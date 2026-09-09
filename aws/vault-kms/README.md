# vault-kms

The AWS half of Vault's auto-unseal (EVA-303 §5). One symmetric KMS key, one IAM
user scoped to three actions on that one key ARN.

**This is the repo's only `us-east-2` stack.** Everything else is `us-east-1`.
The reason is in `provider.tf`; if the jumpbox ends up in `us-east-1`, move this
with it rather than paying a cross-region hop on every unseal.

## Minting the credential

The access key is deliberately **not** managed by tofu — `aws_iam_access_key`
would write a live secret into state, and this repo's state bucket has no
versioning configured. Mint it out-of-band, at the moment Vault is deployed:

```sh
aws iam create-access-key --user-name vault-unseal --profile gas
```

Put the pair straight into a Nomad Variable and hand it to the Vault job through
a `template` stanza reading that variable — the pattern `mysql.nomad.hcl`,
`rabbitmq.nomad.hcl` and `traefik.nomad.hcl` already use. Never a jobspec
literal, never a host-level sops secret (that is the thing netboot is trying to
stop needing).

If the Nomad cluster is rebootstrapped the variable is lost with the keyring.
That is fine and expected: delete the old access key and mint a new one. Nothing
about the KMS key changes, and Vault's own data is unaffected.

## Vault config this produces

```hcl
seal "awskms" {}   # block must be present; values come from the environment
```

| env | value |
| --- | --- |
| `AWS_REGION` | `us-east-2` |
| `VAULT_AWSKMS_SEAL_KEY_ID` | `tofu output -raw kms_key_id` |
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
