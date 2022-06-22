output "eks_api_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "efs_id" {
  value = aws_efs_file_system.efs.id
}

output "eks_serviceaccount_role" {
  value = aws_iam_role.eks_serviceaccount_role.arn
}
