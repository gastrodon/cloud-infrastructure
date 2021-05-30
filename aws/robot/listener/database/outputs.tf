output "database_connection" {
  value = aws_ssm_parameter.endpoint.arn
}
