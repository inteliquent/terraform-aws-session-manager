terraform {
  required_providers {
    aws = {
      version = "~> 5.68"
      source  = "hashicorp/aws"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
  required_version = ">=0.14.8"
}
