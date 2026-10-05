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
