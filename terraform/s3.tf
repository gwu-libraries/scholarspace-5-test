resource "aws_s3_bucket" "app_bucket" {
  bucket = var.s3_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "${var.site_prefix}_prod_app_bucket"
  }
}

resource "aws_s3_bucket_versioning" "app_bucket_versioning" {
  bucket = aws_s3_bucket.app_bucket.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_bucket_encryption" {
  bucket = aws_s3_bucket.app_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app_bucket_public_access" {
  bucket = aws_s3_bucket.app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "derivative_cache_bucket_lifecycle" {
  bucket = aws_s3_bucket.derivative_cache_bucket.id

  rule {
    id     = "expire-derivative-cache"
    status = "Enabled"

    filter {}

    expiration {
      # any files that have been hanging out in this derivative cache for more than a week
      # are assumed to have been persisted in Fedora and get deleted. 
      days = 7
    }
  }
}

# Kept separate from the OCFL bucket so an expiry rule can never reach
# preservation storage.
resource "aws_s3_bucket" "derivative_cache_bucket" {
  bucket = var.s3_derivative_cache_bucket_name

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "${var.site_prefix}_derivative_cache"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "derivative_cache_bucket_encryption" {
  bucket = aws_s3_bucket.derivative_cache_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "derivative_cache_bucket_public_access" {
  bucket = aws_s3_bucket.derivative_cache_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
