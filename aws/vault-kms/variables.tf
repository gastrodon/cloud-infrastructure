variable "state_passphrase" {
  description = "Encrypts this stack's state (client-side, on top of the shared S3 backend). At least 16 characters; losing it means re-importing everything. This stack's state holds a live AWS access key -- treat the passphrase accordingly."
  type        = string
  sensitive   = true
}
