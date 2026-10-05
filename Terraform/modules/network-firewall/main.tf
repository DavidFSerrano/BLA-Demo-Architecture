resource "terraform_data" "layout" {
  lifecycle {
    precondition {
      condition     = toset(keys(var.network.firewall_subnet_ids)) == toset(keys(var.network.app_route_table_ids)) && toset(keys(var.network.firewall_subnet_ids)) == toset(keys(var.network.app_subnet_cidrs)) && toset(keys(var.network.firewall_subnet_ids)) == toset(keys(var.network.firewall_route_table_ids))
      error_message = "Firewall subnets, application CIDRs, and application and firewall route tables must use the same Availability Zone keys."
    }

    precondition {
      condition = alltrue([
        for az, nat_az in var.network.nat_gateway_az_by_app :
        contains(keys(var.network.nat_gateway_ids), nat_az) && contains(keys(var.network.public_route_table_ids), nat_az)
      ])
      error_message = "Each application zone must egress through a NAT gateway that has a public route table."
    }
  }
}

# One pass rule. Traffic still traverses the firewall; nothing is blocked.
resource "aws_networkfirewall_rule_group" "allow" {
  capacity = 10
  name     = "${local.name_prefix}-allow"
  type     = "STATEFUL"

  rule_group {
    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }

    rules_source {
      stateful_rule {
        action = "PASS"

        header {
          destination      = "ANY"
          destination_port = "ANY"
          direction        = "ANY"
          protocol         = "IP"
          source           = "ANY"
          source_port      = "ANY"
        }

        rule_option {
          keyword  = "sid"
          settings = ["1"]
        }
      }
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-allow"
  })
}

resource "aws_networkfirewall_firewall_policy" "this" {
  name = "${local.name_prefix}-egress"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    stateful_default_actions           = ["aws:drop_strict"]

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }

    stateful_rule_group_reference {
      priority     = 1
      resource_arn = aws_networkfirewall_rule_group.allow.arn
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-egress"
  })
}

resource "aws_networkfirewall_firewall" "this" {
  name                = "${local.name_prefix}-egress"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  vpc_id              = var.network.vpc_id

  # One endpoint in the reserved firewall subnet of each Availability Zone.
  dynamic "subnet_mapping" {
    for_each = var.network.firewall_subnet_ids

    content {
      subnet_id = subnet_mapping.value
    }
  }

  delete_protection                 = false
  subnet_change_protection          = false
  firewall_policy_change_protection = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-egress"
  })

  depends_on = [terraform_data.layout]
}

resource "aws_route" "app_default" {
  for_each = var.network.app_route_table_ids

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id = one([
    for state in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    state.attachment[0].endpoint_id
    if state.availability_zone == each.key
  ])
}

resource "aws_route" "firewall_default" {
  for_each = var.network.firewall_route_table_ids

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.network.nat_gateway_ids[var.network.nat_gateway_az_by_app[each.key]]
}

resource "aws_route" "public_return" {
  for_each = var.network.app_subnet_cidrs

  # Return traffic arrives on the public route table of the NAT gateway that
  # carried it. With one NAT per AZ that is the same zone. With one shared NAT
  # every application CIDR returns through that NAT's public route table, to
  # the firewall endpoint of the application zone.
  route_table_id         = var.network.public_route_table_ids[var.network.nat_gateway_az_by_app[each.key]]
  destination_cidr_block = each.value
  vpc_endpoint_id = one([
    for state in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    state.attachment[0].endpoint_id
    if state.availability_zone == each.key
  ])
}
