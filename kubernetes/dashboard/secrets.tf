resource "kubernetes_secret" "certs" {
  type = "Opaque"

  metadata {
    name      = "kubernetes-${var.name_dashboard}-certs"
    namespace = kubernetes_namespace.dashboard.metadata[0].name
    labels    = var.labels_dashboard
  }

}

resource "kubernetes_secret" "csrf" {
  data = {
    csrf = ""
  }

  metadata {
    name      = "kubernetes-${var.name_dashboard}-csrf"
    namespace = kubernetes_namespace.dashboard.metadata[0].name
    labels    = var.labels_dashboard
  }

  type = "Opaque"
}

resource "kubernetes_secret" "key_holder" {
  metadata {
    name      = "kubernetes-${var.name_dashboard}-holder"
    namespace = kubernetes_namespace.dashboard.metadata[0].name
    labels    = var.labels_dashboard
  }

  type = "Opaque"
}
