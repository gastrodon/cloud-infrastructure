# The key Vault seal-wraps its root key with, so a rebooted Vault unseals itself
# without a human typing a share. See EVA-303 section 5.
resource "aws_kms_key" "vault_unseal" {
  description              = "Vault auto-unseal (home Nomad cluster)"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"

  # Transparent to Vault: rotation changes the backing key, the key ID is
  # unchanged, and KMS retains old backing keys so previously-wrapped data still
  # decrypts. No Vault-side action is ever needed.
  enable_key_rotation = true

  # The maximum. This key is the only thing standing between a reboot and an
  # unrecoverable Vault: delete it and every secret Vault holds is gone, with no
  # recovery path short of the recovery keys. 30 days of "are you sure".
  deletion_window_in_days = 30

  tags = {
    Name    = "vault-unseal"
    Purpose = "vault-auto-unseal"
  }
}

resource "aws_kms_alias" "vault_unseal" {
  name          = "alias/vault-unseal"
  target_key_id = aws_kms_key.vault_unseal.key_id
}
