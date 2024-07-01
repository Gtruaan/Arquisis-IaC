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

resource "aws_instance" "e3-iac-ec2" {
  ami           = "ami-0b8b44ec9a8f90422"  # ec2 arquisis
  instance_type = "t2.micro"
  key_name               = "base-key"
  vpc_security_group_ids = [aws_security_group.e3-iac-sg.id]

  user_data = "${file("./scripts/configure-ec2.sh")}"
  tags = {
    Name = "e3-iac-ec2"
  }
}

resource "aws_eip" "e3-iac-eip" {
  instance = aws_instance.e3-iac-ec2.id
}

resource "aws_security_group" "e3-iac-sg" {
  name        = "e3-iac-sg"
  description = "Security group for SSH access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

output "elastic_ip" {
  value = aws_eip.e3-iac-eip.public_ip
}

resource "aws_s3_bucket" "e3-iac-s3-receipts" {
  bucket = "e3-iac-s3-receipts"

  tags = {
    Stage = "prod"
  }
}

resource "aws_s3_bucket_public_access_block" "public_bucket_public_access_block" {
  bucket = aws_s3_bucket.e3-iac-s3-receipts.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_bucket_policy" {
  bucket = aws_s3_bucket.e3-iac-s3-receipts.id

  policy = jsonencode({
    "Version": "2008-10-17",
    "Statement": [
        {
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                aws_s3_bucket.e3-iac-s3-receipts.arn,
                "${aws_s3_bucket.e3-iac-s3-receipts.arn}/*",
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        }
    ]
  })
}

resource "aws_api_gateway_rest_api" "e3-iac-api" {
  name        = "e3-iac-api"
  description = "API para e3-iac-ec2"
}

output "ssh_command" {
  value = "ssh -i ${aws_instance.e3-iac-ec2.key_name}.pem ubuntu@${aws_eip.e3-iac-eip.public_ip}"
}

output "api_url" {
  value = aws_api_gateway_rest_api.e3-iac-api.id
}

output "s3_bucket" {
  value = aws_s3_bucket.e3-iac-s3-receipts.bucket
}
