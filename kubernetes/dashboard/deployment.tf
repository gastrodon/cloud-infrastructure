resource "kubernetes_deployment" "dashboard" {
  metadata {
    name      = var.name_dashboard
    namespace = kubernetes_namespace.dashboard.metadata[0].name
    labels    = var.labels_dashboard
  }

  spec {
    replicas               = 1
    revision_history_limit = 10

    selector {
      match_labels = var.labels_dashboard
    }

    template {
      metadata {
        labels = var.labels_dashboard
      }

      spec {
        service_account_name = kubernetes_service_account.admin.metadata[0].name

        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        container {
          name              = var.name_dashboard
          image             = var.image_dashboard
          image_pull_policy = "Always"

          args = [
            "--auto-generate-certificates",
            "--namespace=${kubernetes_namespace.dashboard.metadata[0].name}",
          ]

          port {
            container_port = 8443
            protocol       = "TCP"
          }

          volume_mount {
            name       = kubernetes_secret.certs.metadata[0].name
            mount_path = "/certs"
          }

          volume_mount {
            mount_path = "/tmp"
            name       = "tmp-volume"
          }

          liveness_probe {
            initial_delay_seconds = 30
            timeout_seconds       = 30

            http_get {
              scheme = "HTTPS"
              path   = "/"
              port   = 8443
            }
          }

          security_context {
            run_as_user  = 1001
            run_as_group = 2001

            allow_privilege_escalation = false
            read_only_root_filesystem  = true
          }
        }

        volume {
          name = kubernetes_secret.certs.metadata[0].name

          secret {
            secret_name = kubernetes_secret.certs.metadata[0].name
          }
        }

        volume {
          name = "tmp-volume"

          empty_dir {}
        }

        toleration {
          key    = "node-role.kubernetes.io.master"
          effect = "NoSchedule"
        }
      }
    }
  }
}

resource "kubernetes_deployment" "metrics_scraper" {
  metadata {
    name      = var.name_metrics_scraper
    namespace = kubernetes_namespace.dashboard.metadata[0].name

    labels = var.labels_metrics_scraper
  }

  spec {
    replicas               = 1
    revision_history_limit = 10

    selector {
      match_labels = var.labels_metrics_scraper
    }

    template {
      metadata {
        labels = var.labels_metrics_scraper
      }

      spec {
        service_account_name = kubernetes_service_account.admin.metadata[0].name

        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        container {
          name              = var.name_metrics_scraper
          image             = var.image_metrics_scraper # TODO: latest
          image_pull_policy = "Always"

          port {
            container_port = 8000
            protocol       = "TCP"
          }

          volume_mount {
            mount_path = "/tmp"
            name       = "tmp-volume"
          }

          liveness_probe {
            initial_delay_seconds = 30
            timeout_seconds       = 30

            http_get {
              scheme = "HTTPS"
              path   = "/"
              port   = 8000
            }
          }

          security_context {
            run_as_user  = 1001
            run_as_group = 2001

            allow_privilege_escalation = false
            read_only_root_filesystem  = true
          }
        }

        volume {
          name = "tmp-volume"

          empty_dir {}
        }

        toleration {
          key    = "node-role.kubernetes.io.master"
          effect = "NoSchedule"
        }
      }
    }
  }
}
