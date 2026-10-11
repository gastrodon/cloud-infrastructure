variable "nix_modules_rev" {
  description = "lab/nix-modules commit the AMI is built from (its edgeAmazonImage output)."
  type        = string
}

variable "home_peers" {
  description = "Home servers that dial in, LAN IP => WireGuard public key (`ssh root@<ip> wg show wg-edge public-key`)."
  type        = map(string)
  default     = {}
}

variable "instance_types" {
  description = "Spot pools the ASG may draw from: Nitro only (the AMI has no Xen blkfront), >= 1 GiB, x86_64."
  type        = list(string)
  default     = ["t3.micro", "t3a.micro"]
}

variable "ssh_cidrs" {
  description = "Public SSH sources (the home IP); passed with -var so it stays out of the repo."
  type        = list(string)

  validation {
    condition     = length(var.ssh_cidrs) > 0
    error_message = "ssh_cidrs needs at least one CIDR; an apply without it would delete the SSH rule."
  }
}

variable "domain" {
  type    = string
  default = "gastrodon.io"
}

variable "caa_issuers" {
  description = "CAs allowed to issue for the domain (CAA issue values)."
  type        = list(string)
  default     = ["letsencrypt.org"]
}

variable "ami_bucket" {
  type    = string
  default = "gastrodon-edge-ami"
}
