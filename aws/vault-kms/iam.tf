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

# NOTE: the access key is deliberately NOT managed here.
#
# `aws_iam_access_key` would write the secret into tofu state, and this repo's
# state bucket (aws/state-bucket) has no versioning and no explicit encryption
# configured — it relies on S3's default SSE-S3. Putting a live credential there
# widens its footprint for no benefit, when sops already exists precisely to
# hold it.
#
# So: tofu owns the user and the policy (declarative, reviewable, diffable), and
# the key itself is minted out-of-band straight into sops. Mint with:
#
#   aws iam create-access-key --user-name vault-unseal --profile gas
#
# then put the pair in secrets.claude.yaml under aws/vault_unseal_{key,secret}
# and hand it to the Vault job as a Nomad Variable — never as a jobspec literal.
