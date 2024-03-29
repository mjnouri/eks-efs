terraform {
  # backend "s3" {
  #   bucket = "BUCKET_NAME_HERE"
  #   key    = "terraform-state/eks-efs/infra/terraform.tfstate"
  #   region = "REGION_HERE"
  # }
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
  region = var.region
  default_tags {
    tags = {
      owner        = var.owner
      project_name = var.project_name
      env          = var.env
    }
  }
}
