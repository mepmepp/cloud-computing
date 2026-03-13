output "ip_publique" {
	value = azurerm_public_ip.public_ip.ip_address
}

output "storage_account_name" {
  value = azurerm_storage_account.main.name
}

output "storage_primary_endpoint" {
  value = azurerm_storage_account.main.primary_blob_endpoint
}

output "storage_primary_access_key" {
  value     = azurerm_storage_account.main.primary_access_key
  sensitive = true
}

output "db_server" {
  value = azurerm_mssql_server.server.fully_qualified_domain_name
}