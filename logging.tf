data "template_file" "instance_profile" {
  template = file("${path.module}/policies/instance-logging-policy.json")
}

resource "aws_iam_role_policy" "instance" {
  name   = "gitlab-runner-instance-role"
  role   = aws_iam_role.instance.name
  policy = data.template_file.instance_profile.rendered
}

resource "aws_cloudwatch_log_group" "environment" {
  name  = "gitlab-runner-log-group"
}
