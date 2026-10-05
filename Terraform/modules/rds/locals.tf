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

  # Stable order. Each replica after the first references the previous one so
  # RDS is not asked to create two replicas while the writer is busy.
  replica_zones = slice(
    local.replica_availability_zones,
    0,
    min(var.read_replica_count, length(local.replica_availability_zones)),
  )
}
