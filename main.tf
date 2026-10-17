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
    description = "HTTP from anywhere"
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

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.main_public_subnet.id # NAT lives in the PUBLIC subnet
  depends_on    = [aws_internet_gateway.main_igw]
  tags          = { Name = "dev-nat" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "dev-private-route-table" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.main_private_subnet.id
  route_table_id = aws_route_table.private.id
}

resource "aws_key_pair" "main_auth" {
  key_name   = "main-key"
  public_key = file("~/.ssh/mainkey.pub")
}

resource "aws_instance" "dev_node" {
  instance_type               = "t3.micro"
  ami                         = data.aws_ami.server_ami.id
  key_name                    = aws_key_pair.main_auth.key_name
  vpc_security_group_ids      = [aws_security_group.main_sg.id]
  subnet_id                   = aws_subnet.main_public_subnet.id
  user_data                   = file("userdata.tpl")
  user_data_replace_on_change = true


  root_block_device {
    volume_type = "gp3"
    volume_size = 10
  }

  tags = {
    Name = "dev-node"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-config.tpl", {
      hostname     = self.public_ip
      user         = "ubuntu"
      identityfile = "~/.ssh/mainkey"
    })

    interpreter = var.host_os == "linux" ? ["/bin/bash", "-c"] : ["powershell", "-command"]
  }
}

