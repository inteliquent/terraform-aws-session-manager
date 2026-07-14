terraform {
  required_providers {
    aws = {
      version = "~> 5.68"
      source  = "hashicorp/aws"
    }
  }
  required_version = ">=0.14.8"
}
