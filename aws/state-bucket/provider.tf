terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>3"
    }
  }

  backend "s3" {
    bucket  = "gastrodon-terraform"
    key     = "state-bucket.tfstate"
    profile = "gas"
    region  = "us-east-1"
  }
}

provider "aws" {
  allowed_account_ids = ["050883687565"]
  region              = "us-east-1"
  profile             = "gas"
}
