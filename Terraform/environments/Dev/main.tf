locals {
  cluster_name = "${var.project}-${var.environment}"
}

module "vpc" {
  count  = var.enabled ? 1 : 0
  source = "../../modules/vpc"

  project     = var.project
  environment = var.environment
  tags        = var.tags

  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  subnet_cidrs       = var.subnet_cidrs

  # Dev trades availability for cost: one NAT gateway in us-east-2a serves the
  # application subnets in all three AZs. See Terraform/README.md.
  single_nat_gateway = true
  nat_gateway_az     = "us-east-2a"

  enable_s3_gateway_endpoint = true
  eks_cluster_name           = local.cluster_name
}

module "eks" {
  count  = var.enabled ? 1 : 0
  source = "../../modules/eks"

  # Endpoints are part of the VPC module and are not referenced below, so this
  # waits for the whole VPC, including those endpoints, before the cluster starts.
  depends_on = [module.vpc]

  project      = var.project
  environment  = var.environment
  tags         = var.tags
  cluster_name = local.cluster_name

  vpc_id             = module.vpc[0].vpc_id
  vpc_cidr           = module.vpc[0].vpc_cidr_block
  private_subnet_ids = module.vpc[0].subnet_id_lists_by_role.app

  node_instance_type = "t3.medium"
  node_desired_size  = 3
  node_min_size      = 1
  node_max_size      = 3

  cluster_admin_principal_arns = [
    "arn:aws:iam::637423617446:user/David_Serrano",
    "arn:aws:iam::637423617446:role/github-actions-terraform-deploy",
  ]
}

module "rds" {
  count  = var.enabled ? 1 : 0
  source = "../../modules/rds"

  project     = var.project
  environment = var.environment
  tags        = var.tags

  vpc_id              = module.vpc[0].vpc_id
  database_subnet_ids = module.vpc[0].subnet_id_lists_by_role.database
  availability_zones  = var.availability_zones

  # Dev keeps a single writer. Prod is the layout in the architecture diagram.
  primary_availability_zone  = "us-east-2a"
  read_replica_count         = 0
  backup_retention_period    = 1
  deletion_protection        = false
  skip_final_snapshot        = true
  allowed_security_group_ids = [module.eks[0].node_security_group_id]
}
