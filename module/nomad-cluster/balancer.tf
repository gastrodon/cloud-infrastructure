# default http - pointing to services exposed by nomad

resource "aws_lb" "nomad" {
  name                 = "${var.name}-ingress"
  internal             = false
  preserve_host_header = true
  idle_timeout         = 4000
  load_balancer_type   = "application"
  subnets              = var.lb_subnet_ids
  security_groups      = [aws_security_group.crosstalk[var.vpc_id].id, aws_security_group.alb.id]
  lifecycle { ignore_changes = [name] }

  depends_on = [
    aws_security_group_rule.balancer_ingress,
    aws_security_group_rule.egress
  ]
}

resource "aws_lb_listener" "ssl" {
  load_balancer_arn = aws_lb.nomad.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  tags              = local.tags_all
  lifecycle { ignore_changes = [certificate_arn] }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx.arn
  }

}

resource "aws_lb_listener" "ssl_redirect" {
  load_balancer_arn = aws_lb.nomad.arn
  port              = 80
  protocol          = "HTTP"
  tags              = merge({ Name = "ssl redirect" }, local.tags_all)

  default_action {
    type = "fixed-response"

    fixed_response {
      status_code  = 404
      content_type = "text/plain"
    }
  }
}

resource "aws_lb_listener_rule" "ssl_redirect" {
  listener_arn = aws_lb_listener.ssl_redirect.arn
  priority     = 99
  tags         = merge({ Name = "redirect http" }, local.tags_all)

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = concat([var.domain, "*.${var.domain}"], var.domain_extra)
    }
  }
}

resource "aws_route53_record" "nomad" {
  name    = "*.${var.domain}"
  zone_id = var.route53_zone
  type    = "CNAME"
  ttl     = 60
  records = [aws_lb.nomad.dns_name]
}

resource "aws_acm_certificate" "nomad_admin" {
  domain_name       = "*.${var.domain}"
  validation_method = "DNS"
  tags              = local.tags_all
  lifecycle { create_before_destroy = true }
}

resource "aws_route53_record" "nomad_admin_cert_verify" {
  for_each = {
    for option in aws_acm_certificate.nomad_admin.domain_validation_options : option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone
}

# admin panels - consul. / nomad.

resource "aws_lb" "admin" {
  name               = "${var.name}-admin-public"
  internal           = false
  idle_timeout       = 4000
  load_balancer_type = "application"
  subnets            = var.lb_subnet_ids
  security_groups    = [aws_security_group.crosstalk[var.vpc_id].id, aws_security_group.alb.id]
  tags               = local.tags_all
  lifecycle { ignore_changes = [name] }
}

resource "aws_lb_listener" "ssl_admin_public" {
  load_balancer_arn = aws_lb.admin.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.nomad_admin.arn
  tags              = local.tags_all

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      status_code  = 404
    }
  }

  depends_on = [aws_route53_record.nomad_admin_cert_verify]
}

resource "aws_lb_listener" "ssl_redirect_admin_public" {
  load_balancer_arn = aws_lb.admin.arn
  port              = 80
  protocol          = "HTTP"
  tags              = local.tags_all

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_route53_record" "admin" {
  name    = "nomad.${var.domain}"
  zone_id = var.route53_zone
  type    = "CNAME"
  ttl     = 60
  records = [aws_lb.admin.dns_name]
}

resource "aws_route53_record" "consul_admin_public" {
  name    = "consul.${var.domain}"
  zone_id = var.route53_zone
  type    = "CNAME"
  ttl     = 60
  records = [aws_lb.admin.dns_name]
}
