resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}_${var.env}_vpc"
  }
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.project_name}_${var.env}_ig"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }
  tags = {
    Name = "${var.project_name}_${var.env}_public_rt"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name = "${var.project_name}_${var.env}_private_rt"
  }
}

resource "aws_subnet" "public_subnet" {
  count                   = 3
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.public_subnet_cidr[count.index]
  availability_zone       = var.az[count.index]
  map_public_ip_on_launch = "true"
  tags = {
    Name                                                               = "${var.project_name}_${var.env}_public_subnet_${count.index + 1}"
    "kubernetes.io/cluster/${var.project_name}_${var.env}_eks_cluster" = "shared"
    "kubernetes.io/role/elb"                                           = 1
  }
}

resource "aws_subnet" "private_subnet" {
  count             = 3
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_cidr[count.index]
  availability_zone = var.az[count.index]
  tags = {
    Name                                                               = "${var.project_name}_${var.env}_private-subnet_${count.index + 1}"
    "kubernetes.io/cluster/${var.project_name}_${var.env}_eks_cluster" = "shared"
    "kubernetes.io/role/internal-elb"                                  = 1
  }
}

resource "aws_eip" "eip" {
  vpc = true
  tags = {
    Name = "${var.project_name}_${var.env}_eip"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  connectivity_type = "public"
  allocation_id     = aws_eip.eip.id
  subnet_id         = aws_subnet.public_subnet[0].id
  depends_on        = [aws_internet_gateway.ig]
  tags = {
    Name = "${var.project_name}_${var.env}_nat_gateway"
  }
}

resource "aws_route_table_association" "public_subnet_route_table_assoc" {
  count          = 3
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_subnet_route_table_assoc" {
  count          = 3
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_rt.id
}
