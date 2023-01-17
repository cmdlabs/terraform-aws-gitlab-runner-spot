data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "build_cache" {
  bucket = var.runners_cache_bucket_name

  acl = "private"

  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "build_cache" {
  bucket = aws_s3_bucket.build_cache.id

  rule {
    id     = "clear"
    status = "Enabled"

    filter {
      prefix = "runner/"
    }

    expiration {
      days = var.runners_cache_expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.runners_cache_expiration_days
    }
  }
}

data "template_file" "docker_machine_cache_policy" {
  template = file("${path.module}/policies/cache.json")

  vars = {
    s3_cache_arn = aws_s3_bucket.build_cache.arn
  }
}

resource "aws_iam_policy" "docker_machine_cache" {
  name_prefix = "gitlab-runner-docker-machine-cache"
  path        = "/"
  description = "Policy for docker machine instance to access cache"

  policy = data.template_file.docker_machine_cache_policy.rendered
}
