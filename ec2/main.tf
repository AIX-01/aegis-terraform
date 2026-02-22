##############################################
# Terraform & Provider Configuration
##############################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "aegis-terraform-state-676323537989"
    key            = "ec2/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "aegis-terraform-lock-676323537989"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aegis"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
