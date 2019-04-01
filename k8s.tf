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

resource "azurerm_kubernetes_cluster" "k8s" {
  name                = "${var.cluster_name}"
  location            = "${var.location}"
  resource_group_name = "${data.azurerm_resource_group.k8s.name}"
  dns_prefix          = "${var.dns_prefix}"
  kubernetes_version  = "${var.k8s_version}"

  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = "${file("${var.ssh_public_key}")}"
    }
  }

  agent_pool_profile {
    name            = "agentpool"
    count           = "${var.agent_count}"
    vm_size         = "${var.agent_vm_size}"
    os_type         = "${var.agent_vm_os}"
    os_disk_size_gb = 30
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
  }

  tags {
    Environment = "Development"
  }
}

resource "local_file" "client_key" {
  content  = "${base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.client_key)}"
  filename = "${path.cwd}/.terraform/${var.name}.${var.base_domain}/client_key.pem"
}

resource "local_file" "client_certificate" {
  content  = "${base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.client_certificate)}"
  filename = "${path.cwd}/.terraform/${var.name}.${var.base_domain}/client_certificate.pem"
}

resource "local_file" "cluster_ca_certificate" {
  content  = "${base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.cluster_ca_certificate)}"
  filename = "${path.cwd}/.terraform/${var.name}.${var.base_domain}/cluster_ca_certificate.pem"
}
