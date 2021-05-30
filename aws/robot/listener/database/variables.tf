variable "database_user" {
  type    = string
  default = "listener"
}

variable "database_password" {
  type      = string
  sensitive = true
}
