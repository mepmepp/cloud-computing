terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.8.0"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "${var.prefix}-resources"
  location = "France Central"
}

resource "random_string" "suffix" {
  length  = 10
  special = false
  upper   = false
}

resource "azurerm_public_ip" "public_ip" {
  name          = "ip-public"
  location      = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
}

resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${var.my_ip_address}/32"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-api"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "${var.app_port}"
    source_address_prefix      = "${var.my_ip_address}/32"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_virtual_machine" "main" {
  name                  = "${var.prefix}-vm"
  location              = azurerm_resource_group.example.location
  resource_group_name   = azurerm_resource_group.example.name
  network_interface_ids = [azurerm_network_interface.main.id]
  vm_size               = "Standard_D2s_v3"

  identity {
    type = "SystemAssigned"
  }

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${var.computer_name}"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = file(pathexpand("${var.local_ssh_key_path}"))
    }
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_ssh_public_key" "ssh" {
  name = "${var.prefix}-ssh"
  resource_group_name = azurerm_resource_group.example.name
  location = azurerm_resource_group.example.location
  public_key = file("${var.local_ssh_key_path}")
}

################
# BLOB STORAGE #
################

resource "azurerm_storage_account" "main" {
  name                     = "${lower(var.prefix)}storage${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"  # Locally Redundant Storage (économique pour dev)

  # Sécurité : désactiver accès public au niveau du compte
  allow_nested_items_to_be_public = false

  # Forcer HTTPS uniquement
  https_traffic_only_enabled = true

  # Version TLS minimale
  min_tls_version = "TLS1_2"

  # Désactiver les clés d'accès partagées (optionnel, si vous utilisez uniquement Azure AD)
  # shared_access_key_enabled = false

  network_rules {
    default_action             = "Deny"  # Bloquer tout par défaut
    bypass                     = ["AzureServices"]
    ip_rules                   = [var.my_ip_address]  # Autoriser votre IP
    virtual_network_subnet_ids = [azurerm_subnet.internal.id]  # Autoriser le subnet de la VM
  }

  tags = {
    environment = "dev"
  }
}

# ----- Containers Blob -----

# Container pour les images
resource "azurerm_storage_container" "images" {
  name                  = "images"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"  # Aucun accès public anonyme
}

# Container pour les logs
resource "azurerm_storage_container" "logs" {
  name                  = "logs"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# ----- Permissions via Azure AD (RBAC) -----

# Récupérer l'identité actuelle (pour l'admin)
data "azurerm_client_config" "current" {}

# Donner un accès complet Blob à l'utilisateur Terraform qui déploie
resource "azurerm_role_assignment" "storage_blob_owner" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Donner accès en lecture/écriture à la VM (via son identité managée)
#resource "azurerm_virtual_machine_extension" "identity" {
#  name                 = "ManagedIdentity"
#  virtual_machine_id   = azurerm_virtual_machine.main.id
#  publisher            = "Microsoft.ManagedIdentity"
#  type                 = "ManagedIdentityExtensionForLinux"
#  type_handler_version = "1.0"
#}

resource "azurerm_role_assignment" "vm_blob_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_virtual_machine.main.identity[0].principal_id
  depends_on           = [azurerm_virtual_machine.main]
}

################
# SQL DATABASE #
################

resource "azurerm_mssql_server" "server" {
  name                         = "${var.prefix}-sql-${random_string.suffix.result}"
  resource_group_name          = azurerm_resource_group.example.name
  location                     = azurerm_resource_group.example.location
  administrator_login          = var.db_user
  administrator_login_password = var.db_password
  version                      = "12.0"
}

resource "azurerm_mssql_database" "db" {
  name      = var.db_name
  server_id = azurerm_mssql_server.server.id
}

resource "azurerm_mssql_firewall_rule" "allow_vm" {
  name             = "allow-vm"
  server_id        = azurerm_mssql_server.server.id
  start_ip_address = azurerm_public_ip.public_ip.ip_address
  end_ip_address   = azurerm_public_ip.public_ip.ip_address
}
