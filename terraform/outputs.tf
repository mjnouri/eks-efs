# output "eks_id" {
#   value = aws_eks_cluster.eks1.id
# }

output "efs_dns" {
  value = aws_efs_file_system.efs.dns_name
}
