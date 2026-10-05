output "vpc_id" {
  description = "Dev VPC ID. Null when enabled is false."
  value       = one(module.vpc[*].vpc_id)
}

output "vpc_cidr_block" {
  description = "Dev VPC CIDR. Null when enabled is false."
  value       = one(module.vpc[*].vpc_cidr_block)
}

output "subnet_ids_by_role" {
  description = "Subnet IDs grouped by role, keyed by AZ. Null when enabled is false."
  value       = one(module.vpc[*].subnet_ids_by_role)
}

output "subnet_cidrs_by_role" {
  description = "Subnet CIDRs grouped by role, keyed by AZ. Null when enabled is false."
  value       = one(module.vpc[*].subnet_cidrs_by_role)
}

output "route_table_ids_by_role" {
  description = "Route table IDs grouped by role, keyed by AZ. Null when enabled is false."
  value       = one(module.vpc[*].route_table_ids_by_role)
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs keyed by hosting AZ. Null when enabled is false."
  value       = one(module.vpc[*].nat_gateway_ids)
}

output "nat_gateway_az_by_app_az" {
  description = "NAT gateway AZ used by each application subnet. Null when enabled is false."
  value       = one(module.vpc[*].nat_gateway_az_by_app_az)
}

output "internet_gateway_id" {
  description = "Internet gateway ID. Null when enabled is false."
  value       = one(module.vpc[*].internet_gateway_id)
}

output "s3_vpc_endpoint_id" {
  description = "S3 gateway endpoint ID. Null when enabled is false."
  value       = one(module.vpc[*].s3_vpc_endpoint_id)
}

output "interface_vpc_endpoint_ids" {
  description = "Interface VPC endpoint IDs keyed by service. Null when enabled is false."
  value       = one(module.vpc[*].interface_vpc_endpoint_ids)
}

output "firewall_integration" {
  description = "Identifiers for the future security module that adds AWS Network Firewall. Null when enabled is false."
  value       = one(module.vpc[*].firewall_integration)
}

output "eks_cluster_name" {
  description = "EKS cluster name. Null when enabled is false."
  value       = one(module.eks[*].cluster_name)
}

output "eks_cluster_endpoint" {
  description = "Kubernetes API server endpoint. Null when enabled is false."
  value       = one(module.eks[*].cluster_endpoint)
}

output "eks_node_security_group_id" {
  description = "Shared security group on every worker node. Null when enabled is false."
  value       = one(module.eks[*].node_security_group_id)
}

output "eks_addon_names" {
  description = "EKS add-ons installed on the cluster. Null when enabled is false."
  value       = one(module.eks[*].addon_names)
}

output "rds_endpoint" {
  description = "PostgreSQL writer hostname. Null when enabled is false."
  value       = one(module.rds[*].endpoint)
}

output "rds_reader_endpoints" {
  description = "PostgreSQL read replica hostnames keyed by Availability Zone. Null when enabled is false."
  value       = one(module.rds[*].reader_endpoints)
}

output "rds_master_user_secret_arn" {
  description = "Secrets Manager ARN of the RDS-managed master password. Null when enabled is false."
  value       = one(module.rds[*].master_user_secret_arn)
}
