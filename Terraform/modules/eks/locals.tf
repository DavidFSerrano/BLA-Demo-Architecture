data "aws_partition" "current" {}

locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Component   = "eks"
    },
    var.tags,
  )

  cluster_admin_arns = toset(var.cluster_admin_principal_arns)
}
