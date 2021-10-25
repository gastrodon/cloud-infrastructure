resource "kubernetes_config_map" "dashboard" {
  metadata {
    name      = var.name_dashboard_config_map
    namespace = kubernetes_namespace.dashboard.metadata[0].name
    labels    = var.labels_dashboard
  }
}
