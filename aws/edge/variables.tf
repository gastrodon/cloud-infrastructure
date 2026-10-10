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
  description = "Spot pools the ASG may draw from, all >= 1 GiB and x86_64."
  type        = list(string)
  default     = ["t3.micro", "t2.micro", "t3a.micro"]
}

variable "ssh_cidrs" {
  description = "Public SSH sources; empty means SSH only over the tunnel."
  type        = list(string)
  default     = []
}

variable "domain" {
  type    = string
  default = "gastrodon.io"
}

variable "caa_issuers" {
  description = "CAA issue values for the domain; empty until the cert source is settled."
  type        = list(string)
  default     = []
}

variable "ami_bucket" {
  type    = string
  default = "gastrodon-edge-ami"
}
