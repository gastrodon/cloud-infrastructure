resource "kubernetes_service_account" "admin" {
  metadata {
    name      = var.name_dashboard_service_user
    namespace = kubernetes_namespace.dashboard.metadata[0].name
  }
}

resource "kubernetes_role" "admin" {
  metadata {
    name      = var.name_dashboard
    namespace = kubernetes_namespace.dashboard.metadata[0].name
    labels    = var.labels_dashboard
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "update", "delete"]

    resource_names = [
      kubernetes_secret.certs.metadata[0].name,
      kubernetes_secret.csrf.metadata[0].name,
      kubernetes_secret.key_holder.metadata[0].name,
    ]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "update"]

    resource_names = [
      kubernetes_config_map.dashboard.metadata[0].name,
    ]
  }

  rule {
    api_groups = [""]
    resources  = ["services"]
    verbs      = ["proxy"]

    resource_names = [
      var.name_metrics_scraper,
      "heapster",
    ]
  }

  rule {
    api_groups = [""]
    resources  = ["services"]
    verbs      = ["get"]

    resource_names = [
      var.name_metrics_scraper,
      "http:${var.name_metrics_scraper}",
      "heapster",
      "http:heapster:",
      "https:heapster:",
    ]
  }
}

resource "kubernetes_cluster_role" "admin" {
  metadata {
    name   = "${var.name_dashboard_service_user}-cluster-admin"
    labels = var.labels_dashboard
  }

  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["pods", "nodes"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "admin" {
  metadata {
    name   = var.name_dashboard_service_user
    labels = var.labels_dashboard
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.admin.metadata[0].name
    namespace = kubernetes_namespace.dashboard.metadata[0].name
  }
}
