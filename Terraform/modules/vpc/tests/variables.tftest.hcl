# Input validation. Each run supplies one bad value and expects the matching
# variable validation to reject it.

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

run "valid_inputs_are_accepted" {
  command = plan
}

run "rejects_malformed_vpc_cidr" {
  command = plan

  variables {
    vpc_cidr = "10.0.0.0/33"
  }

  expect_failures = [var.vpc_cidr]
}

run "rejects_malformed_subnet_cidr" {
  command = plan

  variables {
    subnet_cidrs = {
      "us-east-2a" = { app = "not-a-cidr", public = "10.0.64.0/24", firewall = "10.0.80.0/28", database = "10.0.96.0/24" }
      "us-east-2b" = { app = "10.0.16.0/20", public = "10.0.65.0/24", firewall = "10.0.80.16/28", database = "10.0.97.0/24" }
      "us-east-2c" = { app = "10.0.32.0/20", public = "10.0.66.0/24", firewall = "10.0.80.32/28", database = "10.0.98.0/24" }
    }
  }

  expect_failures = [var.subnet_cidrs]
}

# A CIDR map that does not cover every AZ would otherwise fail deep inside the
# resource graph with a confusing key lookup error.
run "rejects_subnet_cidrs_missing_an_az" {
  command = plan

  variables {
    subnet_cidrs = {
      "us-east-2a" = { app = "10.0.0.0/20", public = "10.0.64.0/24", firewall = "10.0.80.0/28", database = "10.0.96.0/24" }
      "us-east-2b" = { app = "10.0.16.0/20", public = "10.0.65.0/24", firewall = "10.0.80.16/28", database = "10.0.97.0/24" }
    }
  }

  expect_failures = [var.subnet_cidrs]
}

run "rejects_subnet_cidrs_for_an_unknown_az" {
  command = plan

  variables {
    subnet_cidrs = {
      "us-east-2a" = { app = "10.0.0.0/20", public = "10.0.64.0/24", firewall = "10.0.80.0/28", database = "10.0.96.0/24" }
      "us-east-2b" = { app = "10.0.16.0/20", public = "10.0.65.0/24", firewall = "10.0.80.16/28", database = "10.0.97.0/24" }
      "us-east-2c" = { app = "10.0.32.0/20", public = "10.0.66.0/24", firewall = "10.0.80.32/28", database = "10.0.98.0/24" }
      "us-east-2d" = { app = "10.0.48.0/20", public = "10.0.67.0/24", firewall = "10.0.80.48/28", database = "10.0.99.0/24" }
    }
  }

  expect_failures = [var.subnet_cidrs]
}

run "rejects_single_availability_zone" {
  command = plan

  variables {
    availability_zones = ["us-east-2a"]

    subnet_cidrs = {
      "us-east-2a" = { app = "10.0.0.0/20", public = "10.0.64.0/24", firewall = "10.0.80.0/28", database = "10.0.96.0/24" }
    }
  }

  expect_failures = [var.availability_zones]
}

run "rejects_duplicate_availability_zones" {
  command = plan

  variables {
    availability_zones = ["us-east-2a", "us-east-2a", "us-east-2c"]
  }

  expect_failures = [var.availability_zones]
}

run "rejects_nat_gateway_az_outside_availability_zones" {
  command = plan

  variables {
    single_nat_gateway = true
    nat_gateway_az     = "us-west-2a"
  }

  expect_failures = [var.nat_gateway_az]
}
