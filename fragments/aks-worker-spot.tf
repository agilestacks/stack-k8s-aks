resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  name                  = "spot"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.k8s.id

  node_count      = var.spot_agent_count
  min_count       = var.spot_agent_count
  max_count       = var.spot_agent_count*2
  vm_size         = var.agent_vm_size
  os_disk_size_gb = 30
  vnet_subnet_id  = azurerm_subnet.k8s.id
  max_pods        = 50

  priority            = "Spot"
  spot_max_price      = var.spot_agent_price
  enable_auto_scaling = true
  eviction_policy     = "Delete"
}
