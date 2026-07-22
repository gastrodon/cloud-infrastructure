variable "instance_type" {
  description = "EC2 instance type. m7a.large (AMD, x86_64, 2 vCPU / 8GB) matches the shared 8GB hardware profile. m7a/c7a x86 keep the current AMI; arm64 (m8g/c8g) would need a rebuilt image."
  type        = string
  default     = "m7a.large"
}

variable "spot_max_price" {
  description = "Max spot price per hour. Empty string = cap at the on-demand price (recommended)."
  type        = string
  default     = ""
}

variable "key_name" {
  description = "Name of the EC2 key pair (imported from the existing shared key). SSH is for break-glass debugging only."
  type        = string
  default     = "id_ed25519"
}

variable "ssh_public_key_path" {
  description = "Local public key whose material backs the key pair."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "modpack_bucket" {
  description = "Globally-unique S3 bucket name hosting the public modpack zip."
  type        = string
  default     = "gastrodon-glade-pack"
}

variable "modpack_key" {
  description = "Object key (filename) of the modpack zip within the bucket."
  type        = string
  default     = "glade-pack.zip"
}

variable "ami_bucket" {
  description = "Private S3 bucket used to stage the NixOS disk image for VM Import (image → snapshot → AMI). Read access is granted only to the vmimport role."
  type        = string
  default     = "gastrodon-glade-ami"
}
