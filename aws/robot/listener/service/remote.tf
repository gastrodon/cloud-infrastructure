data "terraform_remote_state" "cluster" {
  backend = "s3"

  config = {
    bucket  = "gastrodon-terraform"
    key     = "cluster.tfstate"
    region  = "us-east-1"
    profile = "gas"
  }
}

data "terraform_remote_state" "definition" {
  backend = "s3"

  config = {
    bucket  = "gastrodon-terraform"
    key     = "robot-listener-definition.tfstate"
    region  = "us-east-1"
    profile = "gas"
  }
}
