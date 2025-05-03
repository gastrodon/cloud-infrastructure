locals {
  autoscale_default = {
    instance_use_spot = false
    key_name          = var.ssh_key_name
    server            = false
    vpc_id            = var.vpc_id
  }

  autoscale_iter = {
    for kind in var.autoscaling_groups :
    kind.name => merge(local.autoscale_default, kind, {
      name = "${var.name}-${kind.name}"
    })
  }

  target_groups = [
    aws_lb_target_group.consul.arn,
    aws_lb_target_group.nomad.arn,
    aws_lb_target_group.nginx.arn,
    aws_lb_target_group.traefik.arn,
    aws_lb_target_group.consul_private.arn,
    aws_lb_target_group.nomad_private.arn,
  ]

  cluster_key = var.name
}

resource "random_uuid" "consul_token" {
  keepers = {}
}

module "autoscaling_group" {
  for_each = local.autoscale_iter
  source   = "github.com/gastrodon/cloud-infrastructure//module/aviary-cluster"
  depends_on = [
    aws_security_group_rule.crosstalk_in,
    aws_security_group_rule.crosstalk_out,
    aws_security_group_rule.allow_cidr_in,
    aws_security_group_rule.allow_cidr_out,
    aws_security_group_rule.ssh_in,
    aws_security_group_rule.ssh_out,
    aws_security_group_rule.egress,
  ]

  name               = each.value.name
  desired_capacity   = each.value.desired_capacity
  min_capacity       = try(each.value.min_capacity, each.value.desired_capacity)
  max_capacity       = try(each.value.max_capacity, each.value.desired_capacity * 2)
  key_name           = each.value.key_name
  image_id           = each.value.image_id
  instance_type      = each.value.instance_type
  instance_use_spot  = each.value.instance_use_spot
  availability_zones = try(each.value.availability_zones, null)
  subnet_ids         = try(each.value.subnet_ids, null)

  tags = merge(local.tags_all, each.value.server ? {
    nomad_mode         = try(each.value.mode, "")
    consul_cluster_key = var.name
    nomad_cluster_key  = var.name
  } : {})

  instance_profile = aws_iam_instance_profile.instance.name
  security_groups  = [aws_security_group.crosstalk[each.value.vpc_id].id]
  target_groups    = each.value.server ? local.target_groups : []

  no_cron        = true
  inventory_url  = "https://github.com/gastrodon/cloud-infrastructure"
  inventory_path = "aviary-inventory"
  aviary_roles   = var.aviary_roles
  aviary_variables = {
    server                      = each.value.server
    nomad_datacenter            = each.value.datacenter
    aws_region                  = each.value.aws_region
    nomad_cluster_key           = local.cluster_key
    consul_datacenter           = "dc2"
    consul_token                = random_uuid.consul_token.result
    consul_cluster_key          = local.cluster_key
    bootstrap_expect            = each.value.desired_capacity
    containernetworking_version = "1.6.2"
  }
}
