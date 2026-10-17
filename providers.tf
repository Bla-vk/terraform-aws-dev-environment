terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket       = "precious-terraformstate-dev-2026" # your bucket name
    key          = "dev-environment/terraform.tfstate"
    region       = "eu-west-2"
    profile      = "vscode"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region                   = "eu-west-2"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "vscode"
}
