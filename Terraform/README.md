# Networking foundation

Terraform for the networking layer of the appointment-booking service. This phase builds
**only** the VPC and its routing. EKS, RDS, and AWS Network Firewall are deliberately not
here; they arrive as sibling modules under `modules/` and are wired in through the outputs
documented below.

```
Terraform/
  Bootstrap/            one S3 state bucket per environment (local state, run once)
  environments/
    Dev/                root module, VPC 10.0.0.0/16, own state bucket
    Prod/               root module, VPC 10.1.0.0/16, own state bucket
  modules/
    vpc/                reusable networking module (both environments call it)
    # future siblings: eks/, rds/, security/
```

Region is `us-east-2` and each environment spans `us-east-2a`, `us-east-2b`, `us-east-2c`.
The AZ list and every subnet CIDR are module variables, so a different region or a fourth
zone is a variable change rather than a module change.

## State layout

Dev and prod use separate buckets, not separate keys in a shared bucket. The boundary is
the bucket itself, so prod state access can be granted independently and a mistake in one
environment cannot reach the other's state.

| Environment | Bucket | Key |
| --- | --- | --- |
| dev | `bla-demo-tfstate-dev-<account_id>` | `vpc/terraform.tfstate` |
| prod | `bla-demo-tfstate-prod-<account_id>` | `vpc/terraform.tfstate` |

Both buckets are versioned, encrypted (SSE-S3 with bucket keys), blocked from public
access, and deny non-TLS requests. Locking uses S3 native conditional writes
(`use_lockfile = true`), so there is no DynamoDB table to maintain.

`Bootstrap` keeps local state because it creates the buckets that everything else stores
state in. It is marked `prevent_destroy`.

## Subnet allocation

Each VPC is a `/16`. Only the lower half is allocated; the entire upper half is left free.
The pattern is identical in both environments, so `10.0.x` in dev maps to `10.1.x` in prod.

| Role | Block | us-east-2a | us-east-2b | us-east-2c | Usable IPs each |
| --- | --- | --- | --- | --- | --- |
| Application | `10.x.0.0/18` | `10.x.0.0/20` | `10.x.16.0/20` | `10.x.32.0/20` | 4091 |
| Public | `10.x.64.0/20` | `10.x.64.0/24` | `10.x.65.0/24` | `10.x.66.0/24` | 251 |
| Firewall (reserved) | `10.x.80.0/20` | `10.x.80.0/28` | `10.x.80.16/28` | `10.x.80.32/28` | 11 |
| Database | `10.x.96.0/20` | `10.x.96.0/24` | `10.x.97.0/24` | `10.x.98.0/24` | 251 |
| Free for growth | `10.x.112.0/20` + `10.x.128.0/17` | — | — | — | ~34,800 |

Why these sizes:

- **Application `/20` per AZ.** The VPC CNI assigns a real VPC address to every pod, so
  pod density, not node count, drives the size. 4091 addresses per zone supports roughly
  110-pod nodes at a comfortable ratio and leaves room for rolling replacements, which
  temporarily double address consumption. A `/24` here would exhaust within a few nodes.
- **Public `/24` per AZ.** Only NAT gateways and future internet-facing ALB nodes live
  here. ALBs consume a handful of addresses per zone and scale within that.
- **Firewall `/28` per AZ.** AWS Network Firewall endpoints require a dedicated subnet and
  `/28` is the documented recommendation. These subnets hold nothing else, ever.
- **Database `/24` per AZ.** RDS instances, replicas, and future Multi-AZ failover targets
  need very few addresses.
- **Unallocated space.** Each role block is a `/20` (or `/18` for app) while only three
  subnets are carved from it, so a fourth AZ fits without renumbering. Beyond that,
  `10.x.128.0/17` is untouched for a second cluster, VPC peering, or an unforeseen tier.

Blocks are non-overlapping and allocated per AZ in the root modules, not computed with
`cidrsubnet`, so the address plan is readable in the code and in state diffs.

## Current routing

```
public subnet      --default--> internet gateway
application subnet --default--> NAT gateway --> internet gateway
firewall subnet    (local routes only, reserved)
database subnet    (local routes only, no internet path)
```

Every one of the 12 subnets has an explicit route table and an explicit association;
nothing falls back to the VPC main route table. Public, application, and firewall tables
are per-AZ, and database tables are per-AZ too for symmetry with the outputs.

An S3 gateway endpoint is associated with the three application route tables. That keeps
image layers, logs, and artifact traffic off the NAT gateway, which removes both the data
processing charge and, later, a dependency on egress inspection for S3 reads.

Load balancer discovery tags are applied only where they should be:

| Subnet role | Tag |
| --- | --- |
| Public | `kubernetes.io/role/elb = 1` |
| Application | `kubernetes.io/role/internal-elb = 1` |
| Firewall, database | none |

The optional `eks_cluster_name` variable adds `kubernetes.io/cluster/<name> = shared` to
the public and application subnets. It is unset in both environments today; the EKS module
will supply it.

## NAT gateway tradeoff

| | Dev | Prod |
| --- | --- | --- |
| NAT gateways | 1, in `us-east-2a` | 3, one per AZ |
| Hourly cost | ~1/3 of prod | baseline |
| Cross-AZ data charge | yes, for `2b` and `2c` egress | none |
| Zone failure impact | all three AZs lose egress | contained to the failed zone |

Dev deliberately takes the cheaper, less available option: one NAT gateway with one
Elastic IP, shared by the application subnets in all three zones. Losing `us-east-2a`
removes outbound internet access for the whole dev VPC, and traffic from `2b`/`2c` pays
cross-AZ transfer. That is an acceptable trade for a non-production environment and is a
single variable flip (`single_nat_gateway = false`) if dev ever needs to match prod.

Prod runs one NAT gateway per AZ and each application subnet routes to the gateway in its
own zone, so a zone failure does not take egress with it and no normal egress crosses a
zone boundary.

## Future AWS Network Firewall integration

Nothing firewall-related is deployed yet: no firewall, no policy, no rule groups. What
exists is the structural preparation, which is the part that is expensive to retrofit:
dedicated `/28` subnets per AZ, their own route tables, and per-AZ application and public
route tables so routes can be changed one zone at a time.

The target egress path is:

```
application subnet -> same-AZ firewall endpoint -> NAT gateway -> internet gateway
```

A future `modules/security` will consume the `firewall_integration` output and make three
changes per AZ:

1. Create a firewall endpoint in `firewall_subnet_ids[az]`.
2. **Forward route** — repoint `0.0.0.0/0` in `app_route_table_ids[az]` from the NAT
   gateway to that endpoint, and add `0.0.0.0/0` in `firewall_route_table_ids[az]` to the
   NAT gateway given by `nat_gateway_az_by_app[az]`.
3. **Return route** — in `public_route_table_ids[az]`, route `app_subnet_cidrs[az]` back to
   the same firewall endpoint, so the return leg traverses the same stateful engine as the
   forward leg. Asymmetric routing breaks stateful inspection.

Once step 2 lands, the `aws_route.app_default` resource in this module is no longer the
owner of the application default route. Move that route into the security module rather
than letting the two fight over it.

**The shared dev NAT gateway needs extra care.** With one NAT gateway in `us-east-2a`
serving all three zones, return traffic arrives in a single public subnet whose route table
must send each zone's application CIDR to the *matching* zone's firewall endpoint. The
`2b` and `2c` return routes therefore point at endpoints in a different AZ than the NAT
gateway, which means the return path crosses zones and the per-AZ symmetry prod gets for
free has to be constructed by hand. The three `app_subnet_cidrs` entries are distinct
precisely so these routes can be written unambiguously. Prod has no such problem: one NAT
gateway, one public route table, and one firewall endpoint per zone.

Inbound inspection of ALB traffic is out of scope for this phase. It needs the ALB to
exist first and changes the public subnet route tables in a different way.

## Tagging

Every resource carries `Project`, `Environment`, `ManagedBy = terraform`, and
`Component = network`, plus a descriptive `Name` and a `Tier` matching its role. Each root
module adds `Application` and `CostCenter` through the `tags` variable.

## Usage

Credentials are never in the repository. The provider reads them from the environment
(profile, SSO, or instance role), and `.gitignore` excludes state files, `.terraform/`
directories, `*.tfvars`, and credential material. The `.terraform.lock.hcl` files *are*
committed, with hashes for `darwin_arm64`, `linux_amd64`, and `linux_arm64` so local and
CI runs resolve identical provider builds.

### 1. Validate without credentials or buckets

```sh
cd Terraform
terraform fmt -recursive -check

cd environments/Dev  && terraform init -backend=false && terraform validate
cd ../Prod           && terraform init -backend=false && terraform validate
```

`-backend=false` skips backend initialization, so this works before the state buckets
exist and without AWS credentials. `validate` makes no API calls.

### 2. Run the module tests (no credentials needed)

```sh
cd Terraform/modules/vpc
terraform init
terraform test
```

28 tests covering input validation, the subnet layout, routing, both NAT topologies, and
the output contract. The AWS provider is mocked, so nothing is created. See
[`modules/vpc/README.md`](modules/vpc/README.md#tests).

### 3. Create the state buckets (needs credentials)

```sh
cd Terraform/Bootstrap
terraform init
terraform apply
terraform output state_bucket_names
```

Confirm the output names match the `bucket` values in the two `backend.tf` files. If your
account ID differs from the one written there, update both files to match.

### 4. Initialize each environment against its backend

```sh
cd Terraform/environments/Dev
terraform init -reconfigure    # or: terraform init -migrate-state, if local state exists
terraform plan
```

Repeat for `Prod`. Use `-reconfigure` when switching from the `-backend=false` validation
above, and `-migrate-state` only if you have real local state to move.
