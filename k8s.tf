data "azurerm_resource_group" "k8s" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "k8s" {
  name                = "${var.cluster_name}-vnet"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.k8s.name
  address_space       = ["10.0.0.0/8"]
}

resource "azurerm_subnet" "k8s" {
  name                 = "${var.cluster_name}-default-subnet"
  resource_group_name  = data.azurerm_resource_group.k8s.name
  virtual_network_name = azurerm_virtual_network.k8s.name
  address_prefixes     = ["10.2.0.0/16"]
}

resource "azurerm_subnet" "virtual_nodes" {
  name                 = "${var.cluster_name}-vn-subnet"
  resource_group_name  = data.azurerm_resource_group.k8s.name
  virtual_network_name = azurerm_virtual_network.k8s.name
  address_prefixes     = ["10.3.0.0/16"]

  delegation {
    name = "aciDelegation"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_kubernetes_cluster" "k8s" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.k8s.name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.k8s_version

  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = var.ssh_public_key
    }
  }

  network_profile {
    service_cidr       = "10.0.1.0/24"
    dns_service_ip     = "10.0.1.10"
    network_plugin     = "azure"
    docker_bridge_cidr = "172.17.0.1/16"
  }

  default_node_pool {
    name            = "default"
    node_count      = var.agent_count
    vm_size         = var.agent_vm_size
    os_disk_size_gb = 30
    vnet_subnet_id  = azurerm_subnet.k8s.id
    max_pods        = 50
  }

  # https://docs.microsoft.com/en-us/azure/aks/use-managed-identity
  identity {
    type = "SystemAssigned"
  }
  # service_principal {
  #   client_id     = var.client_id
  #   client_secret = var.client_secret
  # }

  addon_profile {
    aci_connector_linux {
      enabled     = var.virtual_nodes
      subnet_name = azurerm_subnet.virtual_nodes.name
    }
  }

  lifecycle {
    ignore_changes = [
      windows_profile
    ]
  }
}
