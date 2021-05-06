variable "discord_token" {
  type      = string
  sensitive = true
}

variable "task_cpu" {
  type    = number
  default = 256
}

variable "task_ram" {
  type    = number
  default = 512
}
