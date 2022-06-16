terraform {
  #   backend "s3" {
  #     bucket = "bucket_name"
  #     key    = "tf-state/eks-deployment/terraform.tfstate"
  #     region = "us-east-1"
  #   }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 4.14.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "= 3.4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      owner        = var.owner
      project_name = var.project_name
      env          = var.env
    }
  }
}
