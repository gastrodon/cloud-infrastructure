variable "database_user" {
  type    = string
  default = "looker"
}

variable "database_password" {
  type      = string
  sensitive = true
}
