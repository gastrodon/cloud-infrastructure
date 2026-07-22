{
  description = "cloud-infrastructure — terraform dev environment + the Glade Minecraft server";

  inputs = {
    # Unstable backs only the devShell tooling.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Pinned release for the Minecraft NixOS systems. Kept separate from the
    # unstable `nixpkgs` above; disko and nix-minecraft follow this one so the
    # server closure is reproducible across both deploy targets.
    nixpkgs-mc.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Hetzner has no official NixOS image: nixos-anywhere kexecs and partitions
    # via disko (./minecraft/disk-config.nix).
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs-mc";
    };

    # nix-minecraft: declarative multi-server module + package overlay. We don't
    # use its loader packages (it has no Forge) — only the
    # services.minecraft-servers module. Our Forge server is built by
    # ./minecraft/pack/forge-server.nix and passed in as `package`.
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs-mc";
    };
  };

  outputs =
    { self, nixpkgs, nixpkgs-mc, disko, nix-minecraft }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              config.allowUnfree = true; # nomad (BSL)
            }
          )
        );

      # The Glade server, shared across platforms: the nix-minecraft module +
      # overlay and ./minecraft/glade.nix (the platform-independent server
      # definition). Each platform passes only its own extra modules, so both
      # deploy the exact same server.
      gladeSystem =
        extraModules:
        nixpkgs-mc.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            nix-minecraft.nixosModules.minecraft-servers
            { nixpkgs.overlays = [ nix-minecraft.overlay ]; }
            ./minecraft/glade.nix
          ]
          ++ extraModules;
        };
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.opentofu
            pkgs.awscli2
            pkgs.hcloud
            pkgs.jq
            pkgs.podman
            pkgs.nomad
          ];

          shellHook = ''
            export AWS_PROFILE=''${AWS_PROFILE:-gas}
            echo "cloud-infrastructure devshell — opentofu $(tofu version -json | ${pkgs.jq}/bin/jq -r .terraform_version), AWS_PROFILE=$AWS_PROFILE"
          '';
        };
      });

      nixosConfigurations = {
        # Hetzner Cloud: disko partitioning + GRUB/DHCP, installed via
        # nixos-anywhere. `hetzner/minecraft` terraform builds this.
        glade-hetzner = gladeSystem [
          disko.nixosModules.disko
          ./minecraft/disk-config.nix
          ./minecraft/hetzner.nix
        ];

        # AWS: amazon-image + EFS/EIP/spot wiring, baked into an AMI. The image
        # builder lives at ...config.system.build.images.amazon, exposed as the
        # `amazonImage` package below and consumed by aws/minecraft/make-ami.sh.
        glade-aws = gladeSystem [
          ./minecraft/aws.nix
        ];
      };

      # `nix build <repo-root>#amazonImage` → a disk image +
      # nix-support/image-info.json that make-ami.sh registers as an AMI.
      packages.x86_64-linux.amazonImage =
        self.nixosConfigurations.glade-aws.config.system.build.images.amazon;
    };
}
