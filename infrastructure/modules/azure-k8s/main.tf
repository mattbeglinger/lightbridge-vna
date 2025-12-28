variable "region" {}
variable "environment_name" {}
variable "node_count" {}
variable "enable_key_vault" { default = false }
variable "key_vault_name" { default = "" }
variable "allow_traffic_from_cidrs" { type = list(string) }

resource "azurerm_resource_group" "rg" {
  name     = "${var.environment_name}-rg"
  location = var.region
}

# 1. The Network (VNet)
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.environment_name}-vnet"
  address_space       = ["20.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["20.0.1.0/24"]
}

# 2. The Control Plane (AKS)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.environment_name}-cluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${var.environment_name}-dns"

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = "Standard_D2_v2"
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
  }

  identity {
    type = "SystemAssigned"
  }
}

# 3. Security (Key Vault)
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  count                       = var.enable_key_vault ? 1 : 0
  name                        = var.key_vault_name
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    key_permissions = ["Create", "Get", "List"]
  }
}