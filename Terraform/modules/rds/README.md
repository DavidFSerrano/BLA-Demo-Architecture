# modules/rds

PostgreSQL for the booking API, placed in the isolated database subnets from the
production architecture diagram. One read/write instance sits in the middle
Availability Zone. One read replica sits in each of the other two zones. Nothing
here has a public address or an internet route.

The module generates the master password and stores it in Secrets Manager. RDS
cannot manage that password itself, because PostgreSQL read replicas are rejected
while it does. This module does not install the API or create a Kubernetes secret.

## What it creates

- A DB subnet group over the isolated database subnets.
- One security group. PostgreSQL is allowed only from the security groups passed
  in, which should be the shared EKS node security group. t3.medium does not
  support a separate security group on the pods.
- One PostgreSQL writer, `db.t4g.micro` by default, gp3, encrypted, single-AZ.
- Read replicas, one per remaining Availability Zone when `read_replica_count` is 2.

## Usage

```hcl
module "rds" {
  source = "../../modules/rds"

  project     = "bla-demo"
  environment = "prod"
  tags        = { Application = "appointment-booking" }

  vpc_id              = module.vpc.vpc_id
  database_subnet_ids = module.vpc.subnet_id_lists_by_role.database
  availability_zones  = ["us-east-2a", "us-east-2b", "us-east-2c"]

  primary_availability_zone  = "us-east-2b"
  read_replica_count         = 2
  allowed_security_group_ids = [module.eks.node_security_group_id]
}
```

Dev passes `read_replica_count = 0`. That environment already trades a replica
in every zone for a single NAT gateway, and the dev root is gated by `enabled`.

## Tests

```sh
cd Terraform/modules/rds
terraform init
terraform test
```

The AWS provider is mocked. `tests/layout.tftest.hcl` checks the writer zone,
the two reader zones, and that none of the instances are public.
