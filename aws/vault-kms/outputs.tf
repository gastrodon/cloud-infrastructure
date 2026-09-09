output "kms_key_id" {
  description = "Key ID for VAULT_AWSKMS_SEAL_KEY_ID in the Vault job."
  value       = aws_kms_key.vault_unseal.key_id
}

output "kms_key_arn" {
  description = "Full ARN — what the IAM policy scopes to."
  value       = aws_kms_key.vault_unseal.arn
}

output "kms_alias" {
  description = "Stable alias. Prefer the key ID in Vault config; the alias is for humans."
  value       = aws_kms_alias.vault_unseal.name
}

output "region" {
  description = "AWS_REGION the Vault task needs. Note: not the repo's usual us-east-1."
  value       = "us-east-2"
}

output "iam_user" {
  description = "Mint the access key against this user; see the note in iam.tf."
  value       = aws_iam_user.vault_unseal.name
}
