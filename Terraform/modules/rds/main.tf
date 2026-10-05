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

resource "random_password" "master" {
  length  = 32
  special = true

  # RDS rejects /, @, ", and space in a master password.
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "master" {
  name        = "${local.name_prefix}-booking-master"
  description = "Master password for the booking PostgreSQL writer."

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-booking-master"
  })
}

resource "aws_secretsmanager_secret_version" "master" {
  secret_id = aws_secretsmanager_secret.master.id
  secret_string = jsonencode({
    username = var.username
    password = random_password.master.result
  })
}

resource "aws_db_instance" "primary" {
  identifier = "${local.name_prefix}-booking"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.username

  # Omit manage_master_user_password. The provider rejects it alongside
  # password, including when it is false. Leaving it unset changes the
  # existing writer from RDS-managed to this password, which is what
  # PostgreSQL read replicas require.
  password = random_password.master.result

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

# The first replica is its own resource so the rest can wait for it. RDS
# rejects a second CreateDBInstanceReadReplica while the writer is busy with
# the first. us-east-2c already exists as aws_db_instance.replica.
resource "aws_db_instance" "replica_first" {
  count = length(local.replica_zones) > 0 ? 1 : 0

  identifier          = "${local.name_prefix}-booking-${substr(local.replica_zones[0], -1, 1)}"
  replicate_source_db = aws_db_instance.primary.arn
  instance_class      = var.instance_class
  availability_zone   = local.replica_zones[0]

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = false
  storage_encrypted      = true

  skip_final_snapshot = true

  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-booking-${substr(local.replica_zones[0], -1, 1)}"
    Role = "reader"
  })
}

resource "aws_db_instance" "replica" {
  for_each = toset(length(local.replica_zones) > 1 ? slice(local.replica_zones, 1, length(local.replica_zones)) : [])

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

  depends_on = [aws_db_instance.replica_first]
}
