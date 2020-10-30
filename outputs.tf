resource "local_file" "cluster_ca_certificate" {
  content = base64decode(
    azurerm_kubernetes_cluster.k8s.kube_config[0].cluster_ca_certificate,
  )
  filename = "${path.cwd}/.terraform/${var.name}.${var.base_domain}/cluster_ca_certificate.pem"
}

output "api_ca_crt" {
  value = "file://${local_file.cluster_ca_certificate.filename}"
}

output "host" {
  value = azurerm_kubernetes_cluster.k8s.kube_config[0].host
}

output "fqdn" {
  value = azurerm_kubernetes_cluster.k8s.fqdn
}
