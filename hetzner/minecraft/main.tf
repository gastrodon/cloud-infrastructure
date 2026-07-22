resource "hcloud_ssh_key" "id_ed25519" {
  name       = "id_ed25519"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# Boots a stock Debian image; nixos-anywhere kexecs into an installer,
# partitions per disk-config.nix (disko), and installs the flake. No official
# NixOS image on Hetzner, so we can't do the AWS-style AMI + rebuild-over-SSH.
resource "hcloud_server" "mc" {
  name         = "minecraft-glade"
  server_type  = var.server_type
  image        = var.image
  location     = var.location
  ssh_keys     = [hcloud_ssh_key.id_ed25519.id]
  firewall_ids = [hcloud_firewall.mc.id]

  labels = {
    name = "minecraft-glade"
  }
}

# --- NixOS install + subsequent rebuilds, driven by nixos-anywhere ---
# all-in-one does the initial kexec/disko install, then plain nixos-rebuild
# switch on later applies. Re-runs the full install if the server (instance_id)
# is replaced.
#
# The system definition lives in the repo-root flake (../..) as the
# `glade-hetzner` config: shared minecraft/glade.nix + the Hetzner platform
# modules. abspath keeps the flake reference machine-independent.
module "deploy" {
  source = "github.com/nix-community/nixos-anywhere//terraform/all-in-one"

  nixos_system_attr      = "${abspath("${path.module}/../..")}#nixosConfigurations.glade-hetzner.config.system.build.toplevel"
  nixos_partitioner_attr = "${abspath("${path.module}/../..")}#nixosConfigurations.glade-hetzner.config.system.build.diskoScript"

  target_host = hcloud_server.mc.ipv4_address
  instance_id = hcloud_server.mc.id
}
