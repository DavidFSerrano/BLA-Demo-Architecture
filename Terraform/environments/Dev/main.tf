locals {
  cluster_name = "${var.project}-${var.environment}"
}

module "vpc" {
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
  source = "../../modules/eks"

  project      = var.project
  environment  = var.environment
  tags         = var.tags
  cluster_name = local.cluster_name

  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr_block
  private_subnet_ids = module.vpc.subnet_id_lists_by_role.app

  node_instance_type = "t3.medium"
  node_desired_size  = 3
  node_min_size      = 1
  node_max_size      = 3

  cluster_admin_principal_arns = [
    "arn:aws:iam::637423617446:role/github-actions-terraform-deploy",
  ]
}
