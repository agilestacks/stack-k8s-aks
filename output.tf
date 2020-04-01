output "api_ca_crt" {
  value = "file://${local_file.cluster_ca_certificate.filename}"
}

output "host" {
  value = azurerm_kubernetes_cluster.k8s.kube_config[0].host
}

output "fqdn" {
  value = azurerm_kubernetes_cluster.k8s.fqdn
}

