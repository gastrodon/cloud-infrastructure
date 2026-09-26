# vault-kms

The AWS half of Vault's auto-unseal (EVA-303 §5). One symmetric KMS key, one IAM
user scoped to three actions on that one key ARN.

**This is the repo's only `us-east-2` stack.** Everything else is `us-east-1`.
The reason is in `provider.tf`; if the jumpbox ends up in `us-east-1`, move this
with it rather than paying a cross-region hop on every unseal.

## Minting the credential

`tofu apply` mints the access key (`aws_iam_access_key.vault_unseal`) and
writes it straight into a Nomad Variable (`nomad_variable.openbao_unseal`,
`nomad/jobs/openbao`) — no manual `aws iam create-access-key` step, no
jobspec literal, no host-level sops secret.

```sh
export TF_VAR_state_passphrase=…   # from the password manager -- this stack's state now holds a live AWS credential
export NOMAD_TOKEN=…                # a Nomad token that can write Variables
tofu apply
```

Rotate with:

```sh
tofu apply -replace=aws_iam_access_key.vault_unseal
```

This mints a new key and rewrites the Variable in one step. Nothing about the
KMS key changes, and Bao's own data is unaffected.

Note: Vault itself (the original consumer this stack was designed for) is
decommissioned — dead Nomad job, zero consumers, confirmed and repo-cleaned.
The key and IAM user are now Bao's; the Variable is `nomad/jobs/openbao`, not
`nomad/jobs/vault`, since Nomad workload identity scopes a task to its own
job name.

## Seal config this produces

```hcl
seal "awskms" {}   # block must be present; values come from the environment
```

| env | value |
| --- | --- |
| `AWS_REGION` | `us-east-2` |
| `VAULT_AWSKMS_SEAL_KEY_ID` | `aws_kms_key.vault_unseal.key_id` (via the Nomad Variable) |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | from the Nomad Variable |

## Verified 2026-09-09, against the live key

As `vault-unseal`, with a freshly minted key (since deleted):

* `kms:DescribeKey` → `Enabled`
* `kms:Encrypt` → 224 b64 chars of ciphertext
* `kms:Decrypt` → round-trip exact

And denied, which is the half that matters: `kms:ListKeys`, `kms:CreateKey`,
`kms:ScheduleKeyDeletion` (it cannot destroy the key it depends on),
`iam:ListUsers`, `iam:CreateAccessKey` (no privilege escalation),
`s3:ListBuckets` (cannot reach tofu state), `ec2:DescribeInstances`,
`ec2:RunInstances`.

One testing note worth keeping: `ec2:RunInstances` with a *bogus* AMI returns
`InvalidAMIID.NotFound`, not `AccessDenied` — AWS validates the AMI before the
IAM check. That reads as "allowed" if you only grep for AccessDenied. Use
`--dry-run` with a real AMI: `UnauthorizedOperation` is the authoritative denial.

## Costs and blast radius

~$1/month prorated hourly, plus $0.03 per 10k requests against a 20k/month free
tier. Vault calls KMS once per unseal, so the request cost is effectively zero.

`deletion_window_in_days = 30`, the maximum, and the IAM user cannot call
`ScheduleKeyDeletion`. **Deleting this key makes every secret in Vault
permanently unrecoverable** except via the recovery keys from `vault operator
init` — which are not unseal keys and cannot unseal a KMS-sealed Vault; they only
authorise `generate-root` and rekey operations. Store them accordingly.

Key rotation is enabled and is transparent: the key ID does not change and KMS
retains old backing keys, so previously-wrapped data still decrypts.
