locals {
  tags_all = { "Nomad Cluster" = var.name }
}

variable "name" {
  description = "name of the nomad cluster"
  type        = string
}

variable "aviary_roles" {
  description = "Aviary roles to attach"
  type        = set(string)
  default     = ["nomad-cluster"]
}

variable "autoscaling_groups" {
  description = "Autoscaling group descriptors"
  default     = []
  type        = any
}

variable "domain" {
  description = "FQDN that should route to this cluster"
  type        = string
}

variable "domain_extra" {
  description = "Extra domains that can route to this cluster"
  type        = list(string)
  default     = []
}

variable "certificate_arn" {
  description = "ARN pointing to an ACM certificate valid for var.domain"
  type        = string
}

variable "route53_zone" {
  description = "Route53 zone to create dns records in"
  type        = string
}

variable "lb_subnet_ids" {
  description = "Collection of subnets the load balancer can exist in"
  type        = set(string)

  validation {
    condition     = length(var.lb_subnet_ids) >= 2
    error_message = "At least 2 subnet ids are required."
  }
}

variable "ssh_key_name" {
  description = "SSH key for accessing capacity"
  type        = string
}

variable "vpc_id" {
  description = "VPC to deploy capacity into"
  type        = string
}

output "cluster_key" {
  value = local.cluster_key
}

output "balancer_arn" {
  value = aws_lb.nomad.arn
}

output "instance_role_id" {
  value = aws_iam_role.instance.id
}

output "consul_token" {
  value = random_uuid.consul_token.result
}
