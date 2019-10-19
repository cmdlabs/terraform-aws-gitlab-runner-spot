resource "aws_iam_instance_profile" "instance" {
  name = "gitlab-runner-instance-profile"
  role = aws_iam_role.instance.name
}

data "template_file" "instance_role_trust_policy" {
  template = file("${path.module}/policies/instance-role-trust-policy.json")
}

resource "aws_iam_role" "instance" {
  name               = "gitlab-runner-instance-role"
  assume_role_policy = data.template_file.instance_role_trust_policy.rendered
}

data "template_file" "instance_docker_machine_policy" {
  template = file(
    "${path.module}/policies/instance-docker-machine-policy.json",
  )
}

resource "aws_iam_policy" "instance_docker_machine_policy" {
  name        = "gitlab-runner-docker-machine"
  path        = "/"
  description = "Policy for docker machine."

  policy = data.template_file.instance_docker_machine_policy.rendered
}

resource "aws_iam_role_policy_attachment" "instance_docker_machine_policy" {
  role       = aws_iam_role.instance.name
  policy_arn = aws_iam_policy.instance_docker_machine_policy.arn
}

data "template_file" "instance_session_manager_policy" {
  template = file(
    "${path.module}/policies/instance-session-manager-policy.json",
  )
}

resource "aws_iam_policy" "instance_session_manager_policy" {
  name        = "gitlab-runner-session-manager"
  path        = "/"
  description = "Policy session manager."

  policy = data.template_file.instance_session_manager_policy.rendered
}

resource "aws_iam_role_policy_attachment" "instance_session_manager_policy" {
  role       = aws_iam_role.instance.name
  policy_arn = aws_iam_policy.instance_session_manager_policy.arn
}

resource "aws_iam_role_policy_attachment" "instance_session_manager_aws_managed" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "docker_machine_cache_instance" {
  role       = aws_iam_role.instance.name
  policy_arn = aws_iam_policy.docker_machine_cache.arn
}

data "template_file" "dockermachine_role_trust_policy" {
  template = file("${path.module}/policies/instance-role-trust-policy.json")
}

resource "aws_iam_role" "docker_machine" {
  name               = "gitlab-runner-docker-machine-role"
  assume_role_policy = data.template_file.dockermachine_role_trust_policy.rendered
}

resource "aws_iam_instance_profile" "docker_machine" {
  name = "gitlab-runner-docker-machine-profile"
  role = aws_iam_role.docker_machine.name
}

data "template_file" "service_linked_role" {
  template = file("${path.module}/policies/service-linked-role-create-policy.json")
}

resource "aws_iam_policy" "service_linked_role" {
  name        = "gitlab-runner-service_linked_role"
  path        = "/"
  description = "Policy for creation of service linked roles."

  policy = data.template_file.service_linked_role.rendered
}

resource "aws_iam_role_policy_attachment" "service_linked_role" {
  role       = aws_iam_role.instance.name
  policy_arn = aws_iam_policy.service_linked_role.arn
}

data "template_file" "ssm_policy" {
  template = file(
    "${path.module}/policies/instance-secure-parameter-role-policy.json",
  )
}

resource "aws_iam_policy" "ssm" {
  name        = "gitlab-runner-ssm"
  path        = "/"
  description = "Policy for runner token param access via SSM"

  policy = data.template_file.ssm_policy.rendered
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = aws_iam_policy.ssm.arn
}

data "template_file" "instance_profile" {
  template = file("${path.module}/policies/instance-logging-policy.json")
}

resource "aws_iam_role_policy" "instance" {
  name   = "gitlab-runner-instance-role"
  role   = aws_iam_role.instance.name
  policy = data.template_file.instance_profile.rendered
}

resource "aws_cloudwatch_log_group" "environment" {
  name  = local.gitlab_runner_log_group_name
}
