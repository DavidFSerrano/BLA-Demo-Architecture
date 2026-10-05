mock_provider "aws" {}

override_resource {
  target = aws_networkfirewall_rule_group.allow
  values = { arn = "arn:aws:network-firewall:us-east-2:637423617446:stateful-rulegroup/bla-demo-test-allow" }
}

override_resource {
  target = aws_networkfirewall_firewall_policy.this
  values = { arn = "arn:aws:network-firewall:us-east-2:637423617446:firewall-policy/bla-demo-test-egress" }
}

override_resource {
  target = aws_networkfirewall_firewall.this
  values = {
    firewall_status = [
      {
        sync_states = [
          {
            availability_zone = "us-east-2a"
            attachment        = [{ endpoint_id = "vpce-aaaaaaaaaaaaaaaaa", subnet_id = "subnet-fw-a" }]
          },
          {
            availability_zone = "us-east-2b"
            attachment        = [{ endpoint_id = "vpce-bbbbbbbbbbbbbbbbb", subnet_id = "subnet-fw-b" }]
          },
          {
            availability_zone = "us-east-2c"
            attachment        = [{ endpoint_id = "vpce-ccccccccccccccccc", subnet_id = "subnet-fw-c" }]
          },
        ]
      },
    ]
  }
}

variables {
  project     = "bla-demo"
  environment = "test"
  network = {
    vpc_id         = "vpc-0123456789abcdef0"
    vpc_cidr_block = "10.1.0.0/16"
    firewall_subnet_ids = {
      "us-east-2a" = "subnet-fw-a"
      "us-east-2b" = "subnet-fw-b"
      "us-east-2c" = "subnet-fw-c"
    }
    app_route_table_ids = {
      "us-east-2a" = "rtb-app-a"
      "us-east-2b" = "rtb-app-b"
      "us-east-2c" = "rtb-app-c"
    }
    app_subnet_cidrs = {
      "us-east-2a" = "10.1.0.0/20"
      "us-east-2b" = "10.1.16.0/20"
      "us-east-2c" = "10.1.32.0/20"
    }
    firewall_route_table_ids = {
      "us-east-2a" = "rtb-fw-a"
      "us-east-2b" = "rtb-fw-b"
      "us-east-2c" = "rtb-fw-c"
    }
    public_route_table_ids = {
      "us-east-2a" = "rtb-public-a"
      "us-east-2b" = "rtb-public-b"
      "us-east-2c" = "rtb-public-c"
    }
    nat_gateway_ids = {
      "us-east-2a" = "nat-a"
      "us-east-2b" = "nat-b"
      "us-east-2c" = "nat-c"
    }
    nat_gateway_az_by_app = {
      "us-east-2a" = "us-east-2a"
      "us-east-2b" = "us-east-2b"
      "us-east-2c" = "us-east-2c"
    }
    single_nat_gateway  = false
    internet_gateway_id = "igw-0123456789abcdef0"
  }
}

run "one_endpoint_subnet_per_zone_and_symmetric_routes" {
  command = apply

  assert {
    condition     = length(aws_networkfirewall_firewall.this.subnet_mapping) == 3
    error_message = "The firewall needs exactly one endpoint subnet in each Availability Zone."
  }

  assert {
    condition     = toset([for mapping in aws_networkfirewall_firewall.this.subnet_mapping : mapping.subnet_id]) == toset(values(var.network.firewall_subnet_ids))
    error_message = "Each endpoint must use the reserved firewall subnet for its zone."
  }

  assert {
    condition     = aws_networkfirewall_firewall_policy.this.firewall_policy[0].stateless_default_actions == toset(["aws:forward_to_sfe"])
    error_message = "Stateless traffic must be forwarded to the stateful engine."
  }

  assert {
    condition     = length(aws_route.app_default) == 3 && length(aws_route.firewall_default) == 3 && length(aws_route.public_return) == 3
    error_message = "Each zone needs an application route, a firewall route, and a return route."
  }

  assert {
    condition = alltrue([
      for az, route in aws_route.firewall_default :
      route.nat_gateway_id == var.network.nat_gateway_ids[az]
    ])
    error_message = "Each firewall subnet must egress through the NAT gateway in its own zone."
  }

  assert {
    condition = alltrue([
      for az, route in aws_route.public_return :
      route.route_table_id == var.network.public_route_table_ids[az] && route.destination_cidr_block == var.network.app_subnet_cidrs[az]
    ])
    error_message = "Return traffic for each application CIDR must come back through that zone's public route table."
  }
}

run "shared_nat_returns_through_the_nat_zone" {
  command = apply

  variables {
    network = {
      vpc_id         = "vpc-0123456789abcdef0"
      vpc_cidr_block = "10.1.0.0/16"
      firewall_subnet_ids = {
        "us-east-2a" = "subnet-fw-a"
        "us-east-2b" = "subnet-fw-b"
        "us-east-2c" = "subnet-fw-c"
      }
      app_route_table_ids = {
        "us-east-2a" = "rtb-app-a"
        "us-east-2b" = "rtb-app-b"
        "us-east-2c" = "rtb-app-c"
      }
      app_subnet_cidrs = {
        "us-east-2a" = "10.1.0.0/20"
        "us-east-2b" = "10.1.16.0/20"
        "us-east-2c" = "10.1.32.0/20"
      }
      firewall_route_table_ids = {
        "us-east-2a" = "rtb-fw-a"
        "us-east-2b" = "rtb-fw-b"
        "us-east-2c" = "rtb-fw-c"
      }
      public_route_table_ids = {
        "us-east-2a" = "rtb-public-a"
        "us-east-2b" = "rtb-public-b"
        "us-east-2c" = "rtb-public-c"
      }
      nat_gateway_ids = {
        "us-east-2a" = "nat-a"
      }
      nat_gateway_az_by_app = {
        "us-east-2a" = "us-east-2a"
        "us-east-2b" = "us-east-2a"
        "us-east-2c" = "us-east-2a"
      }
      single_nat_gateway  = true
      internet_gateway_id = "igw-0123456789abcdef0"
    }
  }

  assert {
    condition = alltrue([
      for route in aws_route.public_return :
      route.route_table_id == "rtb-public-a"
    ])
    error_message = "With one shared NAT gateway, every application CIDR returns through that gateway's public route table."
  }

  assert {
    condition = alltrue([
      for az, route in aws_route.firewall_default :
      route.nat_gateway_id == "nat-a"
    ])
    error_message = "Every firewall subnet must egress through the single shared NAT gateway."
  }
}
