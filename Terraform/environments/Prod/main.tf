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
}
