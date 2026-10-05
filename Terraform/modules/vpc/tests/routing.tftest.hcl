# Route tables, associations, and the two NAT gateway topologies.
#
# These runs use `command = apply` because resource IDs are only known after
# apply, and the per-AZ routing assertions compare them. The provider is mocked,
# so nothing is created in AWS and no credentials are needed.

mock_provider "aws" {}

override_data {
  target = data.aws_region.current
  values = { region = "us-east-2" }
}

# Deterministic NAT gateway IDs so the per-AZ routing assertions below are
# unambiguous rather than comparing two mock-generated strings.
override_resource {
  target = aws_nat_gateway.this["us-east-2a"]
  values = { id = "nat-aaaaaaaaaaaaaaaaa" }
}

override_resource {
  target = aws_nat_gateway.this["us-east-2b"]
  values = { id = "nat-bbbbbbbbbbbbbbbbb" }
}

override_resource {
  target = aws_nat_gateway.this["us-east-2c"]
  values = { id = "nat-ccccccccccccccccc" }
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

run "every_subnet_has_its_own_route_table_and_association" {
  command = apply

  # Per-AZ tables for all four roles: 12 tables, 12 associations. Nothing is
  # allowed to fall back to the VPC main route table.
  assert {
    condition = alltrue([
      length(aws_route_table.public) == 3,
      length(aws_route_table.app) == 3,
      length(aws_route_table.firewall) == 3,
      length(aws_route_table.database) == 3,
    ])
    error_message = "Expected one route table per role per AZ."
  }

  assert {
    condition = alltrue([
      length(aws_route_table_association.public) == 3,
      length(aws_route_table_association.app) == 3,
      length(aws_route_table_association.firewall) == 3,
      length(aws_route_table_association.database) == 3,
    ])
    error_message = "Every one of the 12 subnets must be explicitly associated."
  }

  assert {
    condition = alltrue(flatten([
      for az in var.availability_zones : [
        aws_route_table_association.public[az].subnet_id == aws_subnet.public[az].id,
        aws_route_table_association.app[az].subnet_id == aws_subnet.app[az].id,
        aws_route_table_association.firewall[az].subnet_id == aws_subnet.firewall[az].id,
        aws_route_table_association.database[az].subnet_id == aws_subnet.database[az].id,
      ]
    ]))
    error_message = "Each association must bind a subnet to the table for its own AZ."
  }
}

run "public_subnets_default_to_the_internet_gateway" {
  command = apply

  assert {
    condition = alltrue([
      for az in var.availability_zones :
      aws_route.public_default[az].gateway_id == aws_internet_gateway.this.id
      && aws_route.public_default[az].destination_cidr_block == "0.0.0.0/0"
    ])
    error_message = "Public route tables must default to the internet gateway."
  }
}

run "only_public_and_app_tables_have_default_routes" {
  command = apply

  # The module declares no routes for the firewall or database tables, so the
  # total route count is the proof that neither has an internet path.
  assert {
    condition     = length(aws_route.public_default) == 3 && length(aws_route.app_default) == 3
    error_message = "Expected exactly three public and three application default routes."
  }
}

# --- Dev topology: one shared NAT gateway -------------------------------------

run "shared_nat_gateway" {
  command = apply

  variables {
    single_nat_gateway = true
    nat_gateway_az     = "us-east-2a"
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1 && length(aws_eip.nat) == 1
    error_message = "A shared NAT configuration must create exactly one gateway and one EIP."
  }

  assert {
    condition     = aws_nat_gateway.this["us-east-2a"].subnet_id == aws_subnet.public["us-east-2a"].id
    error_message = "The NAT gateway must live in the public subnet of its own AZ."
  }

  # All three zones egress through the single gateway, which is the documented
  # cost-over-availability tradeoff.
  assert {
    condition = alltrue([
      for az in var.availability_zones :
      aws_route.app_default[az].nat_gateway_id == "nat-aaaaaaaaaaaaaaaaa"
    ])
    error_message = "Every application subnet must route to the shared NAT gateway."
  }

  assert {
    condition = alltrue([
      for az in var.availability_zones :
      output.nat_gateway_az_by_app_az[az] == "us-east-2a"
    ])
    error_message = "nat_gateway_az_by_app_az must report the shared gateway for every AZ."
  }
}

run "shared_nat_gateway_defaults_to_first_az" {
  command = apply

  variables {
    single_nat_gateway = true
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "Expected a single NAT gateway."
  }

  assert {
    condition     = aws_nat_gateway.this["us-east-2a"].subnet_id == aws_subnet.public["us-east-2a"].id
    error_message = "With nat_gateway_az unset the gateway must land in the first AZ."
  }
}

# --- Prod topology: one NAT gateway per AZ ------------------------------------

run "nat_gateway_per_az" {
  command = apply

  variables {
    single_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 3 && length(aws_eip.nat) == 3
    error_message = "Expected one NAT gateway and one EIP per AZ."
  }

  assert {
    condition = alltrue([
      for az in var.availability_zones :
      aws_nat_gateway.this[az].subnet_id == aws_subnet.public[az].id
    ])
    error_message = "Each NAT gateway must sit in the public subnet of its own AZ."
  }

  # The point of per-AZ NAT: no normal egress crosses a zone boundary, so a
  # zone failure is contained.
  assert {
    condition = alltrue([
      aws_route.app_default["us-east-2a"].nat_gateway_id == "nat-aaaaaaaaaaaaaaaaa",
      aws_route.app_default["us-east-2b"].nat_gateway_id == "nat-bbbbbbbbbbbbbbbbb",
      aws_route.app_default["us-east-2c"].nat_gateway_id == "nat-ccccccccccccccccc",
    ])
    error_message = "Each application subnet must egress through the NAT gateway in its own AZ."
  }

  assert {
    condition = alltrue([
      for az in var.availability_zones :
      output.nat_gateway_az_by_app_az[az] == az
    ])
    error_message = "nat_gateway_az_by_app_az must map each AZ to itself."
  }
}
