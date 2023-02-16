module "label_log_bucket" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  attributes = ["loadbalancer", "logs"]
  context    = module.this.context
}

data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket_policy" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id
  policy = data.aws_iam_policy_document.ipfs_cluster_alb.json
}

resource "aws_s3_bucket_versioning" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id     = "${module.label_log_bucket.id}-expiration"
    status = "Enabled"

    expiration {
      days = var.alb_logs_expiration_days
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket" {
  # https://docs.aws.amazon.com/AmazonS3/latest/dev/bucket-encryption.html
  # https://www.terraform.io/docs/providers/aws/r/s3_bucket.html#enable-default-server-side-encryption
  # ALB cannot write logs into the bucket if we use our own KMS key, so we must use the AES256 amazon managed key

  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_acl" "log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket" "log_bucket" {
  bucket        = module.label_log_bucket.id
  force_destroy = !(module.this.stage == "prod")

  tags = module.label_log_bucket.tags
}

data "aws_iam_policy_document" "ipfs_cluster_alb" {
  statement {
    sid       = "AllowIPFSClusterALBToPutLoadBalancerLogsToS3Bucket"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.log_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_elb_service_account.main.id}:root"]
    }
  }
}

resource "aws_s3_bucket_policy" "alb_log_bucket" {
  bucket = aws_s3_bucket.log_bucket.id
  policy = data.aws_iam_policy_document.ipfs_cluster_alb.json
}

resource "aws_s3_bucket_public_access_block" "default" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
