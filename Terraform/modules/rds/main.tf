resource "terraform_data" "replica_layout" {
  lifecycle {
    precondition {
      condition     = contains(var.availability_zones, var.primary_availability_zone)
      error_message = "primary_availability_zone must be one of availability_zones."
    }

    precondition {
      condition     = var.read_replica_count <= length(local.replica_availability_zones)
      error_message = "read_replica_count cannot exceed the number of zones other than the writer zone."
    }

    precondition {
      condition     = var.read_replica_count == 0 || var.backup_retention_period >= 1
      error_message = "Read replicas require backup_retention_period of at least 1."
    }
  }
}

resource "aws_db_subnet_group" "this" {
  name        = "${local.name_prefix}-db"
  description = "Isolated database subnets for ${local.name_prefix}"
  subnet_ids  = var.database_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db"
  })
}

resource "aws_security_group" "this" {
  name        = "${local.name_prefix}-rds"
  description = "PostgreSQL for the booking API. No internet path."
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds"
  })
}

resource "aws_vpc_security_group_ingress_rule" "postgres" {
  for_each = toset(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from the EKS nodes"

  tags = local.common_tags
}

resource "aws_db_instance" "primary" {
  identifier = "${local.name_prefix}-booking"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.username

  # RDS generates the master password and stores it in Secrets Manager.
  manage_master_user_password = true

  availability_zone      = var.primary_availability_zone
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = false
  multi_az               = false

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  backup_retention_period = var.backup_retention_period
  copy_tags_to_snapshot   = true

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.name_prefix}-booking-final"

  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-booking"
    Role = "writer"
  })

  depends_on = [terraform_data.replica_layout]
}

resource "aws_db_instance" "replica" {
  for_each = toset(slice(local.replica_availability_zones, 0, var.read_replica_count))

  identifier          = "${local.name_prefix}-booking-${substr(each.key, -1, 1)}"
  replicate_source_db = aws_db_instance.primary.arn
  instance_class      = var.instance_class
  availability_zone   = each.key

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = false
  storage_encrypted      = true

  skip_final_snapshot = true

  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-booking-${substr(each.key, -1, 1)}"
    Role = "reader"
  })
}
