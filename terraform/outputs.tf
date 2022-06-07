output "efs_dns" {
  value = aws_efs_file_system.efs.id
}

locals {
  eks_oidc = trimprefix(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://")
}

output "eks_oidc" {
  value = local.eks_oidc
}
