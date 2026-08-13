terraform {
  required_version = ">= 1.2.0" # Ensures compatibility with your Terraform CLI

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
