data "azurerm_resource_group" "k8s" {
  name = "${var.resource_group_name}"
}

resource "azurerm_log_analytics_workspace" "k8s" {
  name                = "${var.log_analytics_workspace_name}"
  location            = "${var.location}"
  resource_group_name = "${data.azurerm_resource_group.k8s.name}"
  sku                 = "${var.log_analytics_workspace_sku}"
}

resource "azurerm_log_analytics_solution" "k8s" {
  solution_name         = "ContainerInsights"
  location              = "${azurerm_log_analytics_workspace.k8s.location}"
  resource_group_name   = "${data.azurerm_resource_group.k8s.name}"
  workspace_resource_id = "${azurerm_log_analytics_workspace.k8s.id}"
  workspace_name        = "${azurerm_log_analytics_workspace.k8s.name}"

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}

resource "azurerm_virtual_network" "k8s" {
  name                = "${var.cluster_name}-vnet"
  location            = "${var.location}"
  resource_group_name = "${data.azurerm_resource_group.k8s.name}"
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "k8s" {
  name                 = "${var.cluster_name}-default-subnet"
  resource_group_name  = "${data.azurerm_resource_group.k8s.name}"
  virtual_network_name = "${azurerm_virtual_network.k8s.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_kubernetes_cluster" "k8s" {
  name                = "${var.cluster_name}"
  location            = "${var.location}"
  resource_group_name = "${data.azurerm_resource_group.k8s.name}"
  dns_prefix          = "${var.dns_prefix}"
  kubernetes_version  = "${coalesce(var.k8s_version, var.k8s_default_version)}"

  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = "${var.ssh_public_key}"
    }
  }

  network_profile {
    service_cidr       = "10.0.1.0/24"
    dns_service_ip     = "10.0.1.10"
    network_plugin     = "azure"
    docker_bridge_cidr = "172.17.0.1/16"
  }

  agent_pool_profile {
    name            = "agentpool"
    count           = "${var.agent_count}"
    vm_size         = "${var.agent_vm_size}"
    os_type         = "${var.agent_vm_os}"
    os_disk_size_gb = 30
    vnet_subnet_id  = "${azurerm_subnet.k8s.id}"
  }

  service_principal {
    client_id     = "${var.client_id}"
    client_secret = "${var.client_secret}"
  }

  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = "${azurerm_log_analytics_workspace.k8s.id}"
    }

    aci_connector_linux {
      enabled     = "${var.virtual_nodes}"
      subnet_name = "${azurerm_subnet.k8s.name}"
    }
  }
}

resource "local_file" "cluster_ca_certificate" {
  content  = "${base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.cluster_ca_certificate)}"
  filename = "${path.cwd}/.terraform/${var.name}.${var.base_domain}/cluster_ca_certificate.pem"
}
