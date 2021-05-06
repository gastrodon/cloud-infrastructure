data "terraform_remote_state" "cluster" {
  backend = "s3"

  config = {
    bucket  = "gastrodon-terraform"
    key     = "cluster.tfstate"
    region  = "us-east-1"
    profile = "gas"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket  = "gastrodon-terraform"
    key     = "network.tfstate"
    region  = "us-east-1"
    profile = "gas"
  }
}

data "terraform_remote_state" "security" {
  backend = "s3"

  config = {
    bucket  = "gastrodon-terraform"
    key     = "security.tfstate"
    region  = "us-east-1"
    profile = "gas"
  }
}
