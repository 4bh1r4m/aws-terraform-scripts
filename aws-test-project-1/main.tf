terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

#hosted zone creation
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Environment = "dev"
    project = "3-tier-app"
  }
}

#output the name server
output "name_servers" {
  description = "name server data for hostinger"
  value = aws_route53_zone.main.name_servers
}