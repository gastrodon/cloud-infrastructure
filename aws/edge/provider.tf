terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~>3"
    }
    local = {
      source  = "hashicorp/local"
      version = "~>2"
    }
    porkbun = {
      source  = "marcfrederick/porkbun"
      version = "~>1"
    }
  }

  # No profile pinned: credentials come from the environment (Bao secret/claude/aws, or AWS_PROFILE=gas).
  backend "s3" {
    bucket = "gastrodon-terraform"
    key    = "edge.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  allowed_account_ids = ["050883687565"] # gastrodon
  region              = "us-east-2"
}

# PORKBUN_API_KEY / PORKBUN_SECRET_API_KEY from Bao secret/claude/porkbun.
provider "porkbun" {}
