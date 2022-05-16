// VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    "Name" = "main"
  }
}

// Subnets
resource "aws_subnet" "eks_control_plane_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name                                        = "EKS_control_plane_1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "eks_control_plane_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name                                        = "EKS_control_plane_2"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "eks_workers_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.8.0/21"

  tags = {
    Name                                        = "EKS_workers_1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "eks_workers_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.16.0/21"

  tags = {
    Name                                        = "EKS_workers_2"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_subnet" "eks_lb_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"

  tags = {
    Name = "EKS_lb_1"
  }
}

resource "aws_subnet" "eks_lb_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.4.0/24"

  tags = {
    Name = "EKS_lb_2"
  }
}

// Igw
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

// routing tables
resource "aws_route_table" "eks_control_plane_1" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "EKS_control_plane_1"
  }
}

resource "aws_route_table_association" "eks_control_plane_1" {
  subnet_id      = aws_subnet.eks_control_plane_1.id
  route_table_id = aws_route_table.eks_control_plane_1.id
}

resource "aws_route_table" "eks_control_plane_2" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "EKS_control_plane_2"
  }
}

resource "aws_route_table_association" "eks_control_plane_2" {
  subnet_id      = aws_subnet.eks_control_plane_2.id
  route_table_id = aws_route_table.eks_control_plane_2.id
}

resource "aws_route_table" "eks_workers_1" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "EKS_workers_1"
  }
}

resource "aws_route_table_association" "eks_workers_1" {
  subnet_id      = aws_subnet.eks_workers_1.id
  route_table_id = aws_route_table.eks_workers_1.id
}

resource "aws_route_table" "eks_workers_2" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "EKS_workers_2"
  }
}

resource "aws_route_table_association" "eks_workers_2" {
  subnet_id      = aws_subnet.eks_workers_2.id
  route_table_id = aws_route_table.eks_workers_2.id
}


resource "aws_route_table" "eks_lb_1" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "EKS_lb_1"
  }
}

resource "aws_route_table_association" "eks_lb_1" {
  subnet_id      = aws_subnet.eks_lb_1.id
  route_table_id = aws_route_table.eks_lb_1.id
}

resource "aws_route_table" "eks_lb_2" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "EKS_lb_2"
  }
}

resource "aws_route_table_association" "eks_lb_2" {
  subnet_id      = aws_subnet.eks_lb_2.id
  route_table_id = aws_route_table.eks_lb_2.id
}

// routes for public subnets
resource "aws_route" "eks_workers_1_igw" {
  route_table_id         = aws_route_table.eks_workers_1.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route" "eks_workers_2_igw" {
  route_table_id         = aws_route_table.eks_workers_2.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route" "eks_lb_1_igw" {
  route_table_id         = aws_route_table.eks_lb_1.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route" "eks_lb_2_igw" {
  route_table_id         = aws_route_table.eks_lb_2.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

