{ config, lib, pkgs, modulesPath, ... }:

# AWS platform module for the Glade server. Paired with ./glade.nix (the shared
# server) by the `glade-aws` system in the repo-root flake.
#
# amazon-image.nix gives us both the EC2 runtime bits (agent, growpart, ssh keys
# from metadata) AND `system.build.images.amazon`, the disk-image builder that
# ./../aws/minecraft/make-ami.sh bakes into a custom AMI. There is no official
# NixOS AMI + rebuild-over-SSH; the ASG boots clones of the baked image, so the
# config has to already live in the image.
#
# Everything below makes that image behave as a self-healing spot instance
# behind a single Auto Scaling Group. The AMI is stateless: the world lives on
# EFS (mounted at /srv/minecraft), the public IP is an Elastic IP the instance
# claims for itself on boot, and a watcher turns the 2-minute spot interruption
# notice into a graceful world-save before AWS pulls the box.
#
# Runtime wiring the image can't know at bake time (which EFS filesystem, which
# EIP) arrives as launch-template user-data: plain KEY=VALUE lines, e.g.
#   EFS_ID=fs-0123...
#   EIP_ALLOC=eipalloc-0123...
let
  serverUnit = "minecraft-server-glade.service";

  # IMDSv2: grab a token, then read a metadata path with it.
  imds = pkgs.writeShellScript "imds" ''
    set -euo pipefail
    tok=$(${pkgs.curl}/bin/curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
    ${pkgs.curl}/bin/curl -sf -H "X-aws-ec2-metadata-token: $tok" \
      "http://169.254.169.254/latest/$1"
  '';
in
{
  imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ];

  # We pass our own KEY=VALUE user-data, which is NOT a NixOS config or a
  # script — so keep amazon-init from trying to interpret it. SSH host/login
  # key fetching is handled separately and is unaffected.
  systemd.services.amazon-init.enable = false;

  environment.systemPackages = [ pkgs.awscli2 pkgs.nfs-utils ];
  boot.supportedFilesystems = [ "nfs" ];

  # The amazon image builder pins a 4GB root, which the Forge + JDK + mods
  # closure blows past. Bump it just for the image build (the world lives on
  # EFS, so the root only holds OS + Nix store). growpart still expands to the
  # EBS volume at boot.
  image.modules.amazon.virtualisation.diskSize = lib.mkForce (8 * 1024);

  # --- Resolve runtime metadata into /run/ec2-mc.env -----------------------
  # EFS_ID / EIP_ALLOC come from user-data; REGION / INSTANCE_ID from IMDS.
  systemd.services.ec2-metadata = {
    description = "Resolve EC2 metadata + user-data into /run/ec2-mc.env";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      umask 077
      ${imds} meta-data/placement/region > /run/ec2-region
      region=$(cat /run/ec2-region)
      instance_id=$(${imds} meta-data/instance-id)

      # user-data holds the EFS/EIP identifiers (KEY=VALUE lines).
      ${imds} user-data > /run/ec2-mc.env
      {
        echo "AWS_REGION=$region"
        echo "AWS_DEFAULT_REGION=$region"
        echo "INSTANCE_ID=$instance_id"
      } >> /run/ec2-mc.env
    '';
  };

  # --- Mount the world storage (EFS) at /srv/minecraft ---------------------
  systemd.services.mount-minecraft = {
    description = "Mount EFS world storage at /srv/minecraft";
    after = [ "ec2-metadata.service" "network-online.target" ];
    requires = [ "ec2-metadata.service" ];
    wants = [ "network-online.target" ];
    before = [ serverUnit ];
    path = [ pkgs.nfs-utils pkgs.util-linux pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "${pkgs.util-linux}/bin/umount /srv/minecraft";
    };
    script = ''
      set -euo pipefail
      . /run/ec2-mc.env
      mkdir -p /srv/minecraft
      if ! mountpoint -q /srv/minecraft; then
        mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport \
          "$EFS_ID.efs.$AWS_REGION.amazonaws.com:/" /srv/minecraft
      fi
      # nix-minecraft runs the server as the `minecraft` user. The tmpfiles rule
      # that creates /srv/minecraft/glade fired before this mount (and is now
      # shadowed by it), so recreate the server dir on the filesystem itself.
      chown minecraft:minecraft /srv/minecraft
      install -d -m 0770 -o minecraft -g minecraft /srv/minecraft/glade
    '';
  };

  # --- Claim the Elastic IP so the address survives instance swaps ---------
  systemd.services.eip-associate = {
    description = "Associate the Elastic IP with this instance";
    after = [ "ec2-metadata.service" "network-online.target" ];
    requires = [ "ec2-metadata.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.awscli2 ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      . /run/ec2-mc.env
      aws ec2 associate-address \
        --allocation-id "$EIP_ALLOC" \
        --instance-id "$INSTANCE_ID" \
        --allow-reassociation \
        --region "$AWS_REGION"
    '';
  };

  # --- Turn the spot interruption notice into a graceful save --------------
  # Poll IMDS for spot/instance-action. When it appears (~2 min before the
  # yank) stop the server unit: nix-minecraft sends SIGTERM, Forge's shutdown
  # hook saves the world, and EFS keeps it for the replacement instance.
  systemd.services.spot-interruption-watch = {
    description = "Watch for the spot interruption notice and save the world";
    after = [ serverUnit ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.systemd ];
    serviceConfig = {
      Restart = "always";
      RestartSec = 5;
    };
    script = ''
      set -uo pipefail
      while true; do
        if ${imds} meta-data/spot/instance-action >/dev/null 2>&1; then
          echo "spot interruption notice received — stopping ${serverUnit} for graceful save"
          systemctl stop ${serverUnit}
          # Stay quiet until the box goes away; no point re-triggering.
          sleep 120
        fi
        sleep 5
      done
    '';
  };

  # Server waits for its world storage, and gets a generous stop window so the
  # save can finish inside the ~120s interruption budget.
  systemd.services."minecraft-server-glade" = {
    after = [ "mount-minecraft.service" ];
    requires = [ "mount-minecraft.service" ];
    # nix-minecraft defaults this to 75s; widen it so a save triggered by the
    # spot notice can finish inside the ~120s interruption budget.
    serviceConfig.TimeoutStopSec = lib.mkForce 110;
  };

  # The shared config.bak cleanup (glade.nix) operates on the EFS-mounted world
  # dir, so it must run after the mount — order it exactly like the server.
  systemd.services."minecraft-glade-clear-stale-config-bak" = {
    after = [ "mount-minecraft.service" ];
    requires = [ "mount-minecraft.service" ];
  };
}
