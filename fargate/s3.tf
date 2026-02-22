##############################################
# S3 Buckets
##############################################

# ── Video Clips Bucket ───────────────────────

resource "aws_s3_bucket" "clips" {
  bucket = "${var.project_name}-clips-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${var.project_name}-clips" }
}

resource "aws_s3_bucket_versioning" "clips" {
  bucket = aws_s3_bucket.clips.id
  versioning_configuration { status = "Disabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "clips" {
  bucket = aws_s3_bucket.clips.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "clips" {
  bucket = aws_s3_bucket.clips.id

  rule {
    id     = "expire-old-clips"
    status = "Enabled"

    filter {}

    # 90일 후 IA로 이동, 365일 후 삭제
    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
    expiration {
      days = 365
    }
  }
}

resource "aws_s3_bucket_public_access_block" "clips" {
  bucket                  = aws_s3_bucket.clips.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── Frontend Static Bucket ───────────────────

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${var.project_name}-frontend" }
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront OAC가 접근할 수 있도록 버킷 정책 설정
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCloudFrontOAC"
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action   = "s3:GetObject"
      Resource = "${aws_s3_bucket.frontend.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
        }
      }
    }]
  })
}
