terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5"
    }
    # local-exec nix build (null) + reading its metadata back (local).
    null = {
      source  = "hashicorp/null"
      version = "~>3"
    }
    local = {
      source  = "hashicorp/local"
      version = "~>2"
    }
  }

  backend "s3" {
    bucket  = "gastrodon-terraform"
    key     = "minecraft.tfstate"
    region  = "us-east-1"
    profile = "gas"
  }
}

provider "aws" {
  allowed_account_ids = ["050883687565"] # gastrodon
  region              = "us-east-1"
  profile             = "gas"
}
