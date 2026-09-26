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
