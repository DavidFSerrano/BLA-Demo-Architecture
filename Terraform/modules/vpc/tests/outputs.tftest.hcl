# S3 gateway endpoint and the output contract that future EKS, RDS, and security
# modules consume.
#
# These runs use `command = apply` because outputs built from resource IDs are
# only resolved after apply. The provider is mocked, so nothing is created in AWS
# and no credentials are needed.

mock_provider "aws" {}

override_data {
  target = data.aws_region.current
  values = { region = "us-east-2" }
}

variables {
  project     = "bla-demo"
  environment = "test"
  vpc_cidr    = "10.0.0.0/16"

  availability_zones = ["us-east-2a", "us-east-2b", "us-east-2c"]

  subnet_cidrs = {
    "us-east-2a" = { app = "10.0.0.0/20", public = "10.0.64.0/24", firewall = "10.0.80.0/28", database = "10.0.96.0/24" }
    "us-east-2b" = { app = "10.0.16.0/20", public = "10.0.65.0/24", firewall = "10.0.80.16/28", database = "10.0.97.0/24" }
    "us-east-2c" = { app = "10.0.32.0/20", public = "10.0.66.0/24", firewall = "10.0.80.32/28", database = "10.0.98.0/24" }
  }
}

run "s3_gateway_endpoint_on_application_route_tables" {
  command = apply

  assert {
    condition     = aws_vpc_endpoint.s3[0].service_name == "com.amazonaws.us-east-2.s3"
    error_message = "The endpoint must target S3 in the provider's region."
  }

  assert {
    condition     = aws_vpc_endpoint.s3[0].vpc_endpoint_type == "Gateway"
    error_message = "A gateway endpoint, not an interface endpoint, is expected."
  }

  # Associated with the app tables only: that is where EKS node traffic to S3
  # originates, and it keeps that traffic off the NAT gateway.
  assert {
    condition = toset(aws_vpc_endpoint.s3[0].route_table_ids) == toset([
      for az in var.availability_zones : aws_route_table.app[az].id
    ])
    error_message = "The S3 endpoint must be associated with exactly the three application route tables."
  }
}

run "s3_gateway_endpoint_can_be_disabled" {
  command = apply

  variables {
    enable_s3_gateway_endpoint = false
  }

  assert {
    condition     = length(aws_vpc_endpoint.s3) == 0
    error_message = "No endpoint should be created when the flag is false."
  }

  assert {
    condition     = output.s3_vpc_endpoint_id == null
    error_message = "The endpoint output must be null when the endpoint is disabled."
  }
}

run "interface_endpoints_in_application_subnets" {
  command = apply

  assert {
    condition = toset([for endpoint in aws_vpc_endpoint.interface : endpoint.service_name]) == toset([
      "com.amazonaws.us-east-2.eks-auth",
      "com.amazonaws.us-east-2.ecr.api",
      "com.amazonaws.us-east-2.ecr.dkr",
      "com.amazonaws.us-east-2.sts",
      "com.amazonaws.us-east-2.ec2",
    ])
    error_message = "The VPC must expose interface endpoints for EKS Auth, ECR, STS, and EC2."
  }

  assert {
    condition = alltrue([
      for endpoint in aws_vpc_endpoint.interface :
      endpoint.vpc_endpoint_type == "Interface"
      && endpoint.private_dns_enabled
      && toset(endpoint.subnet_ids) == toset([for az in var.availability_zones : aws_subnet.app[az].id])
    ])
    error_message = "Interface endpoints must use private DNS and sit in every application subnet."
  }

  assert {
    condition     = toset(keys(output.interface_vpc_endpoint_ids)) == toset(["eks_auth", "ecr_api", "ecr_dkr", "sts", "ec2"])
    error_message = "interface_vpc_endpoint_ids must be keyed by those services."
  }
}

run "interface_endpoints_can_be_disabled" {
  command = apply

  variables {
    enable_interface_endpoints = false
  }

  assert {
    condition     = length(aws_vpc_endpoint.interface) == 0
    error_message = "No interface endpoints should be created when the flag is false."
  }
}

run "subnet_outputs_are_grouped_by_role_and_keyed_by_az" {
  command = apply

  assert {
    condition     = toset(keys(output.subnet_ids_by_role)) == toset(["public", "app", "firewall", "database"])
    error_message = "subnet_ids_by_role must expose all four roles."
  }

  assert {
    condition = alltrue([
      for role in ["public", "app", "firewall", "database"] :
      toset(keys(output.subnet_ids_by_role[role])) == toset(var.availability_zones)
    ])
    error_message = "Every role group must be keyed by all three AZs."
  }

  assert {
    condition = alltrue([
      for az in var.availability_zones : alltrue([
        output.subnet_cidrs_by_role["public"][az] == var.subnet_cidrs[az].public,
        output.subnet_cidrs_by_role["app"][az] == var.subnet_cidrs[az].app,
        output.subnet_cidrs_by_role["firewall"][az] == var.subnet_cidrs[az].firewall,
        output.subnet_cidrs_by_role["database"][az] == var.subnet_cidrs[az].database,
      ])
    ])
    error_message = "Reported subnet CIDRs must match the requested allocation."
  }

  # List form for consumers that take ordered lists, such as RDS subnet groups.
  assert {
    condition = alltrue([
      for role in ["public", "app", "firewall", "database"] :
      length(output.subnet_id_lists_by_role[role]) == 3
    ])
    error_message = "List-form subnet outputs must contain one entry per AZ."
  }

  assert {
    condition = output.subnet_id_lists_by_role["database"] == [
      for az in var.availability_zones : output.subnet_ids_by_role["database"][az]
    ]
    error_message = "List-form outputs must follow the availability_zones order."
  }
}

run "route_table_outputs_are_grouped_by_role_and_keyed_by_az" {
  command = apply

  assert {
    condition     = toset(keys(output.route_table_ids_by_role)) == toset(["public", "app", "firewall", "database"])
    error_message = "route_table_ids_by_role must expose all four roles."
  }

  assert {
    condition = alltrue([
      for role in ["public", "app", "firewall", "database"] :
      toset(keys(output.route_table_ids_by_role[role])) == toset(var.availability_zones)
    ])
    error_message = "Every route table group must be keyed by all three AZs."
  }
}

run "vpc_and_gateway_outputs" {
  command = apply

  assert {
    condition     = output.vpc_cidr_block == "10.0.0.0/16"
    error_message = "vpc_cidr_block must report the configured CIDR."
  }

  assert {
    condition     = output.vpc_id == aws_vpc.this.id
    error_message = "vpc_id must report the VPC."
  }

  assert {
    condition     = output.internet_gateway_id == aws_internet_gateway.this.id
    error_message = "internet_gateway_id must report the internet gateway."
  }

  assert {
    condition     = output.availability_zones == var.availability_zones
    error_message = "availability_zones must be echoed back in order."
  }
}

# The firewall_integration output is the contract a future security module builds
# against. Breaking its shape breaks that module, so its keys are pinned here.
run "firewall_integration_contract" {
  command = apply

  variables {
    single_nat_gateway = true
    nat_gateway_az     = "us-east-2a"
  }

  assert {
    condition = toset(keys(output.firewall_integration)) == toset([
      "vpc_id",
      "vpc_cidr_block",
      "firewall_subnet_ids",
      "app_route_table_ids",
      "app_subnet_cidrs",
      "firewall_route_table_ids",
      "public_route_table_ids",
      "nat_gateway_ids",
      "nat_gateway_az_by_app",
      "single_nat_gateway",
      "internet_gateway_id",
    ])
    error_message = "The firewall_integration contract changed shape."
  }

  # Endpoints are created here, one per AZ.
  assert {
    condition = alltrue([
      for az in var.availability_zones :
      output.firewall_integration.firewall_subnet_ids[az] == aws_subnet.firewall[az].id
    ])
    error_message = "firewall_subnet_ids must point at the reserved firewall subnets."
  }

  # Forward path: these are the tables whose default route gets repointed.
  assert {
    condition = alltrue([
      for az in var.availability_zones :
      output.firewall_integration.app_route_table_ids[az] == aws_route_table.app[az].id
    ])
    error_message = "app_route_table_ids must point at the application route tables."
  }

  assert {
    condition = alltrue([
      for az in var.availability_zones :
      output.firewall_integration.firewall_route_table_ids[az] == aws_route_table.firewall[az].id
    ])
    error_message = "firewall_route_table_ids must point at the firewall route tables."
  }

  # Return path: public tables need per-AZ app CIDRs to build symmetric routes.
  # Distinct CIDRs are what make the shared-NAT return routes expressible.
  assert {
    condition = alltrue([
      for az in var.availability_zones :
      output.firewall_integration.public_route_table_ids[az] == aws_route_table.public[az].id
    ])
    error_message = "public_route_table_ids must point at the public route tables."
  }

  assert {
    condition = length(distinct([
      for az in var.availability_zones : output.firewall_integration.app_subnet_cidrs[az]
    ])) == 3
    error_message = "Per-AZ application CIDRs must be distinct for symmetric return routing."
  }

  assert {
    condition     = output.firewall_integration.single_nat_gateway == true
    error_message = "The contract must surface the shared-NAT condition that needs extra return routes."
  }
}
