output "vpc_id" {
  description = "Prod VPC ID."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "Prod VPC CIDR."
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

output "firewall_integration" {
  description = "Identifiers for the future security module that adds AWS Network Firewall."
  value       = module.vpc.firewall_integration
}
