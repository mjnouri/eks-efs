resource "aws_efs_file_system" "efs" {
  creation_token   = "${var.project_name}_efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  tags = {
    Name = "${var.project_name}_efs"
  }
}

resource "aws_efs_file_system_policy" "efs_policy" {
  file_system_id = aws_efs_file_system.efs.id
  policy         = <<POLICY
{
   "Version":"2012-10-17",
   "Id":"EFSPolicy",
   "Statement":[
      {
         "Sid":"AllowEKSWorkers",
         "Principal":{
            "AWS":"*"
         },
         "Effect":"Allow",
         "Action":[
            "elasticfilesystem:ClientMount",
            "elasticfilesystem:ClientRootAccess",
            "elasticfilesystem:ClientWrite"
         ],
         "Resource":"${aws_efs_file_system.efs.arn}",
         "Condition":{
            "Bool":{
               "aws:SecureTransport":"true",
               "elasticfilesystem:AccessedViaMountTarget":"true",
               "elasticfilesystem:Encrypted":"true"
            }
         }
      }
   ]
}
POLICY
}

resource "aws_security_group" "efs_sg" {
  name   = "efs_sg"
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "efs_sg"
  }
}

resource "aws_security_group_rule" "efs_sg_ingress" {
  type              = "ingress"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"]
  security_group_id = aws_security_group.efs_sg.id
}

resource "aws_security_group_rule" "efs_sg_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.efs_sg.id
}

resource "aws_efs_mount_target" "efs_mount_target" {
  count           = 3
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = aws_subnet.public_subnet[count.index].id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_access_point" "efs_access_point" {
  file_system_id = aws_efs_file_system.efs.id
  root_directory {
    path = "/"
  }
}
