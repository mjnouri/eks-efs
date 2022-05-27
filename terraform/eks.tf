resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.project_name}_eks_cluster_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = "${var.project_name}_eks_cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.21"
  vpc_config {
    subnet_ids = [ aws_subnet.public_subnet[0].id, aws_subnet.public_subnet[1].id, aws_subnet.public_subnet[2].id ]
  }
  tags = {
    Name = "${var.project_name}_eks_cluster"
  }
  provisioner "local-exec" {
    command = "aws eks --region us-east-1 update-kubeconfig --name eks_efs_eks_cluster"
  }
}

resource "aws_iam_role" "eks_nodes_role" {
  name = "${var.project_name}_eks_nodes_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes_role.name
}

resource "aws_eks_node_group" "node_group_1" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.project_name}_node_group_1"
  node_role_arn   = aws_iam_role.eks_nodes_role.arn
  instance_types  = ["t3a.small"]
  subnet_ids      = [ aws_subnet.public_subnet[0].id, aws_subnet.public_subnet[1].id, aws_subnet.public_subnet[2].id ]
  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy_attachment,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy_attachment,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly_attachment
  ]
}
