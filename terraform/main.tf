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

############################################
# SQS Queues
############################################

resource "aws_sqs_queue" "image_processing_requests" {
  name                       = "${var.app_name}-image-processing-requests"
  visibility_timeout_seconds = 300
}

resource "aws_sqs_queue" "image_processing_results" {
  name                       = "${var.app_name}-image-processing-results"
  visibility_timeout_seconds = 300
}

############################################
# IAM Role for Lambda Functions
############################################

resource "aws_iam_role" "lambda_role" {
  name = "${var.app_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

############################################
# IAM Policy (Least Privilege)
############################################

resource "aws_iam_policy" "lambda_policy" {
  name = "${var.app_name}-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # CloudWatch Logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },

      # S3 Access
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.uploads.arn}/*",
          "${aws_s3_bucket.processed.arn}/*"
        ]
      },

      # SQS Access
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.image_processing_requests.arn,
          aws_sqs_queue.image_processing_results.arn
        ]
      }
    ]
  })
}

############################################
# Attach Policy to Role
############################################

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}
