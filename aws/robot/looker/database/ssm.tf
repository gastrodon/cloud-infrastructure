resource "aws_ssm_parameter" "endpoint" {
  name  = "/robot/looker/IFUNNY_STATS_CONNECTION"
  value = "${var.database_user}:${var.database_password}@tcp(${aws_db_instance.database.endpoint})/looker"
  type  = "SecureString"
}
