variable "name_prefix" {
  description = "Prefix for resource names (lowercase letters, digits, hyphens)."
  type        = string
  default     = "careerexp26"
}

variable "teardown_date" {
  description = "Tag only: when this environment should be destroyed."
  type        = string
  default     = "not-set"
}

# --- AWS -------------------------------------------------------------------
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile for a SANDBOX member account (not the org management account)."
  type        = string
  default     = null
}

variable "aws_vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "aws_summary_cidr" {
  description = "Summary route covering the hub VPC and the planned demo spoke (10.10.0.0/16 + 10.11.0.0/16). Azure and GCP use this."
  type        = string
  default     = "10.10.0.0/15"
}

variable "aws_tgw_asn" {
  description = "Amazon-side ASN of the Transit Gateway."
  type        = number
  default     = 64512
}

# --- Azure -----------------------------------------------------------------
variable "azure_subscription_id" {
  type = string
}

variable "azure_location" {
  type    = string
  default = "eastus2"
}

variable "azure_vnet_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "azure_vpn_sku" {
  description = "Use an AZ SKU; non-AZ VpnGw SKUs are being retired."
  type        = string
  default     = "VpnGw1AZ"
}

# --- GCP -------------------------------------------------------------------
variable "gcp_project_id" {
  type = string
}

variable "gcp_region" {
  type    = string
  default = "us-east4"
}

variable "gcp_subnet_cidr" {
  type    = string
  default = "10.30.0.0/20"
}

variable "gcp_router_asn" {
  description = "Cloud Router ASN (also used as the AWS customer gateway ASN)."
  type        = number
  default     = 64514
}

# --- Test VMs (one per cloud, private IPs only) ----------------------------
variable "aws_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "azure_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "gcp_zone" {
  type    = string
  default = "us-east4-a"
}

variable "gcp_machine_type" {
  type    = string
  default = "e2-micro"
}
