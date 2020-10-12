locals {
  gitlab_runner_ami_filter      = ["amzn2-ami-hvm-*-x86_64-ebs"]
  gitlab_runner_instance_type   = "t3.micro"
  docker_machine_ami_filter     = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  docker_machine_instance_type  = "m5a.large"
  docker_machine_version        = "0.16.2"
  docker_machine_root_size      = 16
  gitlab_runner_log_group_name  = "gitlab-runner-log-group"
  runners_docker_image          = "docker:18.03.1-ce"
  runners_ssm_token_key         = "gitlab-runner-runner-token"
  canonical_account_id          = "099720109477"
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
  count = var.enable_ssh_access ? 1 : 0

  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = var.ssh_cidr_blocks

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
  count = var.enable_ssh_access ? 1 : 0

  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = var.ssh_cidr_blocks

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

resource "aws_ssm_parameter" "runner_registration_token" {
  name  = local.runners_ssm_token_key
  type  = "SecureString"
  value = "null"

  lifecycle {
    ignore_changes = [value]  # Managed by the user-data script.
  }
}

data "template_file" "runners" {
  template = file("${path.module}/template/runner-config.tpl")

  vars = {
    aws_region                          = var.aws_region
    aws_availability_zone               = var.aws_availability_zone
    vpc_id                              = var.vpc_id
    subnet_id                           = var.subnet_id
    globals_concurrent                  = var.globals_concurrent
    runners_name                        = var.runners_name
    runners_url                         = var.runners_url
    runners_environment                 = jsonencode(var.runners_environment)
    runners_request_concurrency         = var.runners_request_concurrency
    runners_output_limit                = var.runners_output_limit
    runners_limit                       = var.runners_limit
    runners_docker_image                = local.runners_docker_image
    runners_docker_shm_size             = var.runners_docker_shm_size
    runners_docker_volumes              = jsonencode(var.runners_docker_volumes)
    runners_cache_bucket_name           = var.runners_cache_bucket_name
    runners_machine_idle_count          = var.runners_machine_idle_count
    runners_machine_idle_time           = var.runners_machine_idle_time
    runners_machine_max_builds          = var.runners_machine_max_builds
    docker_machine_iam_instance_profile = aws_iam_instance_profile.docker_machine.name
    docker_machine_instance_type        = local.docker_machine_instance_type
    docker_machine_spot_price           = var.spot_price
    docker_machine_security_group       = aws_security_group.docker_machine.name
    docker_machine_root_size            = local.docker_machine_root_size
    docker_machine_ami                  = data.aws_ami.docker-machine.id
    runners_machine_off_peak_idle_count = var.runners_machine_off_peak_idle_count
    runners_machine_off_peak_idle_time  = var.runners_machine_off_peak_idle_time
    runners_machine_off_peak_periods    = jsonencode(var.runners_machine_off_peak_periods)
    runners_machine_off_peak_timezone   = var.runners_machine_off_peak_timezone
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/template/user-data.sh.tpl")

  vars = {
    aws_region                       = var.aws_region
    docker_machine_version           = local.docker_machine_version
    gitlab_runner_description        = var.gitlab_runner_registration_config["description"]
    gitlab_runner_access_level       = var.gitlab_runner_registration_config["access_level"]
    gitlab_runner_locked_to_project  = var.gitlab_runner_registration_config["locked_to_project"]
    gitlab_runner_maximum_timeout    = var.gitlab_runner_registration_config["maximum_timeout"]
    gitlab_runner_registration_token = var.gitlab_runner_registration_config["registration_token"]
    gitlab_runner_tag_list           = var.gitlab_runner_registration_config["tag_list"]
    gitlab_runner_version            = var.gitlab_runner_version
    gitlab_runner_log_group_name     = local.gitlab_runner_log_group_name
    runners_config                   = data.template_file.runners.rendered
    runners_ssm_token_key            = local.runners_ssm_token_key
    runners_url                      = var.runners_url
  }
}

data "aws_ami" "docker-machine" {
  most_recent = "true"

  filter {
    name   = "name"
    values = local.docker_machine_ami_filter
  }

  owners = [local.canonical_account_id]
}

resource "aws_autoscaling_group" "gitlab_runner_instance" {
  name                      = "gitlab-runner-autoscaling-group"
  vpc_zone_identifier       = var.subnet_ids
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 0
  launch_configuration      = aws_launch_configuration.gitlab_runner_instance.name
}

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
    values = local.gitlab_runner_ami_filter
  }

  owners = ["amazon"]
}

resource "aws_launch_configuration" "gitlab_runner_instance" {
  security_groups      = [aws_security_group.runner.id]
  key_name             = var.key_name
  image_id             = data.aws_ami.runner.id
  user_data            = data.template_file.user_data.rendered
  instance_type        = local.gitlab_runner_instance_type
  iam_instance_profile = aws_iam_instance_profile.instance.name

  root_block_device {
    delete_on_termination = true
    volume_type           = "gp2"
    volume_size           = 8
  }

  associate_public_ip_address = var.enable_ssh_access

  lifecycle {
    create_before_destroy = true
  }
}
