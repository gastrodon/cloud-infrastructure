resource "kubernetes_namespace" "dashboard" {
  metadata {
    name = var.name_dashboard
  }
}
