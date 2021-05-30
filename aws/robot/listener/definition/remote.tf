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

data "terraform_remote_state" "execution_role" {
  backend = "s3"

  config = {
    bucket  = "gastrodon-terraform"
    key     = "robot-shared.tfstate"
    region  = "us-east-1"
    profile = "gas"
  }
}

data "terraform_remote_state" "listener_database" {
  backend = "s3"

  config = {
    bucket  = "gastrodon-terraform"
    key     = "robot-listener-database.tfstate"
    region  = "us-east-1"
    profile = "gas"
  }
}
