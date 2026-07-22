variable "server_type" {
  description = "Hetzner Cloud server type. cpx41 = 8 shared AMD x86 vCPU / 16GB / 240GB NVMe — the c7a.2xlarge equivalent. (The Intel cx4x/cx5x line is currently sold out across all datacenters.)"
  type        = string
  default     = "cpx41"
}

variable "location" {
  description = "Hetzner datacenter location (fsn1/nbg1/hel1 EU, ash/hil US). ash = Ashburn, Virginia (US east coast)."
  type        = string
  default     = "ash"
}

variable "image" {
  description = "Base OS image to boot before nixos-anywhere kexecs and installs NixOS over it."
  type        = string
  default     = "debian-12"
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token. Prefer the HCLOUD_TOKEN env var over setting this in a tfvars file."
  type        = string
  sensitive   = true
  default     = null
}

variable "ssh_public_key_path" {
  description = "Local public key registered with Hetzner and placed in root's authorized_keys (matches the shared id_ed25519 key)."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
