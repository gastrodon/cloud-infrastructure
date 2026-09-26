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

  # State lives in the same bucket as every other stack. The bucket is in
  # us-east-1; that is independent of where this stack's resources live.
  #
  # This state holds a live AWS access key/secret pair (aws_iam_access_key
  # below) -- the bucket has no versioning and no explicit encryption
  # beyond S3's default SSE-S3 (see vault-kms/iam.tf's own note on this).
  # Accepted knowingly for consistency with every other stack here rather
  # than a one-off local-state exception; if that tradeoff ever needs
  # revisiting, `tofu apply -replace=aws_iam_access_key.vault_unseal`
  # rotates the credential this state holds in one step regardless of
  # backend.
  backend "s3" {
    bucket  = "gastrodon-terraform"
    key     = "vault-unseal.tfstate"
    region  = "us-east-1"
    profile = "gas"
  }
}

# Same account/region as vault-kms -- this stack only references that
# one's IAM user by name, never its Terraform state.
provider "aws" {
  allowed_account_ids = ["050883687565"] # gastrodon
  region              = "us-east-2"
  profile             = "gas"
}

# Token comes from NOMAD_TOKEN -- not a variable, so it never lands in
# state or a .tfvars file.
provider "nomad" {
  address = "http://192.168.0.17:4646"
}
