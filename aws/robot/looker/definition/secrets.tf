resource "aws_ssm_parameter" "ifunny_bearer" {
  name  = "/robot/looker/IFUNNY_BEARER"
  value = var.ifunny_bearer
  type  = "SecureString"
}

resource "aws_ssm_parameter" "ifunny_admin" {
  name  = "/robot/looker/IFUNNY_ADMIN"
  value = var.ifunny_admin
  type  = "SecureString"
}
