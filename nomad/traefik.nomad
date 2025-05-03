variable "nomad_token" {}

variable "consul_http_token" {}

job "traefik" {
  datacenters = ["server"]
  type        = "system"

  update {
    max_parallel = 1
    stagger      = "10s"
    auto_revert  = true
  }

  group "traefik" {
    network {
      port "http" {
        static = 80
      }
      port "admin" {
        static = 8080
      }
    }

    service {
      name     = "traefik-http"
      provider = "nomad"
      port     = "http"
    }

    task "traefik_reverse_proxy" {
      kill_timeout = "30s"

      driver = "docker"
      config {
        image        = "traefik:latest"
        ports        = ["admin", "http"]
        network_mode = "host"

        args = [
          "--ping=true",
          "--log.level=INFO",
          "--api.dashboard=true",
          "--api.insecure=true",
          "--entryPoints.web.forwardedHeaders.insecure",
          "--entrypoints.web.address=:${NOMAD_PORT_http}",
          "--entryPoints.web.transport.lifeCycle.requestAcceptGraceTimeout=15s",
          "--entryPoints.web.transport.lifeCycle.graceTimeOut=10s",
          "--entrypoints.traefik.address=:${NOMAD_PORT_admin}",
          "--providers.nomad=true",
          "--providers.nomad.endpoint.address=http://127.0.0.1:4646",
          "--providers.nomad.endpoint.token=${var.nomad_token}",
          "--providers.consulcatalog=true",
          "--providers.consulcatalog.prefix=traefik",
          "--providers.consulcatalog.exposedByDefault=false",
          "--providers.consulcatalog.endpoint.address=http://127.0.0.1:8500",
          "--providers.consulcatalog.endpoint.token=${var.consul_http_token}"
        ]
      }
    }
  }
}
