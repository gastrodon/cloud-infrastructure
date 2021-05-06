data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket  = "gastrodon-terraform"
    key     = "network.tfstate"
    region  = "us-east-1"
    profile = "gas"
  }
}
