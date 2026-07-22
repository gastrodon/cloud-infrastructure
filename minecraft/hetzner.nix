{ modulesPath, ... }:
# Hetzner Cloud platform bits for the Glade server. Paired with ./glade.nix
# (the shared server) and ./disk-config.nix (disko layout) by the
# `glade-hetzner` system in the repo-root flake. Hetzner has no official NixOS
# image, so nixos-anywhere kexecs and partitions via disko instead of importing
# amazon-image.nix.
{
  imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];

  # Legacy BIOS boot off /dev/sda (Hetzner Cloud x86). disko wires up
  # boot.loader.grub.devices from the EF02 partition in disk-config.nix.
  boot.loader.grub.enable = true;
  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];

  # Hetzner hands out addresses via DHCP.
  networking.useDHCP = true;

  # Deploy access: the shared key backs root's authorized_keys, which is how the
  # Terraform nixos-anywhere step connects for the install and later rebuilds.
  users.users.root.openssh.authorizedKeys.keyFiles = [ ./id_ed25519.pub ];
}
