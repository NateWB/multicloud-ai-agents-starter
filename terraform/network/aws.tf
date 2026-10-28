# AWS: workload VPC + Transit Gateway hub + VPN attachments to Azure (static) and GCP (BGP, 4 tunnels)

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.aws_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name_prefix}-vpc" }
}

resource "aws_subnet" "workload" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.aws_vpc_cidr, 8, 1)
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "${var.name_prefix}-workload" }
}

resource "aws_route_table" "workload" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name_prefix}-workload-rt" }
}

resource "aws_route_table_association" "workload" {
  subnet_id      = aws_subnet.workload.id
  route_table_id = aws_route_table.workload.id
}

resource "aws_route" "to_azure" {
  route_table_id         = aws_route_table.workload.id
  destination_cidr_block = var.azure_vnet_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.main]
}

resource "aws_route" "to_gcp" {
  route_table_id         = aws_route_table.workload.id
  destination_cidr_block = var.gcp_subnet_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.main]
}

# --- Transit Gateway (the hub) ---------------------------------------------
resource "aws_ec2_transit_gateway" "main" {
  description                     = "${var.name_prefix} multicloud hub"
  amazon_side_asn                 = var.aws_tgw_asn
  vpn_ecmp_support                = "enable"
  dns_support                     = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  auto_accept_shared_attachments  = "disable"
  tags                            = { Name = "${var.name_prefix}-tgw" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.main.id
  subnet_ids         = [aws_subnet.workload.id]
  tags               = { Name = "${var.name_prefix}-vpc-attach" }
}

# --- VPN to Azure: static routing, one tunnel in use (Azure side uses tunnel 1) ---
resource "aws_customer_gateway" "azure" {
  bgp_asn    = 65000 # required by the API; unused with static routing
  ip_address = azurerm_public_ip.vpn.ip_address
  type       = "ipsec.1"
  tags       = { Name = "${var.name_prefix}-cgw-azure" }
}

resource "aws_vpn_connection" "azure" {
  customer_gateway_id = aws_customer_gateway.azure.id
  transit_gateway_id  = aws_ec2_transit_gateway.main.id
  type                = "ipsec.1"
  static_routes_only  = true

  # One cipher suite, matching the Azure ipsec_policy in azure.tf
  tunnel1_ike_versions                 = ["ikev2"]
  tunnel1_phase1_encryption_algorithms = ["AES256"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase1_dh_group_numbers      = [14]
  tunnel1_phase2_encryption_algorithms = ["AES256"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase2_dh_group_numbers      = [14]

  tunnel2_ike_versions                 = ["ikev2"]
  tunnel2_phase1_encryption_algorithms = ["AES256"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase1_dh_group_numbers      = [14]
  tunnel2_phase2_encryption_algorithms = ["AES256"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase2_dh_group_numbers      = [14]

  tags = { Name = "${var.name_prefix}-vpn-azure" }
}

# Static route: Azure CIDR lives behind the Azure VPN attachment
resource "aws_ec2_transit_gateway_route" "azure" {
  destination_cidr_block         = var.azure_vnet_cidr
  transit_gateway_attachment_id  = aws_vpn_connection.azure.transit_gateway_attachment_id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.main.association_default_route_table_id
}

# --- VPN to GCP: BGP, 2 connections x 2 tunnels = 4 tunnels (Google's documented HA pattern) ---
resource "aws_customer_gateway" "gcp" {
  count      = 2
  bgp_asn    = var.gcp_router_asn
  ip_address = google_compute_ha_vpn_gateway.main.vpn_interfaces[count.index].ip_address
  type       = "ipsec.1"
  tags       = { Name = "${var.name_prefix}-cgw-gcp-${count.index}" }
}

locals {
  # /30s in 169.254.0.0/16; AWS side gets .1, customer (GCP) side gets .2
  gcp_inside_cidrs = [
    ["169.254.10.0/30", "169.254.10.4/30"],
    ["169.254.11.0/30", "169.254.11.4/30"],
  ]
}

resource "aws_vpn_connection" "gcp" {
  count               = 2
  customer_gateway_id = aws_customer_gateway.gcp[count.index].id
  transit_gateway_id  = aws_ec2_transit_gateway.main.id
  type                = "ipsec.1"
  static_routes_only  = false

  tunnel1_inside_cidr = local.gcp_inside_cidrs[count.index][0]
  tunnel2_inside_cidr = local.gcp_inside_cidrs[count.index][1]

  # Google recommends a single transform set to avoid IKE fragmentation
  tunnel1_ike_versions                 = ["ikev2"]
  tunnel1_phase1_encryption_algorithms = ["AES256"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase1_dh_group_numbers      = [14]
  tunnel1_phase2_encryption_algorithms = ["AES256"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase2_dh_group_numbers      = [14]

  tunnel2_ike_versions                 = ["ikev2"]
  tunnel2_phase1_encryption_algorithms = ["AES256"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase1_dh_group_numbers      = [14]
  tunnel2_phase2_encryption_algorithms = ["AES256"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase2_dh_group_numbers      = [14]

  tags = { Name = "${var.name_prefix}-vpn-gcp-${count.index}" }
}
