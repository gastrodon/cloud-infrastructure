resource "aws_lb_target_group" "reverse_proxy" {
  tags     = merge({ Name = "${var.name}-reverse-proxy" }, local.tags_all)
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    port    = 8080
    path    = "/ping/"
    matcher = "200"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "traefik" {
  tags     = merge({ Name = "${var.name}-traefik" }, local.tags_all)
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    port    = 8080
    path    = "/ping/"
    matcher = "200"
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_lb_listener_rule" "traefik" {
  listener_arn = aws_lb_listener.ssl_admin_public.arn
  tags         = merge({ Name = "traefik" }, local.tags_all)

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.traefik.arn
  }

  condition {
    host_header {
      values = ["traefik.${var.domain}"]
    }
  }
}


//public alb

resource "aws_lb_target_group" "nomad" {
  tags     = merge({ Name = "${var.name}-nomad" }, local.tags_all)
  port     = 4646
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    port    = 4646
    path    = "/ui/"
    matcher = "200"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener_rule" "nomad" {
  listener_arn = aws_lb_listener.ssl_admin_public.arn
  priority     = 99
  tags         = merge({ Name = "nomad" }, local.tags_all)

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nomad.arn
  }

  condition {
    host_header {
      values = ["nomad.${var.domain}"]
    }
  }
}

resource "aws_lb_target_group" "consul" {
  tags     = merge({ Name = "${var.name}-consul" }, local.tags_all)
  port     = 8500
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    port    = 8500
    path    = "/ui/"
    matcher = "200"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener_rule" "consul" {
  listener_arn = aws_lb_listener.ssl_admin_public.arn
  priority     = 80
  tags         = merge({ Name = "consul" }, local.tags_all)

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.consul.arn
  }

  condition {
    host_header {
      values = ["consul.${var.domain}"]
    }
  }
}

//*private alb

resource "aws_lb_target_group" "nomad_private" {
  tags     = merge({ Name = "${var.name}-nomad-private" }, local.tags_all)
  port     = 4646
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    port    = 4646
    path    = "/ui/"
    matcher = "200"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "consul_private" {
  tags     = merge({ Name = "${var.name}-consul-private" }, local.tags_all)
  port     = 8500
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    port    = 8500
    path    = "/ui/"
    matcher = "200"
  }

  lifecycle {
    create_before_destroy = true
  }
}
