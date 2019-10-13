locals {
  instance_type                 = "t3.micro"

  docker_machine_instance_type  = "m5a.large"
  docker_machine_spot_price_bid = "0.06"
  docker_machine_version        = "0.16.2"

  gitlab_runner_version         = "12.3.0"

  runners_image                 = "docker:18.03.1-ce"
  runners_pull_policy           = "always"
  runners_privileged            = true

  // Define key for runner token for SSM
  secure_parameter_store_runner_token_key = "gitlab-runner-runner-token"
}

resource "aws_security_group" "runner" {
  name_prefix = "gitlab-runner-security-group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "runner_ssh" {
  count = var.enable_gitlab_runner_ssh_access ? 1 : 0

  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = var.gitlab_runner_ssh_cidr_blocks

  security_group_id = aws_security_group.runner.id
}

resource "aws_security_group" "docker_machine" {
  name_prefix = "gitlab-runner-docker-machine"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "docker_machine_docker_runner" {
  type                     = "ingress"
  from_port                = 2376
  to_port                  = 2376
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.runner.id

  security_group_id = aws_security_group.docker_machine.id
}

resource "aws_security_group_rule" "docker_machine_docker_self" {
  type      = "ingress"
  from_port = 2376
  to_port   = 2376
  protocol  = "tcp"
  self      = true

  security_group_id = aws_security_group.docker_machine.id
}

resource "aws_security_group_rule" "docker_machine_ssh" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = var.docker_machine_ssh_cidr_blocks

  security_group_id = aws_security_group.docker_machine.id
}

resource "aws_security_group_rule" "out_all" {
  type        = "egress"
  from_port   = 0
  to_port     = 65535
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.docker_machine.id
}

# Parameter value is managed by the user-data script of the gitlab runner instance
resource "aws_ssm_parameter" "runner_registration_token" {
  name  = local.secure_parameter_store_runner_token_key
  type  = "SecureString"
  value = "null"

  lifecycle {
    ignore_changes = [value]
  }
}

data "template_file" "services_volumes_tmpfs" {
  template = file("${path.module}/template/volumes.tpl")
  count    = length(var.runners_services_volumes_tmpfs)
  vars = {
    volume  = element(keys(var.runners_services_volumes_tmpfs[count.index]), 0)
    options = element(values(var.runners_services_volumes_tmpfs[count.index]), 0)
  }
}

data "template_file" "volumes_tmpfs" {
  template = file("${path.module}/template/volumes.tpl")
  count    = length(var.runners_volumes_tmpfs)
  vars = {
    volume  = element(keys(var.runners_volumes_tmpfs[count.index]), 0)
    options = element(values(var.runners_volumes_tmpfs[count.index]), 0)
  }
}

data "template_file" "runners" {
  template = file("${path.module}/template/runner-config.tpl")

  vars = {
    runners_instance_profile       = aws_iam_instance_profile.docker_machine.name
    runners_security_group_name    = aws_security_group.docker_machine.name
    runners_services_volumes_tmpfs = chomp(join("", data.template_file.services_volumes_tmpfs.*.rendered))
    runners_volumes_tmpfs          = chomp(join("", data.template_file.volumes_tmpfs.*.rendered))
    runners_ami                    = data.aws_ami.docker-machine.id
    runners_environment_vars       = jsonencode(var.runners_environment_vars)
    bucket_name                    = local.bucket_name
    runners_instance_type          = local.docker_machine_instance_type
    runners_spot_price_bid         = local.docker_machine_spot_price_bid
    runners_image                  = local.runners_image
    runners_max_builds             = var.runners_max_builds
    runners_privileged             = local.runners_privileged
    runners_pull_policy            = local.runners_pull_policy
    aws_region                     = var.aws_region
    runners_aws_zone               = var.aws_zone
    runners_concurrent             = var.runners_concurrent
    gitlab_url                     = var.runners_gitlab_url
    runners_idle_count             = var.runners_idle_count
    runners_idle_time              = var.runners_idle_time
    runners_limit                  = var.runners_limit
    runners_monitoring             = var.runners_monitoring
    runners_name                   = var.runners_name
    runners_off_peak_idle_count    = var.runners_off_peak_idle_count
    runners_off_peak_idle_time     = var.runners_off_peak_idle_time
    runners_off_peak_periods       = var.runners_off_peak_periods
    runners_off_peak_timezone      = var.runners_off_peak_timezone
    runners_output_limit           = var.runners_output_limit
    runners_request_concurrency    = var.runners_request_concurrency
    runners_root_size              = var.runners_root_size
    runners_shm_size               = var.runners_shm_size
    runners_token                  = var.runners_token
    runners_subnet_id              = var.subnet_id_runners
    runners_vpc_id                 = var.vpc_id
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/template/user-data.sh.tpl")

  vars = {
    runners_config                          = data.template_file.runners.rendered
    docker_machine_version                  = local.docker_machine_version
    gitlab_runner_version                   = local.gitlab_runner_version
    secure_parameter_store_runner_token_key = local.secure_parameter_store_runner_token_key
    secure_parameter_store_region           = var.aws_region
    user_data_trace_log                     = var.enable_runner_user_data_trace_log
    gitlab_runner_access_level              = var.gitlab_runner_registration_config["access_level"]
    giltab_runner_description               = var.gitlab_runner_registration_config["description"]
    gitlab_runner_locked_to_project         = var.gitlab_runner_registration_config["locked_to_project"]
    gitlab_runner_maximum_timeout           = var.gitlab_runner_registration_config["maximum_timeout"]
    gitlab_runner_registration_token        = var.gitlab_runner_registration_config["registration_token"]
    gitlab_runner_run_untagged              = var.gitlab_runner_registration_config["run_untagged"]
    runners_gitlab_url                      = var.runners_gitlab_url
    runners_token                           = var.runners_token
  }
}

data "aws_ami" "docker-machine" {
  most_recent = "true"

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical.
}

resource "aws_autoscaling_group" "gitlab_runner_instance" {
  name                = "gitlab-runner-as-group"
  vpc_zone_identifier = var.subnet_ids_gitlab_runner

  min_size                  = "1"
  max_size                  = "1"
  desired_capacity          = "1"
  health_check_grace_period = 0
  launch_configuration      = aws_launch_configuration.gitlab_runner_instance.name
}

# TODO. This was originally disasbled by default and I have enabled it. May need to
# revisit.

resource "aws_autoscaling_schedule" "scale_in" {
  autoscaling_group_name = aws_autoscaling_group.gitlab_runner_instance.name
  scheduled_action_name  = "scale_in-${aws_autoscaling_group.gitlab_runner_instance.name}"
  recurrence             = var.schedule_config["scale_in_recurrence"]
  min_size               = var.schedule_config["scale_in_count"]
  desired_capacity       = var.schedule_config["scale_in_count"]
  max_size               = var.schedule_config["scale_in_count"]
}

resource "aws_autoscaling_schedule" "scale_out" {
  autoscaling_group_name = aws_autoscaling_group.gitlab_runner_instance.name
  scheduled_action_name  = "scale_out-${aws_autoscaling_group.gitlab_runner_instance.name}"
  recurrence             = var.schedule_config["scale_out_recurrence"]
  min_size               = var.schedule_config["scale_out_count"]
  desired_capacity       = var.schedule_config["scale_out_count"]
  max_size               = var.schedule_config["scale_out_count"]
}

data "aws_ami" "runner" {
  most_recent = "true"

  filter {
    name   = "name"
    values = ["amzn-ami-hvm-2018.03*-x86_64-ebs"]
  }

  owners = ["amazon"]
}

resource "aws_launch_configuration" "gitlab_runner_instance" {
  security_groups      = [aws_security_group.runner.id]
  key_name             = var.key_name
  image_id             = data.aws_ami.runner.id
  user_data            = data.template_file.user_data.rendered
  instance_type        = local.instance_type
  iam_instance_profile = aws_iam_instance_profile.instance.name

  root_block_device {
    delete_on_termination = true
    volume_type           = "gp2"
    volume_size           = 8
  }

  associate_public_ip_address = false

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
### Create cache bucket
################################################################################
locals {
  bucket_name   = var.cache_bucket["create"] ? module.cache.bucket : var.cache_bucket["bucket"]
  bucket_policy = var.cache_bucket["create"] ? module.cache.policy_arn : var.cache_bucket["policy"]
}

module "cache" {
  source = "./cache"

  create_cache_bucket     = var.cache_bucket["create"]
  cache_bucket_name       = var.cache_bucket_name
  cache_expiration_days   = var.cache_expiration_days
}

################################################################################
### Trust policy
################################################################################
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

################################################################################
### Policies for runner agent instance to create docker machines via spot req.
################################################################################
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

################################################################################
### Policies for runner agent instance to allow connection via Session Manager
################################################################################

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

################################################################################
### Policy for the docker machine instance to access cache
################################################################################

resource "aws_iam_role_policy_attachment" "docker_machine_cache_instance" {
  role       = aws_iam_role.instance.name
  policy_arn = local.bucket_policy
}

################################################################################
### docker machine instance policy
################################################################################
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

################################################################################
### Service linked policy
################################################################################
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

################################################################################
### AWS Systems Manager access to store runner token once registered
################################################################################
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

################################################################################
### CloudWatch logging
################################################################################
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
