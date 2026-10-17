# Looks up my current public IP on every plan/apply (moved from datasources.tf)
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}

resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.100.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "main_public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.100.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-2a"

  tags = {
    Name = "dev-public-subnet"
  }
}

resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "dev-igw"
  }
}

resource "aws_route_table" "main_public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "dev-public-route-table"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.main_public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_igw.id
}

resource "aws_route_table_association" "main_public_association" {
  subnet_id      = aws_subnet.main_public_subnet.id
  route_table_id = aws_route_table.main_public_route_table.id
}

resource "aws_security_group" "main_sg" {
  name        = "dev-sg"
  description = "dev security group"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description = "SSH from my current IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]
  }

  ingress {
    description = "HTTP from my current IP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "main_private_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.100.2.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "dev-private-subnet"
  }
}
