# Azure: VNet + route-based VPN gateway (AZ SKU) connecting to the AWS Transit Gateway.
# NOTE: the VPN gateway takes roughly 30-45 minutes to create. Apply early.

resource "azurerm_resource_group" "main" {
  name     = "${var.name_prefix}-rg"
  location = var.azure_location
  tags     = local.tags
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.name_prefix}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.azure_vnet_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "workload" {
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.azure_vnet_cidr, 8, 1)]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet" # name is mandatory
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.azure_vnet_cidr, 11, 2040)] # x.x.255.0/27
}

resource "azurerm_public_ip" "vpn" {
  name                = "${var.name_prefix}-vpn-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

resource "azurerm_virtual_network_gateway" "main" {
  name                = "${var.name_prefix}-vpngw"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  type          = "Vpn"
  vpn_type      = "RouteBased"
  sku           = var.azure_vpn_sku
  generation    = "Generation1"
  active_active = false
  bgp_enabled   = false # static routing to AWS keeps this simple and reliable

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  tags = local.tags
}

# AWS side of the tunnel. Address space includes GCP so Azure routes GCP-bound
# traffic into the tunnel; the Transit Gateway forwards it on to GCP.
resource "azurerm_local_network_gateway" "aws" {
  name                = "${var.name_prefix}-lng-aws"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  gateway_address     = aws_vpn_connection.azure.tunnel1_address
  address_space       = [var.aws_summary_cidr, var.gcp_subnet_cidr]
  tags                = local.tags
}

resource "azurerm_virtual_network_gateway_connection" "aws" {
  name                = "${var.name_prefix}-conn-aws"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.main.id
  local_network_gateway_id   = azurerm_local_network_gateway.aws.id
  shared_key                 = aws_vpn_connection.azure.tunnel1_preshared_key
  connection_protocol        = "IKEv2"

  # Must match the single transform set configured on the AWS tunnel
  ipsec_policy {
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    dh_group         = "DHGroup14"
    ipsec_encryption = "AES256"
    ipsec_integrity  = "SHA256"
    pfs_group        = "PFS14"
    sa_lifetime      = 3600
  }

  tags = local.tags
}
