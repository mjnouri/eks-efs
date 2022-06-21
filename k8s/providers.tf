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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 2.11.0"
    }
  }
}

data "aws_eks_cluster" "aws_eks_cluster" {
  name = "eks1"
}

data "aws_eks_cluster_auth" "aws_eks_cluster_auth" {
  name = "eks1"
}

provider "aws" {
  region = "us-east-1"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.aws_eks_cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.aws_eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.aws_eks_cluster_auth.token
}
