{ config, lib, pkgs, ... }:
let
  # Forge 1.20.1-47.4.10 dedicated server (built by ./pack/forge-server.nix).
  # nix-minecraft launches it via `getExe`, with the working directory set to
  # the server's data dir (/srv/minecraft/glade).
  forgeServer = pkgs.callPackage ./pack/forge-server.nix { };

  # The Glade pack's server-side payload: mods/ (jars) and config/, extracted
  # from the S3-hosted server artefact. See ./pack/glade-pack.nix.
  pack = pkgs.callPackage ./pack/glade-pack.nix { };

  # Symlink each jar individually so `mods/` is a real, writable directory.
  # This lets Sinytra Connector create its runtime `.connector` cache next to
  # the jars — a single whole-dir symlink would be read-only and break it.
  # (Reading the dir forces the pack to build; the deploy builds it anyway.)
  modSymlinks = lib.mapAttrs'
    (jar: _: lib.nameValuePair "mods/${jar}" "${pack}/mods/${jar}")
    (lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".jar" n)
      (builtins.readDir "${pack}/mods"));

  # The pack's config tree with a couple of server-admin overrides patched
  # directly into the pack's own files. We patch (rather than regenerate the
  # whole TOML in Nix) so every other setting — and any future pack bump — is
  # preserved untouched; only these specific lines change. `--replace-fail`
  # makes the build error out if a pattern ever stops matching (e.g. the pack
  # renames a key), instead of silently dropping the override.
  packConfig = pkgs.runCommand "glade-config" { } ''
    cp -r ${pack}/config $out
    chmod -R +w $out
    # Disable land claiming for regular players: Private Area caps them at 0
    # regions so they can't register any claim. Ops keep unlimited claims via
    # the separate [limits.admins] block.
    substituteInPlace $out/private_area-common.toml \
      --replace-fail 'maxRegions = 1' 'maxRegions = 0'
    # Don't let the Sculk Horde keep spreading/infesting on an empty server.
    substituteInPlace $out/sculkhorde_config.toml \
      --replace-fail 'isHordeActiveWithNoPlayers = true' 'isHordeActiveWithNoPlayers = false'
  '';
in
{
  # Platform-independent definition of the Glade server. Both the Hetzner and
  # AWS systems import this module so they deploy the exact same server; each
  # adds only its own platform module (boot/disk/network, or EFS/EIP/spot).
  system.stateVersion = "26.05";

  nixpkgs.config.allowUnfree = true; # minecraft/forge are unfree (EULA)

  # A 4GB swapfile as an OOM backstop for the 8GB hardware profile: it catches
  # genuinely-cold pages under a spike so the kernel evicts instead of OOM-killing
  # the JVM. swappiness=10 keeps the hot Java heap in RAM — swapping live heap
  # would stall the single-threaded tick loop. This is a safety net, NOT heap
  # capacity (see jvmOpts). Platform-independent: a swapfile needs no partition,
  # so it lands the same on the AWS EBS root and the Hetzner disko root.
  swapDevices = [{ device = "/var/swapfile"; size = 4096; }];
  boot.kernel.sysctl."vm.swappiness" = 10;

  # Deploy access. On Hetzner the shared key backs root's authorized_keys for
  # nixos-anywhere (see ./hetzner.nix); on AWS the EC2 key pair is injected by
  # amazon-image.nix. Either way the daemon must be up.
  services.openssh.enable = true;

  services.minecraft-servers = {
    enable = true;
    eula = true;
    # Opens 25565 on the host (NixOS) firewall. The cloud firewall/security
    # group opens it at the edge; both layers must allow it.
    openFirewall = true;

    servers.glade = {
      enable  = true;
      package = forgeServer;

      # Heap sized for the shared 8GB hardware profile (m7a.large on AWS): a 6GB
      # heap leaves ~2GB for the OS + JVM off-heap/native (Forge direct buffers,
      # Metaspace). The swapfile (see swapDevices below) is an OOM backstop, NOT
      # heap capacity. Aikar's G1GC flags (small-heap <12G variant) smooth GC
      # pauses on a modded server; AlwaysPreTouch is deliberately omitted so the
      # tight box can leave unused heap uncommitted. nix-minecraft passes this as
      # `getExe forgeServer <jvmOpts>`.
      jvmOpts = builtins.concatStringsSep " " [
        "-Xms4G" "-Xmx6G"
        "-XX:+UseG1GC" "-XX:+ParallelRefProcEnabled" "-XX:MaxGCPauseMillis=200"
        "-XX:+UnlockExperimentalVMOptions" "-XX:+DisableExplicitGC"
        "-XX:G1NewSizePercent=30" "-XX:G1MaxNewSizePercent=40"
        "-XX:G1HeapRegionSize=8M" "-XX:G1ReservePercent=20"
        "-XX:G1HeapWastePercent=5" "-XX:G1MixedGCCountTarget=4"
        "-XX:InitiatingHeapOccupancyPercent=15" "-XX:G1MixedGCLiveThresholdPercent=90"
        "-XX:G1RSetUpdatingPauseTimePercent=5" "-XX:SurvivorRatio=32"
        "-XX:+PerfDisableSharedMem" "-XX:MaxTenuringThreshold=1"
      ];

      serverProperties = {
        server-port = 25565;
        motd        = "The Glade";
        # World-generation seed. Only takes effect when a fresh world is
        # generated; an existing world on EFS keeps its original seed. Quoted so
        # the large value is written to server.properties verbatim.
        level-seed  = "1942040084311180782";
        # Modpacks chunk-gen slowly; give clients time before disconnect.
        max-tick-time = 180000;
        # 0 = no idle kick (vanilla default). Pinned so nix-minecraft's
        # regenerated server.properties never carries a stray live value.
        player-idle-timeout = 0;

        difficulty          = "hard";
        # Anti-cheat permit, NOT a flight grant — leaving it false does not stop
        # anyone flying by legitimate means. Ability-based modded flight
        # (Origins, Icarus) is exempt; only momentum tricks (grappling hook) can
        # occasionally trip the kick.
        allow-flight        = false;
        # Server view/sim radius, sized for the 2-vCPU hardware profile. sim is the
        # dominant per-tick cost (~quadratic in radius); dropped 16→10 and view
        # 12→8 so tick time fits a single 3.7GHz core. max-tick-time above still
        # cushions slow modded chunk-gen.
        view-distance       = 8;
        simulation-distance = 10;
        # No protected bubble around spawn.
        spawn-protection    = 0;
      };

      # Server admins. Setting this makes nix-minecraft manage ops.json
      # declaratively — it is regenerated on every rebuild, so any live `/op`
      # not listed here is dropped. Bare UUID string coerces to level 4.
      operators = {
        InstallArch = "ae2d5669-4728-4787-b29e-2c6ce5cd7a33";
        Cyperus1215 = "ba42a561-6e8f-43dd-aed6-680ae802901f";
      };

      # Mods: one symlink per jar (writable mods/ dir, Connector-friendly).
      symlinks = modSymlinks;

      # Config: writable copy of the pack's config tree, with the admin
      # overrides patched in (see packConfig above).
      files = {
        "config" = packConfig;
      };
    };
  };

  # --- Guard against nix-minecraft's non-idempotent config backup ----------
  # nix-minecraft installs the writable `config` tree (files."config" above) by
  # running `mv config config.bak` on every start before recopying it from the
  # store — but it never clears a prior `config.bak`. If a start is interrupted
  # between the recopy and its ".nix-minecraft-managed" bookkeeping (e.g. an AWS
  # spot kill mid-boot), the next start finds BOTH `config` and `config.bak`
  # present, tries to nest the move into `config.bak/config`, hits a name
  # collision, and aborts under the start script's `set -o errexit`. On EFS that
  # wedged state survives every replacement instance, so the server never starts
  # again and no reboot clears it (this took the AWS server down on 2026-07-22).
  #
  # The config is recopied fresh from the store on every start, so the backup is
  # disposable: delete any stale `config.bak` before nix-minecraft's start-pre
  # runs. It's its own unit ordered *before* the server so it inherits the
  # platform's world-storage ordering (aws.nix adds `after mount-minecraft`; on
  # Hetzner the dir lives on the local root). `wantedBy` (not `requiredBy`) so a
  # cleanup hiccup can never itself block the server from starting.
  systemd.services."minecraft-glade-clear-stale-config-bak" =
    let
      serverDir = "${config.services.minecraft-servers.dataDir}/glade";
    in
    {
      description = "Drop stale nix-minecraft config.bak so an interrupted restart can't wedge glade";
      before = [ "minecraft-server-glade.service" ];
      wantedBy = [ "minecraft-server-glade.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/rm -rf ${serverDir}/config.bak";
      };
    };
}
