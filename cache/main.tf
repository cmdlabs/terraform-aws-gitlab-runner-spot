data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "build_cache" {
  bucket = var.cache_bucket_name

  acl    = "private"

  force_destroy = true

  lifecycle_rule {
    id      = "clear"
    enabled = true

    prefix = "runner/"

    expiration {
      days = var.cache_expiration_days
    }

    noncurrent_version_expiration {
      days = var.cache_expiration_days
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
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
  name        = "gitlab-runner-docker-machine-cache"
  path        = "/"
  description = "Policy for docker machine instance to access cache"

  policy = data.template_file.docker_machine_cache_policy.rendered
}
