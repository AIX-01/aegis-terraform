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

  # S3 Backend (먼저 수동으로 S3 버킷 + DynamoDB 테이블 생성 필요)
  backend "s3" {
    bucket         = "aegis-terraform-state"
    key            = "fargate/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "aegis-terraform-lock"
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

# CloudFront용 ACM 인증서는 us-east-1에서만 발급 가능
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
