resource "kubernetes_service" "dashboard" {
  metadata {
    name      = var.name_dashboard
    namespace = kubernetes_namespace.dashboard.metadata[0].name

    labels = var.labels_dashboard
  }

  spec {
    port {
      port        = 443
      target_port = 8443
    }

    selector = var.labels_dashboard
  }
}

resource "kubernetes_service" "scraper" {
  metadata {
    name      = var.name_metrics_scraper
    namespace = kubernetes_namespace.dashboard.metadata[0].name

    labels = var.labels_metrics_scraper
  }

  spec {
    port {
      port        = 8000
      target_port = 8000
    }

    selector = var.labels_metrics_scraper
  }
}
