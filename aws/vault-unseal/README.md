# vault-unseal

Mints an access key for `vault-kms`'s `vault-unseal` IAM user and hands it to
Bao's Nomad job (`lab/nomad-jobs/infra/openbao.nomad.hcl`) via a Nomad
Variable, so it can carry `seal "awskms" {}` and auto-unseal on restart
instead of needing a human to type shamir shares every time.

Separate stack from `vault-kms` on purpose: `vault-kms` owns the IAM
user/policy/KMS key (declarative, reviewable), this one owns the live
credential and its delivery to Nomad — the same split `vault-kms/README.md`
originally described, just with the "mint out-of-band, hand to Nomad by
hand" half now automated instead of manual.

## Applying

```sh
cd aws/vault-unseal
nix develop ../..   # opentofu + awscli2 + nomad, AWS_PROFILE=gas already set
export NOMAD_TOKEN=…   # a Nomad token that can write Variables
tofu init
tofu apply
```

## Rotating

```sh
tofu apply -replace=aws_iam_access_key.vault_unseal
```

Mints a new key and rewrites the Nomad Variable in one step. The old access
key stays live in AWS until deleted by hand — Terraform no longer tracks it
once replaced.

## State

Shared `gastrodon-terraform` S3 bucket, like every other stack here — see the
note in `provider.tf` on what that means for a stack whose state holds a live
credential, and why it was accepted anyway.
