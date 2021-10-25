terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2"
    }
  }

  backend "kubernetes" {
    load_config_file = true
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "default"
}
