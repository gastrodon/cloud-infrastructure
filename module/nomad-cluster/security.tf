resource "aws_security_group" "crosstalk" {
  for_each    = toset([for each in local.autoscale_iter : each.vpc_id])
  name_prefix = "${var.name}-crosstalk-${each.value}"
  vpc_id      = each.value
  tags        = local.tags_all

  lifecycle {
    ignore_changes        = [name, name_prefix]
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "crosstalk_in" {
  for_each = aws_security_group.crosstalk

  security_group_id = each.value.id
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  self              = true
}

resource "aws_security_group_rule" "crosstalk_out" {
  for_each = aws_security_group.crosstalk

  security_group_id = each.value.id
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  self              = true
}

locals {
  allow_cidr = [
    "172.30.0.0/16",
    "172.31.0.0/16",
  ]
}

resource "aws_security_group_rule" "allow_cidr_in" {
  for_each = aws_security_group.crosstalk

  security_group_id = each.value.id
  cidr_blocks       = local.allow_cidr
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
}

resource "aws_security_group_rule" "allow_cidr_out" {
  for_each = aws_security_group.crosstalk

  security_group_id = each.value.id
  cidr_blocks       = local.allow_cidr
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
}

resource "aws_security_group_rule" "ssh_in" {
  for_each = aws_security_group.crosstalk

  security_group_id = each.value.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ssh_out" {
  for_each = aws_security_group.crosstalk

  security_group_id = each.value.id
  type              = "egress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "http traffic allowed into the load balancer"
  vpc_id      = var.vpc_id
  tags        = local.tags_all
}

resource "aws_security_group_rule" "balancer_ingress" {
  for_each = toset(["80", "443"])

  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  from_port         = each.value
  to_port           = each.value
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
}

locals {
  want_egress = merge({ alb : aws_security_group.alb.id }, {
    for each in aws_security_group.crosstalk : "crosstalk-${each.vpc_id}" => each.id
  })
}

resource "aws_security_group_rule" "egress" {
  for_each = local.want_egress

  security_group_id = each.value
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

