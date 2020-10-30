variable "client_id" {
}

variable "client_secret" {
}

variable "name" {
}

variable "base_domain" {
}

variable "agent_count" {
}

variable "spot_agent_count" {
    type    = string
    default = "0"
}

variable "spot_agent_price" {
    type    = string
    default = ""
}

variable "agent_vm_size" {
}

variable "agent_vm_os" {
}

variable "dns_prefix" {
}

variable "cluster_name" {
}

variable "resource_group_name" {
}

variable "location" {
}

variable "virtual_nodes" {
}

variable "k8s_version" {
}

variable "ssh_public_key" {
}
