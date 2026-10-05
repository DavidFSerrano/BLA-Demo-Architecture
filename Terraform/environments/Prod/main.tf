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

  # One NAT gateway per AZ: each application subnet egresses through the NAT
  # gateway in its own zone, so a zone failure is contained to that zone.
  single_nat_gateway = false

  enable_s3_gateway_endpoint = true
  eks_cluster_name           = local.cluster_name
}

module "network_firewall" {
  source = "../../modules/network-firewall"

  project     = var.project
  environment = var.environment
  tags        = var.tags
  network     = module.vpc.firewall_integration
}

moved {
  from = module.vpc.aws_route.app_default
  to   = module.network_firewall.aws_route.app_default
}

module "eks" {
  source = "../../modules/eks"

  # Endpoints are part of the VPC module and are not referenced below, so this
  # waits for the whole VPC, including those endpoints, before the cluster starts.
  depends_on = [module.vpc]

  project      = var.project
  environment  = var.environment
  tags         = var.tags
  cluster_name = local.cluster_name

  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr_block
  private_subnet_ids = module.vpc.subnet_id_lists_by_role.app

  node_instance_type = "t3.medium"
  node_desired_size  = 3
  node_min_size      = 3
  node_max_size      = 6

  cluster_admin_principal_arns = [
    "arn:aws:iam::637423617446:user/David_Serrano",
    "arn:aws:iam::637423617446:role/github-actions-terraform-deploy",
  ]
}

module "rds" {
  source = "../../modules/rds"

  project     = var.project
  environment = var.environment
  tags        = var.tags

  vpc_id              = module.vpc.vpc_id
  database_subnet_ids = module.vpc.subnet_id_lists_by_role.database
  availability_zones  = var.availability_zones

  # The architecture diagram puts the writer in the middle zone and a read
  # replica in each of the other two database subnets. db.t3.micro is the
  # common x86 class; db.t4g.micro had no capacity in us-east-2b.
  primary_availability_zone  = "us-east-2b"
  read_replica_count         = 2
  instance_class             = "db.t3.micro"
  deletion_protection        = false
  skip_final_snapshot        = true
  allowed_security_group_ids = [module.eks.node_security_group_id]
}
