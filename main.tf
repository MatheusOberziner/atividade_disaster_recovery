provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "primary_bucket" {
  bucket = "matheus-bucket-primary"

  versioning {
    enabled = true
  }
}

# Recurso separado para a configuração de replicação
resource "aws_s3_bucket_replication_configuration" "primary_bucket_replication" {
  bucket = aws_s3_bucket.primary_bucket.id
  role   = aws_iam_role.replication_role.arn

  rule {
    id     = "replication-rule"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.replica_bucket.arn
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "primary_bucket_lifecycle" {
  bucket = aws_s3_bucket.primary_bucket.id

  rule {
    id     = "expire_old_versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

provider "aws" {
  alias  = "replica"
  region = "us-west-2"
}

resource "aws_s3_bucket" "replica_bucket" {
  provider = aws.replica
  bucket   = "matheus-bucket-replica"

  versioning {
    enabled = true
  }
}

resource "aws_iam_role" "replication_role" {
  name = "s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "replication_policy" {
  role = aws_iam_role.replication_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging",
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.primary_bucket.arn,
          "${aws_s3_bucket.primary_bucket.arn}/*"
        ]
      },
      {
        Action = "s3:ListBucket"
        Effect = "Allow"
        Resource = aws_s3_bucket.primary_bucket.arn
      }
    ]
  })
}
