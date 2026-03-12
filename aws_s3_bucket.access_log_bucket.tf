resource "aws_s3_bucket" "access_log_bucket" {
  # checkov:skip=CKV_AWS_144: Cross region replication is overkill
  # checkov:skip=CKV_AWS_18:
  # checkov:skip=CKV_AWS_52:
  # checkov:skip=CKV_AWS_145:v4 provider legacy
  bucket_prefix = "${var.access_log_bucket_name}-"
  force_destroy = true

  tags = var.tags


}

# Clear any existing ACL grants before switching to BucketOwnerEnforced.
# AWS blocks the ownership change if non-default ACL grants are present.
# The || true ensures this is a no-op if the bucket already has BucketOwnerEnforced.
resource "null_resource" "clear_access_log_bucket_acl" {
  triggers = {
    bucket = aws_s3_bucket.access_log_bucket.bucket
  }

  provisioner "local-exec" {
    command = "aws s3api put-bucket-acl --bucket ${aws_s3_bucket.access_log_bucket.bucket} --acl private || true"
  }
}

resource "aws_s3_bucket_ownership_controls" "access_log_bucket" {
  bucket     = aws_s3_bucket.access_log_bucket.bucket
  depends_on = [null_resource.clear_access_log_bucket_acl]

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "access_log_bucket" {
  bucket     = aws_s3_bucket.access_log_bucket.id
  depends_on = [aws_s3_bucket_ownership_controls.access_log_bucket]

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
        Resource = "${aws_s3_bucket.access_log_bucket.arn}/*"
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


resource "aws_s3_bucket_versioning" "access_log_bucket" {
  bucket = aws_s3_bucket.access_log_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "access_log_bucket" {
  bucket = aws_s3_bucket.access_log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.ssmkey.arn
      sse_algorithm     = "aws:kms"
    }
  }
}


resource "aws_s3_bucket_lifecycle_configuration" "access_log_bucket" {
  bucket = aws_s3_bucket.access_log_bucket.id

  rule {
    id     = "delete_after_X_days"
    status = "Enabled"

    filter {}

    expiration {
      days = var.access_log_expire_days
    }
  }
}


resource "aws_s3_bucket_public_access_block" "access_log_bucket" {
  bucket                  = aws_s3_bucket.access_log_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
