resource "aws_eip" "nat" {
  for_each = local.nat_gateway_azs

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-eip-${local.az_letter[each.value]}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = local.nat_gateway_azs

  allocation_id = aws_eip.nat[each.value].id
  subnet_id     = aws_subnet.public[each.value].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-${local.az_letter[each.value]}"
  })

  depends_on = [aws_internet_gateway.this]
}
