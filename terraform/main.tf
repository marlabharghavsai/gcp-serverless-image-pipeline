############################################
# S3 Buckets
############################################

resource "aws_s3_bucket" "uploads" {
  bucket = "${var.app_name}-uploads-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "processed" {
  bucket = "${var.app_name}-processed-${data.aws_caller_identity.current.account_id}"
}

############################################
# Lifecycle Rule - Delete uploads after 7 days
############################################

resource "aws_s3_bucket_lifecycle_configuration" "uploads_lifecycle" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    id     = "delete-after-7-days"
    status = "Enabled"

    expiration {
      days = 7
    }
  }
}
