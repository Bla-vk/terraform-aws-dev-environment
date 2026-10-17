data "aws_ami" "test_ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# Allows SSH only from the public dev-sg (the jump host), not from the internet
resource "aws_security_group" "private_test_sg" {
  name        = "dev-private-test-sg"
  description = "SSH from the jump host only"
  vpc_id      = data.aws_subnet.private.vpc_id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [module.network.security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_subnet" "private" {
  id = module.network.private_subnet_id
}

resource "aws_instance" "private_test" {
  ami                    = data.aws_ami.test_ami.id
  instance_type          = "t3.micro"
  subnet_id              = module.network.private_subnet_id
  vpc_security_group_ids = [aws_security_group.private_test_sg.id]
  key_name               = "main-key"
  depends_on             = [module.compute]

  tags = { Name = "dev-private-test" }
}

output "private_test_ip" {
  value = aws_instance.private_test.private_ip
}