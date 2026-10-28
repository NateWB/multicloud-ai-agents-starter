# GCP: custom VPC + HA VPN gateway + Cloud Router (BGP) connecting to the AWS Transit Gateway.
# Pattern follows Google's "Connect HA VPN to AWS peer gateways" guide:
#   2 AWS VPN connections (A, B), 4 AWS tunnel IPs, FOUR_IPS_REDUNDANCY external gateway,
#   HA VPN if0 -> A1, A2 ; HA VPN if1 -> B1, B2.

resource "google_compute_network" "main" {
  name                    = "${var.name_prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "workload" {
  name          = "${var.name_prefix}-workload"
  region        = var.gcp_region
  network       = google_compute_network.main.id
  ip_cidr_range = var.gcp_subnet_cidr
}

resource "google_compute_firewall" "allow_cross_cloud" {
  name    = "${var.name_prefix}-allow-cross-cloud"
  network = google_compute_network.main.name

  direction     = "INGRESS"
  source_ranges = [var.aws_summary_cidr, var.azure_vnet_cidr]

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_ha_vpn_gateway" "main" {
  name    = "${var.name_prefix}-ha-vpn"
  region  = var.gcp_region
  network = google_compute_network.main.id
}

resource "google_compute_router" "main" {
  name    = "${var.name_prefix}-router"
  region  = var.gcp_region
  network = google_compute_network.main.id

  bgp {
    asn = var.gcp_router_asn
  }
}

locals {
  # Tunnel order: 0=A1, 1=A2 (AWS connection 0), 2=B1, 3=B2 (AWS connection 1)
  gcp_tunnel_keys = ["0", "1", "2", "3"]

  gcp_hvpn_interface = [0, 0, 1, 1]

  gcp_aws_peer_ips = [
    aws_vpn_connection.gcp[0].tunnel1_address,
    aws_vpn_connection.gcp[0].tunnel2_address,
    aws_vpn_connection.gcp[1].tunnel1_address,
    aws_vpn_connection.gcp[1].tunnel2_address,
  ]

  # BGP inside addresses: AWS side (vgw) is the peer, GCP side (cgw) is the router interface
  gcp_aws_inside_ips = [
    aws_vpn_connection.gcp[0].tunnel1_vgw_inside_address,
    aws_vpn_connection.gcp[0].tunnel2_vgw_inside_address,
    aws_vpn_connection.gcp[1].tunnel1_vgw_inside_address,
    aws_vpn_connection.gcp[1].tunnel2_vgw_inside_address,
  ]

  gcp_cgw_inside_ips = [
    aws_vpn_connection.gcp[0].tunnel1_cgw_inside_address,
    aws_vpn_connection.gcp[0].tunnel2_cgw_inside_address,
    aws_vpn_connection.gcp[1].tunnel1_cgw_inside_address,
    aws_vpn_connection.gcp[1].tunnel2_cgw_inside_address,
  ]

  gcp_psks = [
    aws_vpn_connection.gcp[0].tunnel1_preshared_key,
    aws_vpn_connection.gcp[0].tunnel2_preshared_key,
    aws_vpn_connection.gcp[1].tunnel1_preshared_key,
    aws_vpn_connection.gcp[1].tunnel2_preshared_key,
  ]
}

resource "google_compute_external_vpn_gateway" "aws" {
  name            = "${var.name_prefix}-aws-peer"
  redundancy_type = "FOUR_IPS_REDUNDANCY"
  description     = "AWS Transit Gateway VPN endpoints"

  dynamic "interface" {
    for_each = toset(local.gcp_tunnel_keys)
    content {
      id         = tonumber(interface.key)
      ip_address = local.gcp_aws_peer_ips[tonumber(interface.key)]
    }
  }
}

resource "google_compute_vpn_tunnel" "aws" {
  for_each = toset(local.gcp_tunnel_keys)

  name                            = "${var.name_prefix}-tunnel-${each.key}"
  region                          = var.gcp_region
  vpn_gateway                     = google_compute_ha_vpn_gateway.main.id
  vpn_gateway_interface           = local.gcp_hvpn_interface[tonumber(each.key)]
  peer_external_gateway           = google_compute_external_vpn_gateway.aws.id
  peer_external_gateway_interface = tonumber(each.key)
  shared_secret                   = local.gcp_psks[tonumber(each.key)]
  router                          = google_compute_router.main.id
  ike_version                     = 2
}

resource "google_compute_router_interface" "aws" {
  for_each = toset(local.gcp_tunnel_keys)

  name       = "${var.name_prefix}-if-${each.key}"
  region     = var.gcp_region
  router     = google_compute_router.main.name
  ip_range   = "${local.gcp_cgw_inside_ips[tonumber(each.key)]}/30"
  vpn_tunnel = google_compute_vpn_tunnel.aws[each.key].name
}

resource "google_compute_router_peer" "aws" {
  for_each = toset(local.gcp_tunnel_keys)

  name                      = "${var.name_prefix}-peer-${each.key}"
  region                    = var.gcp_region
  router                    = google_compute_router.main.name
  interface                 = google_compute_router_interface.aws[each.key].name
  peer_ip_address           = local.gcp_aws_inside_ips[tonumber(each.key)]
  peer_asn                  = var.aws_tgw_asn
  advertised_route_priority = 100
}
