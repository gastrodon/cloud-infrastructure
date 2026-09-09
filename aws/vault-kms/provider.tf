terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5"
    }
  }

  # State lives in the same bucket as every other stack. The bucket is in
  # us-east-1; that is independent of where this stack's resources live.
  backend "s3" {
    bucket  = "gastrodon-terraform"
    key     = "vault-kms.tfstate"
    region  = "us-east-1"
    profile = "gas"
  }
}

# us-east-2, NOT us-east-1 like the rest of the repo. Deliberate: EVA-352 sized
# the jumpbox here because t3.micro spot is both cheapest and in the best
# interruption band (<5%) in this region, and the KMS key should sit next to the
# thing that uses it rather than paying a cross-region hop on every unseal.
#
# This is the repo's first us-east-2 stack. If the jumpbox later lands in
# us-east-1 after all, move this with it — a KMS key is cheap to recreate as
# long as Vault has not yet been initialised against it.
provider "aws" {
  allowed_account_ids = ["050883687565"] # gastrodon
  region              = "us-east-2"
  profile             = "gas"
}
