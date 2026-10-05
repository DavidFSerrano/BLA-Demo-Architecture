# Gateway endpoint keeps S3 traffic from EKS nodes (image layers, logs, artifacts)
# off the NAT gateway, which removes both data processing charges and a dependency
# on egress inspection for S3 reads.
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_gateway_endpoint ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.app : rt.id]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-s3-endpoint"
  })
}

data "aws_region" "current" {}

# Interface endpoints in every application subnet. Private DNS keeps the public
# AWS hostnames, so ECR, STS, EC2, and EKS Auth traffic never uses the NAT
# gateway. ECR image layers still go to the S3 gateway endpoint above.
locals {
  interface_endpoints = var.enable_interface_endpoints ? {
    eks_auth = "eks-auth"
    ecr_api  = "ecr.api"
    ecr_dkr  = "ecr.dkr"
    sts      = "sts"
    ec2      = "ec2"
  } : {}
}

resource "aws_security_group" "interface_endpoints" {
  count = var.enable_interface_endpoints ? 1 : 0

  name        = "${local.name_prefix}-vpce"
  description = "HTTPS from the VPC to interface VPC endpoints"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpce"
  })
}

resource "aws_vpc_security_group_ingress_rule" "interface_endpoints" {
  count = var.enable_interface_endpoints ? 1 : 0

  security_group_id = aws_security_group.interface_endpoints[0].id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "Workloads in the VPC call AWS APIs on these endpoints"

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "interface_endpoints" {
  count = var.enable_interface_endpoints ? 1 : 0

  security_group_id = aws_security_group.interface_endpoints[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Interface endpoint egress"

  tags = local.common_tags
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for az in var.availability_zones : aws_subnet.app[az].id]
  security_group_ids  = [aws_security_group.interface_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}"
  })
}
