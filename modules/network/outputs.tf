output "public_subnet_id" {
  value = aws_subnet.main_public_subnet.id
}

output "private_subnet_id" {
  value = aws_subnet.main_private_subnet.id
}

output "security_group_id" {
  value = aws_security_group.main_sg.id
}

output "nat_public_ip" {
  value = aws_eip.nat.public_ip
}