resource "aws_iam_role" "eks_cluster_role" {
  name               = "${var.project_name}_eks_cluster_role"
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
  name     = "eks1"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.21"
  vpc_config {
    subnet_ids = [aws_subnet.public_subnet[0].id, aws_subnet.public_subnet[1].id, aws_subnet.public_subnet[2].id]
  }
  tags = {
    Name = "eks1"
  }
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name eks1 --region us-east-1"
  }
}

resource "aws_iam_role" "eks_nodes_role" {
  name               = "${var.project_name}_eks_nodes_role"
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
  subnet_ids      = [aws_subnet.public_subnet[0].id, aws_subnet.public_subnet[1].id, aws_subnet.public_subnet[2].id]
  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy_attachment,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy_attachment,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly_attachment
  ]
}

resource "aws_iam_policy" "eks_serviceaccount_policy" {
  name        = "EFSCSIControllerIAMPolicy"
  description = "Grant access to EFS Access Point"

  policy = jsonencode({
    "Version":"2012-10-17",
    "Statement":[
       {
          "Effect":"Allow",
          "Action":[
             "elasticfilesystem:DescribeAccessPoints",
             "elasticfilesystem:DescribeFileSystems"
          ],
          "Resource":"*"
       },
       {
          "Effect":"Allow",
          "Action":[
             "elasticfilesystem:CreateAccessPoint"
          ],
          "Resource":"*",
          "Condition":{
             "StringLike":{
                "aws:RequestTag/efs.csi.aws.com/cluster":"true"
             }
          }
       },
       {
          "Effect":"Allow",
          "Action":"elasticfilesystem:DeleteAccessPoint",
          "Resource":"*",
          "Condition":{
             "StringEquals":{
                "aws:ResourceTag/efs.csi.aws.com/cluster":"true"
             }
          }
       }
    ]
  })
}

resource "aws_iam_role" "eks_serviceaccount_role" {
  name               = "${var.project_name}_eks_serviceaccount_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::765981046280:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/64A0F61BE36D445CC24A657B7B3872A6"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/64A0F61BE36D445CC24A657B7B3872A6:aud": "sts.amazonaws.com",
          "oidc.eks.us-east-1.amazonaws.com/id/64A0F61BE36D445CC24A657B7B3872A6:sub": "system:serviceaccount:efs-ns:efs-sa"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attachit" {
  policy_arn = aws_iam_policy.eks_serviceaccount_policy.arn
  role       = aws_iam_role.eks_serviceaccount_role.name
}
