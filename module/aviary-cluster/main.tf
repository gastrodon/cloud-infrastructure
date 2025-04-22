locals {
  aviary_install = var.aviary_install_url != null ? var.aviary_install_url : "https://raw.githubusercontent.com/gastrodon/aviary.sh/refs/${var.aviary_ref}/install"
  inventory_root = "/opt/aviary/inventory-repo/${var.inventory_path}"

  user_data = <<-EOF
  #!/bin/bash
  curl -L ${local.aviary_install} | AVIARY_NO_CRON=${var.no_cron} bash

  inventory="${local.inventory_root}/hosts/$(hostname)"
  mkdir -p /opt/aviary "$inventory"
  git clone "${var.inventory_url}" /opt/aviary/inventory-repo
  git -C /opt/aviary/inventory-repo checkout "${var.inventory_branch}"

  ${join("\n", [for key, value in var.aviary_config : "echo \"${key}=${value}\" >> /var/lib/aviary/config"])}

  cat <<AV > "$inventory/variables"
  ${join("\n", [for key, value in var.aviary_variables : "${key}='${value}'"])}
  AV

  cat <<AV > "$inventory/roles"
  ${join("\n", var.aviary_roles)}
  AV

  cat <<AV > "$inventory/modules"
  ${join("\n", var.aviary_modules)}
  AV

  av apply --inventory /opt/aviary/inventory-repo/${var.inventory_path}
  ${var.user_data != null ? var.user_data : ""}
  EOF
}

resource "aws_launch_template" "this" {
  name_prefix            = "${var.name}-"
  image_id               = var.image_id
  key_name               = var.key_name
  instance_type          = var.instance_type
  vpc_security_group_ids = var.security_groups
  user_data              = base64encode(local.user_data)
  update_default_version = true

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs { volume_size = var.volume_size }
  }

  iam_instance_profile {
    name = var.instance_profile
  }

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  launch_template_iter = var.instance_use_spot ? [] : [0]
  mixed_instances_iter = var.instance_use_spot ? [0] : []

}

resource "aws_autoscaling_group" "this" {
  name             = "${aws_launch_template.this.name}-asg"
  desired_capacity = var.desired_capacity
  min_size         = var.min_capacity
  max_size         = var.max_capacity

  health_check_grace_period = 60
  health_check_type         = "EC2"
  availability_zones        = var.availability_zones
  vpc_zone_identifier       = var.subnet_ids
  target_group_arns         = var.target_groups

  dynamic "launch_template" {
    for_each = local.launch_template_iter
    content {
      name = aws_launch_template.this.name
    }
  }

  dynamic "mixed_instances_policy" {
    for_each = local.mixed_instances_iter

    content {
      instances_distribution {
        on_demand_base_capacity                  = 0
        on_demand_percentage_above_base_capacity = 0
        spot_allocation_strategy                 = var.instance_allocation_strategy
      }

      launch_template {
        launch_template_specification {
          launch_template_id = aws_launch_template.this.id
          version            = "$Latest"
        }
      }
    }
  }

  tag {
    key                 = "Name"
    value               = var.name
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

output "asg_name" {
  value = aws_autoscaling_group.this.name
}
