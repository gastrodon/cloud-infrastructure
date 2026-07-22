data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_key_pair" "id_ed25519" {
  key_name   = var.key_name
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# Static public address that survives spot swaps. Each replacement instance
# claims it for itself on boot (see ec2-spot.nix → eip-associate.service), so
# the DNS record and players' saved address never change.
resource "aws_eip" "mc" {
  domain = "vpc"
  tags   = { Name = "minecraft" }
}

# The instance blueprint the ASG stamps out: our baked NixOS AMI, requested as
# spot. The AMI is stateless — the world lives on EFS and the identifiers it
# needs (which EFS, which EIP) are threaded in as KEY=VALUE user-data.
resource "aws_launch_template" "mc" {
  name_prefix   = "minecraft-"
  image_id      = aws_ami.mc.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.id_ed25519.key_name

  # Override the AMI's 8GB root up to 16GB gp3 so the OS + Nix store closure and
  # the 4GB swapfile (glade.nix) fit. amazon-image's growpart expands the FS to
  # the larger volume at boot. World data lives on EFS, not here.
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 16
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  vpc_security_group_ids = [aws_security_group.mc.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.mc.name
  }

  instance_market_options {
    market_type = "spot"
    spot_options {
      spot_instance_type             = "one-time"
      instance_interruption_behavior = "terminate"
      max_price                      = var.spot_max_price != "" ? var.spot_max_price : null
    }
  }

  # IMDSv2 required; hop limit 1 is enough since our services run on the host.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(<<-EOT
    EFS_ID=${aws_efs_file_system.mc.id}
    EIP_ALLOC=${aws_eip.mc.id}
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "minecraft" }
  }

  update_default_version = true
}

# Single-instance ASG: it keeps exactly one spot box alive, relaunching after
# an interruption. max=1 means no two instances ever overlap, so the world on
# EFS only ever has one writer (Minecraft's session.lock is the backstop).
resource "aws_autoscaling_group" "mc" {
  name                = "minecraft"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = data.aws_subnets.default.ids
  capacity_rebalance  = true
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.mc.id
    version = "$Latest"
  }

  # Rolling a new AMI in: a launch-template change triggers a refresh. With a
  # single instance the old one must go before the new one comes up.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
    }
  }

  tag {
    key                 = "Name"
    value               = "minecraft"
    propagate_at_launch = true
  }
}
