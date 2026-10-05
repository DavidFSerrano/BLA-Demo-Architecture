data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # One bucket per environment keeps a hard boundary between dev and prod state:
  # access can be granted per bucket and a mistake in one cannot touch the other.
  state_buckets = {
    for env in var.environments :
    env => "${var.state_bucket_prefix}-${env}-${local.account_id}"
  }

  common_tags = {
    Project   = var.project
    ManagedBy = "terraform"
    Component = "tf-backend"
  }
}

resource "aws_s3_bucket" "state" {
  for_each = local.state_buckets

  bucket = each.value

  tags = merge(local.common_tags, {
    Name        = each.value
    Environment = each.key
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  for_each = aws_s3_bucket.state

  bucket = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  for_each = aws_s3_bucket.state

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  for_each = aws_s3_bucket.state

  bucket = each.value.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state" {
  for_each = aws_s3_bucket.state

  bucket = each.value.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  for_each = aws_s3_bucket.state

  bucket = each.value.id

  rule {
    id     = "expire-noncurrent-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

data "aws_iam_policy_document" "state" {
  for_each = aws_s3_bucket.state

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      each.value.arn,
      "${each.value.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  for_each = aws_s3_bucket.state

  bucket = each.value.id
  policy = data.aws_iam_policy_document.state[each.key].json

  depends_on = [aws_s3_bucket_public_access_block.state]
}
