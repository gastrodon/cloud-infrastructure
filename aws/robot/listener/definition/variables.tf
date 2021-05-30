variable "discord_token" {
  type      = string
  sensitive = true
}

variable "task_cpu" {
  type    = number
  default = 128
}

variable "task_ram" {
  type    = number
  default = 64
}
