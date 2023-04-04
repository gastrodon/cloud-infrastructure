variable "database_user" {
  type    = string
  default = "looker"
}

variable "database_password" {
  type      = string
  sensitive = true
}

output "database_connection" {
  value     = "${var.database_user}:${var.database_password}@tcp(${aws_db_instance.database.endpoint})/looker"
  sensitive = true
}
