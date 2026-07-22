# Hetzner firewall — the SG equivalent. Default-deny inbound, allow-all
# outbound, so we only declare the two inbound ports (SSH + Minecraft Java).
resource "hcloud_firewall" "mc" {
  name = "minecraft"

  rule {
    description = "SSH"
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Minecraft Java — The Glade"
    direction   = "in"
    protocol    = "tcp"
    port        = "25565"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Minecraft Java — Create+"
    direction   = "in"
    protocol    = "tcp"
    port        = "25566"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}
