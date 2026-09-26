terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5"
    }
    nomad = {
      source  = "hashicorp/nomad"
      version = "~>2.6"
    }
  }

  backend "s3" {
    bucket  = "gastrodon-terraform"
    key     = "vault-kms.tfstate"
    region  = "us-east-1"
    profile = "gas"
  }

  # Wraps the S3 backend above, not a replacement for it -- state is
  # encrypted client-side before it ever reaches the bucket, independent
  # of that bucket's own (lack of) versioning/SSE config. Needed now that
  # this stack's state holds a live AWS credential (iam.tf).
  #
  # MIGRATION IN PROGRESS: this stack's existing state predates this block
  # and is unencrypted. `method.unencrypted.migrate` + the `fallback` below
  # let one `tofu apply` read the old unencrypted state and rewrite it
  # encrypted. `enforced` deliberately left off `state` during this step
  # (not just unset -- OpenTofu's own migration docs omit it here too,
  # presumably because it doesn't make sense alongside a fallback that
  # explicitly permits an unencrypted read). Once that apply succeeds:
  # delete `method "unencrypted" "migrate" {}` and the `fallback` block,
  # and add `enforced = true` to `state` to match `plan` below.
  encryption {
    method "unencrypted" "migrate" {}

    key_provider "pbkdf2" "passphrase" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "passphrase" {
      keys = key_provider.pbkdf2.passphrase
    }
    state {
      method = method.aes_gcm.passphrase
      fallback {
        method = method.unencrypted.migrate
      }
    }
    plan {
      method   = method.aes_gcm.passphrase
      enforced = true
    }
  }
}

# us-east-2 gives us cheaper spot cap
provider "aws" {
  allowed_account_ids = ["050883687565"] # gastrodon
  region              = "us-east-2"
  profile             = "gas"
}

provider "nomad" {
  address = "http://192.168.0.17:4646"
}
