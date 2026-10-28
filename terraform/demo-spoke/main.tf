# DEMO: second AWS spoke attached to the existing Transit Gateway hub.
# Separate root + separate state from terraform/network, so it can be applied and destroyed
# repeatedly (practice runs) without touching the backbone.
# This is a known-good reference for what an AI agent produces from prompts/01-add-spoke.md.
# Compare the agent's output against it; do not hand it to the agent as a starting point.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "aws_profile" {
  description = "AWS CLI profile for the SAME sandbox account that holds the hub. null = default credentials."
  type        = string
  default     = null
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name_prefix" {
  type    = string
  default = "careerexp26"
}

variable "spoke_cidr" {
  type    = string
  default = "10.11.0.0/16"
}

variable "azure_vnet_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "gcp_subnet_cidr" {
  type    = string
  default = "10.30.0.0/20"
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project = "CareerExp26"
      Purpose = "Live demo spoke - destroy after use"
    }
  }
}

# --- Look up the existing hub by its Name tags (nothing hard-coded) ----------
data "aws_ec2_transit_gateway" "hub" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-tgw"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_vpc" "hub" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-vpc"]
  }
}

data "aws_route_table" "hub_workload" {
  filter {
    name   = "tag:Name"
    values = ["${var.name_prefix}-workload-rt"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  # Everywhere the spoke must reach through the hub
  remote_cidrs = {
    hub   = data.aws_vpc.hub.cidr_block
    azure = var.azure_vnet_cidr
    gcp   = var.gcp_subnet_cidr
  }
}

# --- Spoke network -------------------------------------------------------------
resource "aws_vpc" "spoke" {
  cidr_block           = var.spoke_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name_prefix}-spoke-vpc" }
}

resource "aws_subnet" "spoke" {
  vpc_id            = aws_vpc.spoke.id
  cidr_block        = cidrsubnet(var.spoke_cidr, 8, 1)
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "${var.name_prefix}-spoke-subnet" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke" {
  transit_gateway_id = data.aws_ec2_transit_gateway.hub.id
  vpc_id             = aws_vpc.spoke.id
  subnet_ids         = [aws_subnet.spoke.id]
  tags               = { Name = "${var.name_prefix}-spoke-attach" }
}

resource "aws_route_table" "spoke" {
  vpc_id = aws_vpc.spoke.id
  tags   = { Name = "${var.name_prefix}-spoke-rt" }
}

resource "aws_route_table_association" "spoke" {
  subnet_id      = aws_subnet.spoke.id
  route_table_id = aws_route_table.spoke.id
}

resource "aws_route" "spoke_to_remote" {
  for_each = local.remote_cidrs

  route_table_id         = aws_route_table.spoke.id
  destination_cidr_block = each.value
  transit_gateway_id     = data.aws_ec2_transit_gateway.hub.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.spoke]
}

# Return path: the hub VPC needs a route to the new spoke
resource "aws_route" "hub_to_spoke" {
  route_table_id         = data.aws_route_table.hub_workload.id
  destination_cidr_block = var.spoke_cidr
  transit_gateway_id     = data.aws_ec2_transit_gateway.hub.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.spoke]
}

# --- Test VM ---------------------------------------------------------------------
resource "aws_security_group" "spoke_vm" {
  name        = "${var.name_prefix}-spoke-vm"
  description = "Spoke test VM: ICMP from the hub and the other clouds"
  vpc_id      = aws_vpc.spoke.id

  ingress {
    description = "ICMP from hub, Azure, GCP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = values(local.remote_cidrs)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-spoke-vm-sg" }
}

resource "aws_instance" "spoke" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.spoke.id
  private_ip             = cidrhost(aws_subnet.spoke.cidr_block, 10)
  vpc_security_group_ids = [aws_security_group.spoke_vm.id]

  metadata_options {
    http_tokens = "required"
  }

  tags = { Name = "${var.name_prefix}-spoke-vm" }
}

output "spoke_vm_ip" {
  value = aws_instance.spoke.private_ip
}
