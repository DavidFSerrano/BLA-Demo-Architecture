## Prompt for creating baseline vpc infrastructure


Create the Terraform networking foundation for a two-tier application that will later use EKS and RDS. Implement only networking at this stage, in a reusable VPC module.

**Terraform structure**

Use two separate root modules under `environments/dev` and `environments/prod`. Both should call `modules/vpc`. Future EKS, RDS, and security modules will be siblings of the VPC module.

I already have a `bootstrap` folder for provisioning S3 backend buckets. Inspect the existing configuration and integrate with it. Each environment must use its own state bucket and independent state. Do not recreate existing bootstrap resources.

Use the `hashicorp/aws` provider. Declare Terraform and provider version constraints, configure the AWS provider in each root module, and commit provider dependency lock files. Keep environment-specific values in the root modules and pass them into the VPC module.

**Networking**

Use region `us-east-2` and three Availability Zones. Make the AZ selection and subnet CIDRs configurable.

Use these VPC CIDRs:
- Dev: `10.0.0.0/16`
- Prod: `10.1.0.0/16`

For each environment, create:

- One VPC with DNS support and DNS hostnames enabled.
- Twelve non-overlapping subnets across three AZs, with one subnet of each role per AZ:
  - Three public subnets for future internet-facing ALBs and current NAT gateways.
  - Three private application subnets for future EKS nodes and pods.
  - Three dedicated subnets reserved for future AWS Network Firewall endpoints.
  - Three isolated database subnets for future RDS resources.
- An explicit CIDR allocation that gives application subnets sufficient space for VPC CNI pod IPs and leaves unused VPC space for growth. Document the allocation.
- An internet gateway.
- One zonal NAT gateway with an Elastic IP in dev, shared by its application subnets; one per AZ in prod.
- Explicit route tables and associations for every subnet, with separate application, firewall, and public route tables per AZ.
- Public subnet default routes to the internet gateway.
- Application subnet default routes directly to the NAT gateway for now. In prod, use the NAT gateway in the same AZ.
- Database and reserved firewall subnet route tables without internet default routes at this stage.
- An S3 gateway endpoint associated with the application subnet route tables.
- Load-balancer discovery tags on public subnets for internet-facing load balancers and application subnets for internal load balancers. Do not apply these tags to firewall or database subnets.

**Future firewall integration**

Do not deploy AWS Network Firewall, its policies, or its rules yet.

Plan for future application internet-egress routing through:
application subnet → same-AZ firewall endpoint → NAT gateway → internet gateway.

Expose the networking identifiers needed for a future security module to create firewall endpoints and symmetric forward and return routes. Keep the VPC module independent of that future security module.

Document that the shared dev NAT gateway will require additional return-route configuration when firewall inspection is introduced. Inbound ALB traffic inspection is outside this phase.

**Outputs and documentation**

Output:
- VPC ID and CIDR.
- Subnet IDs and CIDRs grouped by role and keyed by AZ.
- Route table IDs grouped by role and keyed by AZ.
- NAT gateway IDs and their AZs.
- Internet gateway and S3 endpoint IDs.

Apply consistent project and environment tags. Document the subnet allocation, current routing, future firewall integration, and the cost and availability tradeoffs of the dev NAT configuration. Keep credentials, state files, and `.terraform` directories out of Git.

**Validation**

Run `terraform fmt` and initialize and validate each environment. If backend buckets are not available, use `terraform init -backend=false` for validation and explain how to initialize the backend after bootstrapping.

Do not apply the infrastructure.



## Prompt for unit testing and the terraform testing framework

Using the terrafrom testing framework, add tests to the vpc module

## Prompt for creating a basic CICD workflow

I have connected this repo with aws via oidc, the role arn github actions must use for terraform apply is arn:aws:iam::637423617446:role/github-actions-terraform-deploy

Create a gh actions pipeline where:

PRs trigger terraform init -> terraform fmt -> terraform validate -> terraform test -> terraform plan and terraform apply to the dev backend. for the dev backend, terraform apply is a manual hold 

merge to main triggers terraform apply to the prod backend


## Prompt for creating the EKS module.

Create the eks module now, use the second smallest ec2 instance that eks allows, the worker nodes should be deployed in 3 private subnets across the 3 AZs, install the vpc CNI , EBS CSI , use managed node groups , add EKS pod identify so pods can use IAM roles, as an eks addon, coredns and kube-proxy, all eks worker nodes should share the same security group