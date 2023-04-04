data "terraform_remote_state" "execution_role" {
  backend = "s3"

  config = {
    bucket  = "gastrodon-terraform"
    key     = "robot-shared.tfstate"
    region  = "us-east-1"
    profile = "gas"
  }
}

data "terraform_remote_state" "looker_database" {
  backend = "s3"

  config = {
    bucket  = "gastrodon-terraform"
    key     = "robot-looker-database.tfstate"
    region  = "us-east-1"
    profile = "gas"
  }
}
