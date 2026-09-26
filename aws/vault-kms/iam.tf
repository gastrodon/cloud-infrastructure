# Vault runs on-prem, so there is no instance profile to attach and no way to
# avoid a long-lived credential entirely. What we can do is make it the
# narrowest credential in the account: one user, three actions, one key ARN.
#
# Contrast with `claude-stone`, which carries IAMFullAccess + PowerUserAccess.
# Replacing standing credentials like that one is a large part of why Vault is
# worth deploying at all (EVA-303 section 10.2) — so this user must not become
# another of them. Do not attach anything else to it.
resource "aws_iam_user" "vault_unseal" {
  name = "vault-unseal"
  path = "/service/"

  tags = {
    Purpose = "vault-auto-unseal"
  }
}

# Exactly the three actions the awskms seal calls, on exactly one key.
# https://developer.hashicorp.com/vault/docs/configuration/seal/awskms
resource "aws_iam_user_policy" "vault_unseal" {
  name = "vault-unseal-kms"
  user = aws_iam_user.vault_unseal.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "VaultSealUnseal"
      Effect   = "Allow"
      Action   = ["kms:Encrypt", "kms:Decrypt", "kms:DescribeKey"]
      Resource = aws_kms_key.vault_unseal.arn
    }]
  })
}

# The access key IS managed here (revised from the original design, which
# kept it out of tofu state over this same bucket's lack of versioning/
# explicit encryption -- see git history for that reasoning if reviving it).
# Accepted knowingly: the alternative was a second, hand-run stack whose
# state lived in the exact same bucket anyway, buying no real isolation for
# an extra moving part. `tofu apply -replace=aws_iam_access_key.vault_unseal`
# is the entire rotation procedure regardless of where the state lives.
#
# Bao's job reads this via a Nomad Variable, not Vault's own -- Nomad
# workload identity scopes a task to nomad/jobs/<its own job name>, and
# Vault itself is being decommissioned (dead job, zero consumers), so this
# is nomad/jobs/openbao, not nomad/jobs/vault, even though it's the same
# underlying key.
resource "aws_iam_access_key" "vault_unseal" {
  user = aws_iam_user.vault_unseal.name
}

resource "nomad_variable" "openbao_unseal" {
  path = "nomad/jobs/openbao"
  items = {
    aws_access_key_id     = aws_iam_access_key.vault_unseal.id
    aws_secret_access_key = aws_iam_access_key.vault_unseal.secret
    kms_key_id            = aws_kms_key.vault_unseal.key_id
  }
}
