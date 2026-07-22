{ lib, pkgs, ... }:

# NixOS module for the Create+ server.
# Adds services.minecraft-servers.servers.createplus with:
#   - NeoForge 1.21.1 loader
#   - Port 25566 (glade uses 25565)
#   - Modest heap (4GB) to share the 16GB cx43 with glade (~10GB)
#   - Server-side mods and config from the Create+ 6.0.0 alpha mrpack
#
# The top-level services.minecraft-servers block (enable, eula, openFirewall)
# is defined in configuration.nix and applies globally; this module only
# adds a servers.createplus entry. NixOS merges attrsets, so this works.

let
  # The Create+ pack's server-relevant contents (mods jars + config)
  pack = pkgs.callPackage ./pack/createplus-pack.nix { };

  # Symlink each jar individually so mods/ is writable and real.
  # (Same pattern as glade for consistency.)
  modSymlinks = lib.mapAttrs'
    (jar: _: lib.nameValuePair "mods/${jar}" "${pack}/mods/${jar}")
    (lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".jar" n)
      (builtins.readDir "${pack}/mods"));
in
{
  services.minecraft-servers.servers.createplus = {
    enable = true;

    # nix-minecraft's NeoForge loader for 1.21.1 (from the overlay)
    package = pkgs.neoforgeServers."1.21.1";

    # Modest heap for the shared 16GB cx43 (glade uses up to 10G)
    jvmOpts = "-Xms2G -Xmx4G";

    serverProperties = {
      server-port = 25566;
      motd = "Create+";
      # Standard modpack timeouts
      max-tick-time = 180000;
    };

    # Mods: one symlink per jar (writable mods/ dir)
    symlinks = modSymlinks;

    # Config: writable copy of the pack's config tree
    files = {
      "config" = "${pack}/config";
    };
  };
}
