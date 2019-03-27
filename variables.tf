variable "client_id" {}
variable "client_secret" {}

variable "name" {}
variable "base_domain" {}

variable "agent_count" {
  default = 2
}

variable "ssh_public_key" {
  default = "~/.ssh/id_rsa.pub"
}

variable "dns_prefix" {
  default = "k8stest"
}

variable cluster_name {
  default = "k8stest"
}

variable resource_group_name {
  default = "azure-k8stest"
}

variable location {
  default = "Central US"
}

variable log_analytics_workspace_name {
  default = "k8s-logs-43424234432"
}

variable log_analytics_workspace_sku {
  default = "PerGB2018"
}
