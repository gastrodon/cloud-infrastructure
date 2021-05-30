resource "aws_ssm_parameter" "endpoint" {
  name  = "/robot/listener/LISTENER_CONNECTION"
  value = "${var.database_user}:${var.database_password}@tcp(${aws_db_instance.database.endpoint})/listener"
  type  = "SecureString"
}
