job "observe" {
  datacenters = ["server"]
  type        = "service"

  group "observe" {
    count = 1

    service {
      name = "observe"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.observe.rule=HostRegexp(`observe.*`)",
      ]
    }

    network {
      mode = "bridge"
      port "http" {
        to = 80
      }
    }

    task "echo" {
      driver = "docker"

      config {
        image = "nginx:latest"
        ports = ["http"]
      }
    }
  }
}
