terraform {
  backend "s3" {
    bucket = "nj-devils"
    key    = "tf-state/eks-efs/terraform.tfstate"
    region = "us-east-1"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 4.14.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
