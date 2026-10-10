# One edge box: its EIP, its SSM-held WireGuard identity, and a single-instance spot ASG.

variable "name" {
  type = string
}

variable "tunnel_ip" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_types" {
  type = list(string)
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "efs_id" {
  type = string
}

variable "public_tcp_ports" {
  description = "Public TCP ports beyond 80/443 the box opens in its own firewall."
  type        = list(string)
  default     = []
}

variable "home_peers" {
  type = map(string)
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  ssm_prefix = "/edge/${var.name}"
  ssm_arn    = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_prefix}/*"
  home_peers = join(" ", [for ip, key in var.home_peers : "${ip}@${key}"])
}

resource "aws_eip" "this" {
  domain = "vpc"
  tags   = { Name = var.name }
}

resource "aws_iam_role" "this" {
  name = "${var.name}-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "this" {
  name = "edge"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:AssociateAddress", "ec2:DescribeAddresses"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:PutParameter"]
        Resource = local.ssm_arn
      },
    ]
  })
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-instance"
  role = aws_iam_role.this.name
}

resource "aws_launch_template" "this" {
  name_prefix = "${var.name}-"
  image_id    = var.ami_id

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  vpc_security_group_ids = [var.security_group_id]

  iam_instance_profile {
    name = aws_iam_instance_profile.this.name
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(<<-EOT
    NODE_NAME=${var.name}
    EIP_ALLOC=${aws_eip.this.id}
    EFS_ID=${var.efs_id}
    SSM_WG_KEY=${local.ssm_prefix}/wg-key
    SSM_WG_PUB=${local.ssm_prefix}/wg-pub
    TUNNEL_IP=${var.tunnel_ip}
    PUBLIC_TCP_PORTS="${join(" ", var.public_tcp_ports)}"
    HOME_PEERS="${local.home_peers}"
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = var.name }
  }

  update_default_version = true
}

# max_size = 1 keeps the box's EFS directory single-writer.
resource "aws_autoscaling_group" "this" {
  name                = var.name
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = var.subnet_ids
  capacity_rebalance  = true
  health_check_type   = "EC2"

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "price-capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.this.id
        # A concrete version, unlike minecraft's $Latest, so template changes trigger the refresh.
        version = aws_launch_template.this.latest_version
      }

      dynamic "override" {
        for_each = var.instance_types
        content {
          instance_type = override.value
        }
      }
    }
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
    }
  }

  tag {
    key                 = "Name"
    value               = var.name
    propagate_at_launch = true
  }
}

output "eip" {
  value = aws_eip.this.public_ip
}

output "wg_pub_parameter" {
  value = "${local.ssm_prefix}/wg-pub"
}

output "tunnel_ip" {
  value = var.tunnel_ip
}
