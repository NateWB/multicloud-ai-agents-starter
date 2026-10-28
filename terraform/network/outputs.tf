# Deliberately minimal: no keys, no secrets, no account IDs.
output "tgw_name" {
  value = "${var.name_prefix}-tgw"
}

output "azure_resource_group" {
  value = azurerm_resource_group.main.name
}

output "gcp_router" {
  value = google_compute_router.main.name
}

# Used by scripts/connectivity_test.py (no secrets)
output "test_vms" {
  value = {
    aws_instance_id = aws_instance.test.id
    aws_region      = var.aws_region
    azure_vm_name   = azurerm_linux_virtual_machine.test.name
    azure_rg        = azurerm_resource_group.main.name
    gcp_vm_name     = google_compute_instance.test.name
    gcp_zone        = var.gcp_zone
    gcp_project     = var.gcp_project_id
    ips = {
      aws   = aws_instance.test.private_ip
      azure = azurerm_network_interface.test.private_ip_address
      gcp   = google_compute_instance.test.network_interface[0].network_ip
    }
  }
}
