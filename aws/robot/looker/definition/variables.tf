variable "ifunny_bearer" {
  type      = string
  sensitive = true
}

variable "ifunny_admin" {
  type      = string
  sensitive = true
}

variable "task_cpu" {
  type    = number
  default = 2048
}

variable "task_ram" {
  type    = number
  default = 1942
}
