resource "aws_s3_bucket" "session_logs_bucket" {
  # checkov:skip=CKV_AWS_144: Cross region replication overkill
  # checkov:skip=CKV_AWS_52:
  # checkov:skip=CKV_AWS_145:v4 provider legacy
  bucket_prefix = "${var.bucket_name}-"
  force_destroy = true
  tags          = var.tags

}

resource "aws_s3_bucket_ownership_controls" "session_logs_bucket" {
  bucket = aws_s3_bucket.session_logs_bucket.bucket

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "session_logs_bucket" {
  bucket     = aws_s3_bucket.session_logs_bucket.id
  depends_on = [aws_s3_bucket_ownership_controls.session_logs_bucket]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ServerAccessLogsPolicy"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.session_logs_bucket.arn}/log/*"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:s3:::*"
          }
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_versioning" "session_logs_bucket" {
  bucket = aws_s3_bucket.session_logs_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "session_logs_bucket" {
  bucket = aws_s3_bucket.session_logs_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.ssmkey.arn
      sse_algorithm     = "aws:kms"
    }
  }
}


resource "aws_s3_bucket_lifecycle_configuration" "session_logs_bucket" {
  bucket = aws_s3_bucket.session_logs_bucket.id

  rule {
    id     = "archive_after_X_days"
    status = "Enabled"

    filter {}

    transition {
      days          = var.log_archive_days
      storage_class = "GLACIER"
    }

    expiration {
      days = var.log_expire_days
    }
  }
}


resource "aws_s3_bucket_logging" "session_logs_bucket" {
  bucket = aws_s3_bucket.session_logs_bucket.id

  target_bucket = aws_s3_bucket.session_logs_bucket.id
  target_prefix = "log/"
}


resource "aws_s3_bucket_public_access_block" "session_logs_bucket" {
  bucket                  = aws_s3_bucket.session_logs_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
