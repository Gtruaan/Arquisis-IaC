terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-2"
}

resource "aws_s3_bucket" "e3-iac-s3-front" {
  bucket = "e3-iac-s3-front"

  tags = {
    Stage = "prod"
  }
}

resource "aws_s3_bucket_public_access_block" "public_bucket_public_access_block" {
  bucket = aws_s3_bucket.e3-iac-s3-front.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_bucket_policy" {
  bucket = aws_s3_bucket.e3-iac-s3-front.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowPublicAccessToFiles",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "${aws_s3_bucket.e3-iac-s3-front.arn}/*",
        }
    ]
  })
}

resource "aws_cloudfront_distribution" "e3-iac-cloudfront" {
  origin {
    domain_name = aws_s3_bucket.e3-iac-s3-front.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.e3-iac-s3-front.bucket_regional_domain_name
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "e3-iac-cloudfront"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD" ]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.e3-iac-s3-front.bucket_regional_domain_name

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
  }

  # Aca van las edge locations
  price_class = "PriceClass_All"
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "s3_bucket" {
  value = aws_s3_bucket.e3-iac-s3-front.bucket
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.e3-iac-cloudfront.domain_name
}

