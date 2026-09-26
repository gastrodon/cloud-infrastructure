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
  # Migration to encrypted state completed 2026-09-26 -- the
  # unencrypted/fallback migration path used to get here is gone; see git
  # history for that shape if this ever needs repeating on another stack.
  encryption {
    key_provider "pbkdf2" "passphrase" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "passphrase" {
      keys = key_provider.pbkdf2.passphrase
    }
    state {
      method   = method.aes_gcm.passphrase
      enforced = true
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
