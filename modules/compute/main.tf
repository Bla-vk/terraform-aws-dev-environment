# Replace this block with your own data "aws_ami" "server_ami" from datasources.tf if yours differs
data "aws_ami" "server_ami" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_key_pair" "main_auth" {
  key_name   = "main-key"
  public_key = file("~/.ssh/mainkey.pub")
}

resource "aws_instance" "dev_node" {
  instance_type               = "t3.micro"
  ami                         = data.aws_ami.server_ami.id
  key_name                    = aws_key_pair.main_auth.key_name
  vpc_security_group_ids      = [var.security_group_id]
  subnet_id                   = var.subnet_id
  user_data                   = file("${path.module}/userdata.tpl")
  user_data_replace_on_change = true

  root_block_device {
    volume_type = "gp3"
    volume_size = 10
  }

  tags = {
    Name = "dev-node"
  }

  provisioner "local-exec" {
    command = templatefile("${path.module}/${var.host_os}-ssh-config.tpl", {
      hostname     = self.public_ip
      user         = "ubuntu"
      identityfile = "~/.ssh/mainkey"
    })

    interpreter = var.host_os == "linux" ? ["/bin/bash", "-c"] : ["powershell", "-command"]
  }
}
