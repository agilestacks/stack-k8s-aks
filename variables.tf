variable "client_id" {}
variable "client_secret" {}
variable "name" {}
variable "base_domain" {}
variable "agent_count" {}
variable "agent_vm_size" {}
variable "agent_vm_os" {}
variable "dns_prefix" {}
variable cluster_name {}
variable resource_group_name {}
variable location {}
variable log_analytics_workspace_name {}

variable k8s_version {
  default = ""
}

variable "ssh_public_key" {
  default = "~/.ssh/id_rsa.pub"
}

variable log_analytics_workspace_sku {
  default = "PerGB2018"
}
