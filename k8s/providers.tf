data "aws_eks_cluster" "aws_eks_cluster" {
  name = "eks1"
}

data "aws_eks_cluster_auth" "aws_eks_cluster_auth" {
  name = "eks1"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.aws_eks_cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.aws_eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.aws_eks_cluster_auth.token
}
