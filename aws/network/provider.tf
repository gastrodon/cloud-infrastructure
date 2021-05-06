terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>3"
    }
  }

  backend "s3" {
    bucket  = "gastrodon-terraform"
    key     = "network.tfstate"
    region  = "us-east-1"
    profile = "gas"
  }
}

provider "aws" {
  allowed_account_ids = ["050883687565"] # gastrodon
  region              = "us-east-1"
  profile             = "gas"
}
