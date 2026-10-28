# One small test VM per cloud with a fixed private IP, so cross-cloud traffic can be proven end to end.
# No public IPs. Access: AWS via SSM, Azure via run-command, GCP via IAP. See scripts/connectivity_test.py.

# --- AWS ---------------------------------------------------------------------
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "vm" {
  name        = "${var.name_prefix}-vm"
  description = "Test VM: ICMP from the other clouds"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "ICMP from Azure and GCP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.azure_vnet_cidr, var.gcp_subnet_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name_prefix}-vm-sg" }
}

resource "aws_security_group" "endpoints" {
  name        = "${var.name_prefix}-ssm-endpoints"
  description = "HTTPS from the VPC to the SSM interface endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.aws_vpc_cidr]
  }

  tags = { Name = "${var.name_prefix}-ssm-endpoints-sg" }
}

# The VM has no internet path, so SSM Session Manager / Run Command needs these endpoints.
resource "aws_vpc_endpoint" "ssm" {
  for_each = toset(["ssm", "ssmmessages", "ec2messages"])

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.workload.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "${var.name_prefix}-${each.key}" }
}

resource "aws_iam_role" "vm" {
  name = "${var.name_prefix}-vm-ssm"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "vm_ssm" {
  role       = aws_iam_role.vm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "vm" {
  name = "${var.name_prefix}-vm"
  role = aws_iam_role.vm.name
}

resource "aws_instance" "test" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.aws_instance_type
  subnet_id              = aws_subnet.workload.id
  private_ip             = cidrhost(aws_subnet.workload.cidr_block, 10)
  vpc_security_group_ids = [aws_security_group.vm.id]
  iam_instance_profile   = aws_iam_instance_profile.vm.name

  metadata_options {
    http_tokens = "required"
  }

  tags       = { Name = "${var.name_prefix}-aws-vm" }
  depends_on = [aws_vpc_endpoint.ssm]
}

# --- Azure -------------------------------------------------------------------
resource "random_password" "azure_vm" {
  length      = 24
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
  min_special = 1
  special     = true
  # Not used for login (we use run-command); only needed to satisfy the VM resource.
  override_special = "!#%*-_"
}

resource "azurerm_network_interface" "test" {
  name                = "${var.name_prefix}-vm-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(azurerm_subnet.workload.address_prefixes[0], 10)
  }

  tags = local.tags
}

resource "azurerm_linux_virtual_machine" "test" {
  name                = "${var.name_prefix}-azure-vm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  size                = var.azure_vm_size

  admin_username                  = "azureuser"
  admin_password                  = random_password.azure_vm.result
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.test.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  tags = local.tags
}

# --- GCP ---------------------------------------------------------------------
resource "google_project_service" "iap" {
  service            = "iap.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name          = "${var.name_prefix}-allow-iap-ssh"
  network       = google_compute_network.main.name
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"] # Google IAP TCP forwarding range

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_instance" "test" {
  name         = "${var.name_prefix}-gcp-vm"
  machine_type = var.gcp_machine_type
  zone         = var.gcp_zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.workload.id
    network_ip = cidrhost(var.gcp_subnet_cidr, 10) # no access_config = no public IP
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  depends_on = [google_project_service.iap]
}
