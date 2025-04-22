variable "name" {
  description = "Autoscaling group and derivative name"
  type        = string
}

variable "server" {
  description = "Is this autoscaling group for server nodes?"
  type        = bool
  default     = false
}

variable "image_id" {
  type = string
}

variable "desired_capacity" {
  type = number
}

variable "min_capacity" {
  type = number
}

variable "max_capacity" {
  type = number
}

variable "instance_profile" {
  description = "Instance profile attached to nodes"
  type        = string
  default     = null
}

variable "no_cron" {
  description = "Disable aviary cron?"
  type        = bool
  default     = false
}

variable "inventory_url" {
  description = "Aviary inventory url"
  type        = string
}

variable "inventory_branch" {
  description = "Branch to checkout once inventory_url is cloned"
  type        = string
  default     = "master"
}

variable "aviary_ref" {
  description = "Aviary version to install"
  type        = string
  default     = "tags/v1.5.1"
}

variable "aviary_config" {
  description = "Aviary configuration values"
  type        = map(string)
  default     = {}
}

variable "aviary_roles" {
  description = "Aviary roles to assume"
  type        = set(string)
  default     = []
}

variable "aviary_modules" {
  description = "Aviary modules to apply"
  type        = set(string)
  default     = []
}

variable "aviary_variables" {
  description = "Aviary variables to set"
  type        = map(any)
  default     = {}
}

variable "tags" {
  description = "Tags to attach to instances"
  type        = map(string)
  default     = {}
}

variable "user_data" {
  type    = string
  default = null
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "instance_type" {
  type = string
}

variable "instance_use_spot" {
  description = "Launch spot instances?"
  type        = bool
  default     = false
}

variable "instance_allocation_strategy" {
  type    = string
  default = "capacity-optimized"
}

variable "volume_size" {
  type    = number
  default = 30
}

variable "availability_zones" {
  description = "Collection of availability zone ids to place instances in"
  type        = set(string)
  default     = null
}

variable "subnet_ids" { // TODO conflict with availability_zones
  description = "Collection of subnet ids to place instances in."
  type        = set(string)
  default     = null
}

variable "security_groups" {
  description = "Collection of security group ids to attach to instances"
  type        = set(string)
  default     = []
}

variable "target_groups" {
  description = "Collection of target group ARNs to attach instances to"
  type        = set(string)
  default     = []
}
