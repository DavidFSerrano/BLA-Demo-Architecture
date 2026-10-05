# modules/vpc

Reusable networking module: one VPC, 12 subnets across the supplied Availability Zones,
explicit route tables for every subnet, NAT and internet gateways, and an S3 gateway
endpoint. It deploys no compute, no database, and no firewall.

The full address plan, routing diagram, NAT tradeoff, and the future AWS Network Firewall
integration are documented in [`../../README.md`](../../README.md).

## Design notes

- **One subnet of each role per AZ.** Roles are `public`, `app`, `firewall` (reserved), and
  `database`. All four are keyed by AZ name throughout the module and the outputs, so
  callers never depend on list ordering.
- **Explicit CIDRs.** The caller passes a `subnet_cidrs` map keyed by AZ rather than a
  prefix the module subdivides. The address plan stays visible in the root module and in
  plan output, and a future subnet can be added without shifting existing ones.
- **Per-AZ route tables for public, app, and firewall.** This is what makes the firewall
  insertion a per-zone route change instead of a restructuring. Database tables are per-AZ
  too, for consistency with the outputs.
- **No implicit routing.** Every subnet has an explicit route table and association;
  nothing uses the VPC main route table. Firewall and database tables intentionally have no
  default route.
- **The module owns no firewall resources.** It exposes `firewall_integration` with the IDs
  a separate security module needs. The dependency points one way: the security module
  consumes this module's outputs, never the reverse.

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project     = "bla-demo"
  environment = "dev"
  tags        = { Application = "appointment-booking" }

  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-2a", "us-east-2b", "us-east-2c"]

  subnet_cidrs = {
    "us-east-2a" = { app = "10.0.0.0/20", public = "10.0.64.0/24", firewall = "10.0.80.0/28", database = "10.0.96.0/24" }
    "us-east-2b" = { app = "10.0.16.0/20", public = "10.0.65.0/24", firewall = "10.0.80.16/28", database = "10.0.97.0/24" }
    "us-east-2c" = { app = "10.0.32.0/20", public = "10.0.66.0/24", firewall = "10.0.80.32/28", database = "10.0.98.0/24" }
  }

  # Cost over availability: one NAT gateway shared by all three zones.
  single_nat_gateway = true
  nat_gateway_az     = "us-east-2a"
}
```

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `project` | `string` | — | Name and tag prefix. |
| `environment` | `string` | — | Environment name, used in names and tags. |
| `tags` | `map(string)` | `{}` | Extra tags merged into every resource. |
| `vpc_cidr` | `string` | — | VPC IPv4 CIDR. |
| `availability_zones` | `list(string)` | — | Ordered AZ names. Minimum two, no duplicates. |
| `subnet_cidrs` | `map(object)` | — | Per-AZ CIDRs for `public`, `app`, `firewall`, `database`. Keys must match `availability_zones` exactly. |
| `single_nat_gateway` | `bool` | `false` | Share one NAT gateway across all AZs. |
| `nat_gateway_az` | `string` | `null` | AZ hosting the shared NAT gateway. Defaults to the first AZ. |
| `enable_s3_gateway_endpoint` | `bool` | `true` | Create the S3 gateway endpoint on the app route tables. |
| `eks_cluster_name` | `string` | `null` | When set, adds `kubernetes.io/cluster/<name> = shared` to public and app subnets. |

## Outputs

| Name | Description |
| --- | --- |
| `vpc_id`, `vpc_arn`, `vpc_cidr_block` | VPC identifiers. |
| `availability_zones` | AZs the VPC spans. |
| `public_subnet_ids`, `app_subnet_ids`, `firewall_subnet_ids`, `database_subnet_ids` | Per-role subnet IDs keyed by AZ. |
| `subnet_ids_by_role`, `subnet_cidrs_by_role` | All subnet IDs / CIDRs grouped by role, keyed by AZ. |
| `subnet_id_lists_by_role` | Same IDs as AZ-ordered lists, for consumers that take a list (RDS subnet groups, EKS). |
| `route_table_ids_by_role` | Route table IDs grouped by role, keyed by AZ. |
| `nat_gateway_ids`, `nat_gateway_public_ips` | Keyed by the AZ that hosts them. |
| `nat_gateway_az_by_app_az`, `single_nat_gateway` | Which NAT gateway each app subnet egresses through. |
| `internet_gateway_id`, `s3_vpc_endpoint_id` | Gateway and endpoint IDs. |
| `firewall_integration` | Bundle of IDs a future security module needs for firewall endpoints and symmetric routes. |
