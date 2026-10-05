locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Component   = "rds"
    },
    var.tags,
  )

  replica_availability_zones = [
    for az in var.availability_zones : az
    if az != var.primary_availability_zone
  ]
}
