locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Component   = "network"
    },
    var.tags,
  )

  # Short AZ letter (us-east-2a -> a) used to keep resource names readable.
  az_letter = { for az in var.availability_zones : az => substr(az, -1, 1) }

  # Per-role CIDR maps keyed by AZ.
  public_subnet_cidrs   = { for az in var.availability_zones : az => var.subnet_cidrs[az].public }
  app_subnet_cidrs      = { for az in var.availability_zones : az => var.subnet_cidrs[az].app }
  firewall_subnet_cidrs = { for az in var.availability_zones : az => var.subnet_cidrs[az].firewall }
  database_subnet_cidrs = { for az in var.availability_zones : az => var.subnet_cidrs[az].database }

  # AZs that host a NAT gateway.
  shared_nat_az = var.single_nat_gateway ? coalesce(var.nat_gateway_az, var.availability_zones[0]) : null
  nat_gateway_azs = toset(
    var.single_nat_gateway ? [local.shared_nat_az] : var.availability_zones
  )

  # AZ of the NAT gateway each application subnet egresses through.
  app_nat_az = {
    for az in var.availability_zones : az => var.single_nat_gateway ? local.shared_nat_az : az
  }

  # Cluster discovery tags are only meaningful once EKS exists; opt-in via eks_cluster_name.
  cluster_tags = var.eks_cluster_name == null ? {} : {
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}
