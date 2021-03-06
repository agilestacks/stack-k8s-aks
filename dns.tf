data "azurerm_dns_zone" "base" {
  name                = var.base_domain
  resource_group_name = var.resource_group_name
}

resource "azurerm_dns_zone" "main" {
  name                = "${var.name}.${data.azurerm_dns_zone.base.name}"
  resource_group_name = var.resource_group_name
}

resource "azurerm_dns_ns_record" "parent" {
  name                = var.name
  zone_name           = data.azurerm_dns_zone.base.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = azurerm_dns_zone.main.name_servers
}

resource "azurerm_dns_cname_record" "api" {
  name                = "api"
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  record              = azurerm_kubernetes_cluster.k8s.fqdn
}
