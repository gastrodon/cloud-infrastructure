terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~>1.49"
    }
  }

  # Shares the AWS state bucket with the rest of the repo; key matches the
  # hetzner/minecraft file structure. Backend needs AWS creds (profile "gas")
  # at plan/apply time — no runtime dependency on AWS.
  backend "s3" {
    bucket  = "gastrodon-terraform"
    key     = "hetzner-minecraft.tfstate"
    region  = "us-east-1"
    profile = "gas"
  }
}

provider "hcloud" {
  token = var.hcloud_token
}
