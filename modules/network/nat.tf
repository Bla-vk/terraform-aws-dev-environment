# NAT gateway pieces. These bill hourly.
# If they are NOT applied yet, rename this file to nat.tf.off until the
# refactor has applied cleanly, then rename it back.

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
