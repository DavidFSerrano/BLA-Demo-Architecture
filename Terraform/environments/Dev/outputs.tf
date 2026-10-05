output "vpc_id" {
  description = "Dev VPC ID."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "Dev VPC CIDR."
  value       = module.vpc.vpc_cidr_block
}

output "subnet_ids_by_role" {
  description = "Subnet IDs grouped by role, keyed by AZ."
  value       = module.vpc.subnet_ids_by_role
}

output "subnet_cidrs_by_role" {
  description = "Subnet CIDRs grouped by role, keyed by AZ."
  value       = module.vpc.subnet_cidrs_by_role
}

output "route_table_ids_by_role" {
  description = "Route table IDs grouped by role, keyed by AZ."
  value       = module.vpc.route_table_ids_by_role
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs keyed by hosting AZ."
  value       = module.vpc.nat_gateway_ids
}

output "nat_gateway_az_by_app_az" {
  description = "NAT gateway AZ used by each application subnet."
  value       = module.vpc.nat_gateway_az_by_app_az
}

output "internet_gateway_id" {
  description = "Internet gateway ID."
  value       = module.vpc.internet_gateway_id
}

output "s3_vpc_endpoint_id" {
  description = "S3 gateway endpoint ID."
  value       = module.vpc.s3_vpc_endpoint_id
}

output "interface_vpc_endpoint_ids" {
  description = "Interface VPC endpoint IDs keyed by service."
  value       = module.vpc.interface_vpc_endpoint_ids
}

output "firewall_integration" {
  description = "Identifiers for the future security module that adds AWS Network Firewall."
  value       = module.vpc.firewall_integration
}

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "eks_node_security_group_id" {
  description = "Shared security group on every worker node."
  value       = module.eks.node_security_group_id
}

output "eks_addon_names" {
  description = "EKS add-ons installed on the cluster."
  value       = module.eks.addon_names
}
