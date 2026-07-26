{ lib, pkgs, modulesPath, ... }:

# AWS *staging* platform module for the Glade server. Paired with ./glade.nix
# (the shared server definition) by the `glade-staging` system in the repo-root
# flake. This is the counterpart to ./aws.nix, deliberately stripped down so a
# staging box can never touch the live server:
#
#   - NO Auto Scaling Group / NO spot: launched as a single ON-DEMAND instance
#     out-of-band (AWS CLI), so there is no spot-interruption watcher to bake in.
#   - NO Elastic IP claim: the live server's static address is claimed by the
#     live instance on boot (aws.nix → eip-associate). Staging must NOT run that
#     service or it would steal the live IP. It uses its auto-assigned public IP.
#   - NO shared EFS mount: the live world lives on EFS with a single-writer
#     invariant. Staging keeps its (throwaway, pack-testing) world on the local
#     EBS root instead, so it can never open a second writer on the live world.
#
# Because staging is launched with the default (empty) EC2 user-data, we leave
# amazon-init ENABLED (unlike aws.nix, which disables it to protect its custom
# KEY=VALUE user-data): that's what injects the EC2 key pair for break-glass SSH.
{
  imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ];

  # Root volume holds OS + Nix store + the (throwaway) test world; the 4GB
  # amazon-image default is far too small. growpart expands the FS to the larger
  # EBS volume at boot (the launch sets a bigger volume, as the live LT does).
  image.modules.amazon.virtualisation.diskSize = lib.mkForce (8 * 1024);

  environment.systemPackages = [ pkgs.awscli2 ];
}
