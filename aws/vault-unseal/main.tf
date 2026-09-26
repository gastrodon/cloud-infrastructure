# vault-unseal (the IAM user + KMS key) already exists -- vault-kms/iam.tf,
# vault-kms/kms.tf. This stack only mints a key for it and hands the pair to
# Bao's Nomad job, so it references the user by name and never touches
# vault-kms's own Terraform state.
#
# Reuses Vault's existing key rather than provisioning a new one: Vault is
# being decommissioned and was the key's only other consumer, so there's no
# blast-radius reason to keep them separate.
resource "aws_iam_access_key" "vault_unseal" {
  user = "vault-unseal"
}

# job-name-scoped by Nomad workload identity: the openbao job can only read
# nomad/jobs/openbao, not nomad/jobs/vault -- so this is a new Variable, not
# a repoint of Vault's old one, even though it carries the same key.
resource "nomad_variable" "openbao_unseal" {
  path = "nomad/jobs/openbao"
  items = {
    aws_access_key_id      = aws_iam_access_key.vault_unseal.id
    aws_secret_access_key  = aws_iam_access_key.vault_unseal.secret
    kms_key_id             = "9ac58c81-5155-4391-b8c2-3b8ac53d8cde" # vault-kms's kms_key_id output -- not secret
  }
}
