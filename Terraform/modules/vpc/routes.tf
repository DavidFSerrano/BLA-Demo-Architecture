# One route table per role per AZ. Per-AZ tables keep the future firewall insertion
# a route change inside a single zone rather than a restructuring of shared tables.

resource "aws_route_table" "public" {
  for_each = local.public_subnet_cidrs

  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt-${local.az_letter[each.key]}"
    Tier = "public"
  })
}

resource "aws_route" "public_default" {
  for_each = aws_route_table.public

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[each.key].id
}

resource "aws_route_table" "app" {
  for_each = local.app_subnet_cidrs

  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-rt-${local.az_letter[each.key]}"
    Tier = "app"
  })
}

resource "aws_route_table_association" "app" {
  for_each = aws_subnet.app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id
}

# Firewall route tables exist now so the subnets are explicitly associated and never
# fall back to the main route table. They intentionally carry no default route until
# the firewall endpoints exist.
resource "aws_route_table" "firewall" {
  for_each = local.firewall_subnet_cidrs

  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-firewall-rt-${local.az_letter[each.key]}"
    Tier = "firewall"
  })
}

resource "aws_route_table_association" "firewall" {
  for_each = aws_subnet.firewall

  subnet_id      = each.value.id
  route_table_id = aws_route_table.firewall[each.key].id
}

# Database route tables carry only the implicit local route: no internet egress.
resource "aws_route_table" "database" {
  for_each = local.database_subnet_cidrs

  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-rt-${local.az_letter[each.key]}"
    Tier = "database"
  })
}

resource "aws_route_table_association" "database" {
  for_each = aws_subnet.database

  subnet_id      = each.value.id
  route_table_id = aws_route_table.database[each.key].id
}
