# The world storage. EFS (not EBS) because a spot replacement can land in any
# AZ, and only EFS mounts across AZs — an EBS volume is pinned to one. Mounted
# at /srv/minecraft by ec2-spot.nix.
resource "aws_efs_file_system" "mc" {
  encrypted = true
  tags      = { Name = "minecraft" }
}

# One mount target per subnet (== per AZ in the default VPC), so whichever AZ
# the spot instance lands in has a local NFS endpoint.
resource "aws_efs_mount_target" "mc" {
  for_each        = toset(data.aws_subnets.default.ids)
  file_system_id  = aws_efs_file_system.mc.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}
