job "echo" {
  datacenters = ["server"]
  type        = "service"

  group "echo" {
    count = 1

    service {
      name = "echo"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.echo.rule=HostRegexp(`echo.*`)",
      ]
    }

    network {
      mode = "bridge"
      port "http" {}
    }

    task "echo" {
      driver = "docker"

      config {
        image = "hashicorp/http-echo:latest"
        args  = ["-listen", ":${NOMAD_PORT_http}", "-text", "robot rock"]
        ports = ["http"]
      }
    }
  }
}
