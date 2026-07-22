{ ... }:
{
  # Hetzner Cloud x86 boots via legacy BIOS off /dev/sda. GPT with a small
  # BIOS-boot partition for GRUB's core image, the rest an ext4 root.
  disko.devices.disk.main = {
    device = "/dev/sda";
    type   = "disk";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size     = "1M";
          type     = "EF02"; # BIOS boot partition
        };
        root = {
          size = "100%";
          content = {
            type       = "filesystem";
            format     = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
