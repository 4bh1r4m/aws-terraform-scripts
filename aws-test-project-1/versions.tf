terraform {
  required_version = ">=1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  /*
#TF-REMOTE-STATE: storing state in S3 instead of local file for safety
  backend "s3" {
    bucket         = "abhi-terraform-state-bucket"
    key            = "3-tier-app/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = "terraform-locks"
    }
*/
}


provider "aws" {
  region = var.aws_region
}