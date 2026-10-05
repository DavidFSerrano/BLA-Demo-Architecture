resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# Public subnets: NAT gateways today, internet-facing ALBs later.
resource "aws_subnet" "public" {
  for_each = local.public_subnet_cidrs

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  # ALBs and NAT gateways receive addresses explicitly; instances here should not
  # get public IPs by default.
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, local.cluster_tags, {
    Name                     = "${local.name_prefix}-public-${local.az_letter[each.key]}"
    Tier                     = "public"
    "kubernetes.io/role/elb" = "1"
  })
}

# Application subnets: future EKS nodes and VPC CNI pod addresses.
resource "aws_subnet" "app" {
  for_each = local.app_subnet_cidrs

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(local.common_tags, local.cluster_tags, {
    Name                              = "${local.name_prefix}-app-${local.az_letter[each.key]}"
    Tier                              = "app"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# Reserved for AWS Network Firewall endpoints. Nothing is deployed into these yet.
resource "aws_subnet" "firewall" {
  for_each = local.firewall_subnet_cidrs

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-firewall-${local.az_letter[each.key]}"
    Tier = "firewall"
  })
}

# Isolated database subnets for future RDS resources. No load balancer discovery tags.
resource "aws_subnet" "database" {
  for_each = local.database_subnet_cidrs

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-${local.az_letter[each.key]}"
    Tier = "database"
  })
}
