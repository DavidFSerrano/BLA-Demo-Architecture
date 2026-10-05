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
}
