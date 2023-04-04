output "database_connection" {
  value = aws_ssm_parameter.endpoint.arn
}

output "database_connection_string" {
  value     = "${var.database_user}:${var.database_password}@tcp(${aws_db_instance.database.endpoint})/looker"
  sensitive = true
}
