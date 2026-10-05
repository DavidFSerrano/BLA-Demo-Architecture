output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_arn" {
  description = "VPC ARN."
  value       = aws_vpc.this.arn
}

output "vpc_cidr_block" {
  description = "VPC IPv4 CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "availability_zones" {
  description = "Availability Zones this VPC spans."
  value       = var.availability_zones
}

# --- Subnets -----------------------------------------------------------------

output "public_subnet_ids" {
  description = "Public subnet IDs keyed by Availability Zone."
  value       = { for az, subnet in aws_subnet.public : az => subnet.id }
}

output "app_subnet_ids" {
  description = "Application subnet IDs keyed by Availability Zone."
  value       = { for az, subnet in aws_subnet.app : az => subnet.id }
}

output "firewall_subnet_ids" {
  description = "Reserved firewall subnet IDs keyed by Availability Zone."
  value       = { for az, subnet in aws_subnet.firewall : az => subnet.id }
}

output "database_subnet_ids" {
  description = "Database subnet IDs keyed by Availability Zone."
  value       = { for az, subnet in aws_subnet.database : az => subnet.id }
}

output "subnet_ids_by_role" {
  description = "All subnet IDs grouped by role, keyed by Availability Zone."
  value = {
    public   = { for az, subnet in aws_subnet.public : az => subnet.id }
    app      = { for az, subnet in aws_subnet.app : az => subnet.id }
    firewall = { for az, subnet in aws_subnet.firewall : az => subnet.id }
    database = { for az, subnet in aws_subnet.database : az => subnet.id }
  }
}

output "subnet_cidrs_by_role" {
  description = "All subnet CIDR blocks grouped by role, keyed by Availability Zone."
  value = {
    public   = { for az, subnet in aws_subnet.public : az => subnet.cidr_block }
    app      = { for az, subnet in aws_subnet.app : az => subnet.cidr_block }
    firewall = { for az, subnet in aws_subnet.firewall : az => subnet.cidr_block }
    database = { for az, subnet in aws_subnet.database : az => subnet.cidr_block }
  }
}

# Flat lists for consumers that take a list, such as RDS subnet groups and EKS.
output "subnet_id_lists_by_role" {
  description = "All subnet IDs grouped by role as AZ-ordered lists."
  value = {
    public   = [for az in var.availability_zones : aws_subnet.public[az].id]
    app      = [for az in var.availability_zones : aws_subnet.app[az].id]
    firewall = [for az in var.availability_zones : aws_subnet.firewall[az].id]
    database = [for az in var.availability_zones : aws_subnet.database[az].id]
  }
}

# --- Route tables ------------------------------------------------------------

output "route_table_ids_by_role" {
  description = "Route table IDs grouped by role, keyed by Availability Zone."
  value = {
    public   = { for az, rt in aws_route_table.public : az => rt.id }
    app      = { for az, rt in aws_route_table.app : az => rt.id }
    firewall = { for az, rt in aws_route_table.firewall : az => rt.id }
    database = { for az, rt in aws_route_table.database : az => rt.id }
  }
}

# --- Gateways and endpoints --------------------------------------------------

output "internet_gateway_id" {
  description = "Internet gateway ID."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs keyed by the Availability Zone that hosts them."
  value       = { for az, ngw in aws_nat_gateway.this : az => ngw.id }
}

output "nat_gateway_public_ips" {
  description = "NAT gateway Elastic IP addresses keyed by Availability Zone."
  value       = { for az, eip in aws_eip.nat : az => eip.public_ip }
}

output "nat_gateway_az_by_app_az" {
  description = "Availability Zone of the NAT gateway each application subnet egresses through. Values are identical to the key when one NAT gateway per AZ is used."
  value       = local.app_nat_az
}

output "single_nat_gateway" {
  description = "Whether the application subnets share one NAT gateway."
  value       = var.single_nat_gateway
}

output "s3_vpc_endpoint_id" {
  description = "S3 gateway endpoint ID, or null when the endpoint is disabled."
  value       = try(aws_vpc_endpoint.s3[0].id, null)
}

# --- Future firewall integration contract ------------------------------------

# Everything a future security module needs to create AWS Network Firewall endpoints
# and symmetric forward/return routes, without this module depending on it.
output "firewall_integration" {
  description = "Networking identifiers a future security module needs to insert AWS Network Firewall endpoints and symmetric routes."
  value = {
    vpc_id         = aws_vpc.this.id
    vpc_cidr_block = aws_vpc.this.cidr_block

    # Subnets the firewall endpoints are created in, one per AZ.
    firewall_subnet_ids = { for az, subnet in aws_subnet.firewall : az => subnet.id }

    # Forward path: replace the 0.0.0.0/0 target in these tables with the same-AZ
    # firewall endpoint.
    app_route_table_ids = { for az, rt in aws_route_table.app : az => rt.id }
    app_subnet_cidrs    = { for az, subnet in aws_subnet.app : az => subnet.cidr_block }

    # Firewall subnet tables need 0.0.0.0/0 to the NAT gateway in nat_gateway_az_by_app_az.
    firewall_route_table_ids = { for az, rt in aws_route_table.firewall : az => rt.id }

    # Return path: public route tables need routes for the application CIDRs back to
    # the firewall endpoint so inspection stays symmetric.
    public_route_table_ids = { for az, rt in aws_route_table.public : az => rt.id }

    nat_gateway_ids       = { for az, ngw in aws_nat_gateway.this : az => ngw.id }
    nat_gateway_az_by_app = local.app_nat_az
    single_nat_gateway    = var.single_nat_gateway
    internet_gateway_id   = aws_internet_gateway.this.id
  }
}
