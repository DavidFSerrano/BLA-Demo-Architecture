# VPC settings, the 12-subnet layout, and the tags that future controllers rely on.

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

  tags = { Application = "appointment-booking" }
}

run "vpc_settings" {
  command = plan

  assert {
    condition     = aws_vpc.this.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR does not match the requested value."
  }

  # EKS service discovery and RDS endpoint resolution both depend on these.
  assert {
    condition     = aws_vpc.this.enable_dns_support
    error_message = "DNS support must be enabled."
  }

  assert {
    condition     = aws_vpc.this.enable_dns_hostnames
    error_message = "DNS hostnames must be enabled."
  }
}

run "twelve_subnets_one_of_each_role_per_az" {
  command = plan

  assert {
    condition = alltrue([
      length(aws_subnet.public) == 3,
      length(aws_subnet.app) == 3,
      length(aws_subnet.firewall) == 3,
      length(aws_subnet.database) == 3,
    ])
    error_message = "Expected exactly three subnets of each role."
  }

  # Keyed by AZ, so a subnet can never silently land in the wrong zone.
  assert {
    condition = alltrue(flatten([
      for az in var.availability_zones : [
        aws_subnet.public[az].availability_zone == az,
        aws_subnet.app[az].availability_zone == az,
        aws_subnet.firewall[az].availability_zone == az,
        aws_subnet.database[az].availability_zone == az,
      ]
    ]))
    error_message = "Every subnet must sit in the AZ it is keyed by."
  }

  assert {
    condition = alltrue(flatten([
      for az in var.availability_zones : [
        aws_subnet.public[az].cidr_block == var.subnet_cidrs[az].public,
        aws_subnet.app[az].cidr_block == var.subnet_cidrs[az].app,
        aws_subnet.firewall[az].cidr_block == var.subnet_cidrs[az].firewall,
        aws_subnet.database[az].cidr_block == var.subnet_cidrs[az].database,
      ]
    ]))
    error_message = "Subnet CIDRs must match the requested allocation exactly."
  }
}

run "subnet_cidrs_do_not_overlap" {
  command = plan

  # Decompose every subnet into the /28 blocks it covers. If any block appears
  # twice, two subnets overlap. Catches a typo in the address plan that the
  # variable validations cannot see.
  assert {
    condition = length(flatten([
      for cidr in flatten([for az in var.availability_zones : [
        var.subnet_cidrs[az].public,
        var.subnet_cidrs[az].app,
        var.subnet_cidrs[az].firewall,
        var.subnet_cidrs[az].database,
      ]]) :
      [for i in range(pow(2, 28 - tonumber(split("/", cidr)[1]))) :
        cidrsubnet(cidr, 28 - tonumber(split("/", cidr)[1]), i)
      ]
      ])) == length(distinct(flatten([
        for cidr in flatten([for az in var.availability_zones : [
          var.subnet_cidrs[az].public,
          var.subnet_cidrs[az].app,
          var.subnet_cidrs[az].firewall,
          var.subnet_cidrs[az].database,
        ]]) :
        [for i in range(pow(2, 28 - tonumber(split("/", cidr)[1]))) :
          cidrsubnet(cidr, 28 - tonumber(split("/", cidr)[1]), i)
        ]
    ])))
    error_message = "Subnet CIDRs overlap."
  }

  # Every subnet must sit inside the VPC range. Masking each subnet's first
  # address to the VPC prefix length must yield the VPC network address.
  assert {
    condition = alltrue(flatten([
      for az in var.availability_zones : [
        for cidr in [
          var.subnet_cidrs[az].public,
          var.subnet_cidrs[az].app,
          var.subnet_cidrs[az].firewall,
          var.subnet_cidrs[az].database,
        ] :
        cidrhost("${cidrhost(cidr, 0)}/${split("/", var.vpc_cidr)[1]}", 0) == cidrhost(var.vpc_cidr, 0)
        && tonumber(split("/", cidr)[1]) >= tonumber(split("/", var.vpc_cidr)[1])
      ]
    ]))
    error_message = "Every subnet must fall inside the VPC CIDR."
  }
}

run "application_subnets_are_sized_for_vpc_cni" {
  command = plan

  # The VPC CNI gives every pod a VPC address, so a /24 per zone would exhaust
  # within a handful of nodes. Require /20 or larger.
  assert {
    condition = alltrue([
      for az in var.availability_zones :
      tonumber(split("/", var.subnet_cidrs[az].app)[1]) <= 20
    ])
    error_message = "Application subnets must be /20 or larger to hold VPC CNI pod addresses."
  }
}

run "load_balancer_discovery_tags" {
  command = plan

  assert {
    condition = alltrue([
      for az in var.availability_zones :
      lookup(aws_subnet.public[az].tags, "kubernetes.io/role/elb", "") == "1"
    ])
    error_message = "Public subnets need the internet-facing load balancer tag."
  }

  assert {
    condition = alltrue([
      for az in var.availability_zones :
      lookup(aws_subnet.app[az].tags, "kubernetes.io/role/internal-elb", "") == "1"
    ])
    error_message = "Application subnets need the internal load balancer tag."
  }

  # Firewall and database subnets must never be selected by the load balancer
  # controller, so they carry neither tag.
  assert {
    condition = alltrue(flatten([
      for az in var.availability_zones : [
        !contains(keys(aws_subnet.firewall[az].tags), "kubernetes.io/role/elb"),
        !contains(keys(aws_subnet.firewall[az].tags), "kubernetes.io/role/internal-elb"),
        !contains(keys(aws_subnet.database[az].tags), "kubernetes.io/role/elb"),
        !contains(keys(aws_subnet.database[az].tags), "kubernetes.io/role/internal-elb"),
      ]
    ]))
    error_message = "Firewall and database subnets must not carry load balancer discovery tags."
  }
}

run "project_and_environment_tags_are_applied" {
  command = plan

  assert {
    condition = alltrue([
      aws_vpc.this.tags["Project"] == "bla-demo",
      aws_vpc.this.tags["Environment"] == "test",
      aws_vpc.this.tags["ManagedBy"] == "terraform",
      aws_vpc.this.tags["Application"] == "appointment-booking",
    ])
    error_message = "Common and caller-supplied tags must both be applied."
  }

  assert {
    condition = alltrue(flatten([
      for az in var.availability_zones : [
        aws_subnet.public[az].tags["Tier"] == "public",
        aws_subnet.app[az].tags["Tier"] == "app",
        aws_subnet.firewall[az].tags["Tier"] == "firewall",
        aws_subnet.database[az].tags["Tier"] == "database",
      ]
    ]))
    error_message = "Each subnet must carry a Tier tag matching its role."
  }
}

run "cluster_discovery_tag_is_opt_in" {
  command = plan

  assert {
    condition     = !contains(keys(aws_subnet.app["us-east-2a"].tags), "kubernetes.io/cluster/booking")
    error_message = "No cluster tag should be present when eks_cluster_name is unset."
  }
}

run "cluster_discovery_tag_when_cluster_named" {
  command = plan

  variables {
    eks_cluster_name = "booking"
  }

  assert {
    condition = alltrue(flatten([
      for az in var.availability_zones : [
        lookup(aws_subnet.app[az].tags, "kubernetes.io/cluster/booking", "") == "shared",
        lookup(aws_subnet.public[az].tags, "kubernetes.io/cluster/booking", "") == "shared",
      ]
    ]))
    error_message = "Public and application subnets need the shared cluster tag."
  }

  assert {
    condition = alltrue(flatten([
      for az in var.availability_zones : [
        !contains(keys(aws_subnet.firewall[az].tags), "kubernetes.io/cluster/booking"),
        !contains(keys(aws_subnet.database[az].tags), "kubernetes.io/cluster/booking"),
      ]
    ]))
    error_message = "Firewall and database subnets must not carry the cluster tag."
  }
}
