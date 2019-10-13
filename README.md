<!-- vim: set ft=markdown: -->
![CMD Solutions|medium](https://s3-ap-southeast-2.amazonaws.com/cmd-website-images/CMDlogo.jpg)

# terraform-aws-gitlab-runner

#### Table of contents

1. [Overview](#overview)
2. [AWS Gitlab Runner - Overview Diagram](#aws-gitlab-runner---overview-diagram)
3. [Prerequisites](#prerequisites)
    * [AWS](#aws)
    * [Service linked roles](#service-linked-roles)
    * [GitLab runner token configuration](#gitlab-runner-token-configuration)
    * [GitLab runner cache](#gitlab-runner-cache)
    * [Inputs](#inputs)
    * [Outputs](#outputs)
    * [Examples](#examples)
4. [License](#license)

## Overview

This module creates an auto-scaling [GitLab CI runner](https://docs.gitlab.com/runner/) on AWS spot instances. The original setup of the module is based on the blog post: [Auto scale GitLab CI runners and save 90% on EC2 costs](https://about.gitlab.com/2017/11/23/autoscale-ci-runners/).

The runners created by the module using spot instances for running the builds using the `docker+machine` executor.

- Shared cache in S3 with life cycle management to clear objects after x days.
- Logs streamed to CloudWatch.
- Runner agents registered automatically.

The runner agent is running on a single EC2 node and runners are created by [docker machine](https://docs.gitlab.com/runner/configuration/autoscale.html) using spot instances. Runners will scale automatically based on configuration. The module creates by default a S3 cache that is shared cross runners (spot instances).

## AWS Gitlab Runner - Overview Diagram

![runners-default](https://github.com/npalm/assets/raw/master/images/terraform-aws-gitlab-runner/runner-default.png)

## Prerequisites

### AWS

Ensure you have setup you AWS credentials. The module requires access to IAM, EC2, CloudWatch, S3 and SSM.

### Service linked roles

The GitLab runner EC2 instance requires the following service linked roles:

  - AWSServiceRoleForAutoScaling
  - AWSServiceRoleForEC2Spot

### GitLab runner token configuration

The runner is registered on initial deployment.

To register the runner automatically set the variable `gitlab_runner_registration_config["token"]`. This token value can be found in your GitLab project, group, or global settings. For a generic runner you can find the token in the admin section. Here is an example:

``` hcl
gitlab_runner_registration_config = {
  registration_token = "<registration token>"
  description        = "<some description>"
  locked_to_project  = "true"
  run_untagged       = "false"
  maximum_timeout    = "3600"
  access_level       = "<not_protected OR ref_protected, ref_protected runner will only run on pipelines triggered on protected branches>"
}
```

### GitLab runner cache

The module creates a cache for the runner in S3. Old objects are automatically remove via a configurable life cycle policy on the bucket.

### Inputs

The below outlines the current parameters and defaults.

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-------:|:--------:|
|aws_region|AWS region|string|""|Yes|
|vpc_id|The target VPC for the docker-machine and runner instances|string|""|Yes|
|subnet_id_runners|Subnet used for hosting the GitLab runner|string|""|Yes|
|subnet_ids_gitlab_runner|List of subnets used for hosting the GitLab runners|list(string)|""|Yes|
|runners_gitlab_url|URL of the GitLab instance to connect to|string|""|Yes|
|aws_zone|AWS availability zone (typically 'a', 'b', or 'c'), used in config.toml|string|a|No|
|key_name|The name of the EC2 key pair to use|string|default|No|
|runners_name|Name of the runner, used in config.toml|string|""|Yes|
|runners_limit|Limit for the runners, used in config.toml|number|0|No|
|runners_concurrent|Concurrent value for the runners, used in config.toml|number|10|No|
|runners_idle_time|Idle time of the runners, used in config.toml|number|600|No|
|runners_idle_count|Idle count of the runners, used in config.toml|number|0|No|
|runners_max_builds|Max builds for each runner after which it will be removed, used in config.toml|number|0|No|
|runners_shm_size|shm_size for the runners, used in config.toml|number|0|No|
|runners_monitoring|Enable detailed CloudWatch monitoring for spot instances|bool|false|No|
|runners_off_peak_timezone|Off peak idle time zone of the runners, used in config.toml|string|Australia/Sydney|No|
|runners_off_peak_idle_count|Off peak idle count of the runners, used in config.toml|number|0|No|
|runners_off_peak_idle_time|Off peak idle time of the runners, used in config.toml|number|0|No|
|runners_off_peak_periods|Off peak periods of the runners, used in config.toml|string|""|Yes|
|runners_root_size|Runner instance root size in GB|number|16|No|
|runners_environment_vars|Environment variables during build execution as a list of strings like VAR1=value1, used in config.toml|list(string)|[]|No|
|runners_request_concurrency|Limit number of concurrent requests for new jobs from GitLab (default 1)|number|1|No|
|runners_output_limit|Sets the maximum build log size in kilobytes, by default set to 4096 (4MB)|number|4096|No|
|cache_bucket_name|The bucket name of the S3 cache bucket|string|""|Yes|
|cache_expiration_days|Number of days before cache objects expires|number|1|No|
|enable_gitlab_runner_ssh_access|Enables SSH Access to the GitLab Runner instance|bool|false|No|
|gitlab_runner_ssh_cidr_blocks|List of CIDR blocks to allow SSH Access to the GitLab Runner instance|list(string)|[0.0.0.0/0]|No|
|docker_machine_docker_cidr_blocks|List of CIDR blocks to allow Docker Access to the docker machine runner instance|list(string)|[0.0.0.0/0]|No|
|docker_machine_ssh_cidr_blocks|List of CIDR blocks to allow SSH Access to the docker machine runner instance|list(string)|[0.0.0.0/0]|No|
|gitlab_runner_registration_config||map(string)|(map)|No|
|enable_runner_user_data_trace_log|Enable bash xtrace for the user data script that creates the EC2 instance for the runner agent. Be aware this could log sensitive data such as you GitLab runner token|bool|false|No|
|schedule_config|Map containing the configuration of the ASG scale-in and scale-up for the runner instance|map|(map)|No|

### Outputs

|Name|Description|
|------------|---------------------|
|runner_as_group_name|Name of the autoscaling group for the gitlab-runner instance|
|runner_cache_bucket_arn|ARN of the S3 for the build cache.|
|runner_cache_bucket_name|Name of the S3 for the build cache.|
|runner_agent_role_arn|ARN of the role used for the ec2 instance for the GitLab runner agent.|
|runner_agent_role_name|Name of the role used for the ec2 instance for the GitLab runner agent.|
|runner_role_arn|ARN of the role used for the docker machine runners.|
|runner_role_name|Name of the role used for the docker machine runners.|
|runner_agent_sg_id|ID of the security group attached to the GitLab runner agent.|
|runner_sg_id|ID of the security group attached to the docker machine runners.|

### Examples

To create a Gitlab Runner:

```tf
variable "registration_token" {}

variable "enable_gitlab_runner_ssh_access" {
  default = false
}

variable "bucket_name" {
  default = "config-bucket-1c5a1978-d138-4084-a3b4-fd4c403a89a0"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "git@github.com:cmdlabs/terraform-aws-gitlab-runner.git"
  version = "2.5"

  name = "vpc-gitlab-runner"
  cidr = "10.0.0.0/16"

  azs             = [data.aws_availability_zones.available.names[0]]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_s3_endpoint = true
}

module "runner" {
  source = "git@github.com:cmdlabs/terraform-aws-gitlab-runner.git"

  key_name = "default"

  aws_region = "ap-southeast-2"

  cache_bucket_name = var.bucket_name

  vpc_id                   = module.vpc.vpc_id
  subnet_ids_gitlab_runner = module.vpc.private_subnets
  subnet_id_runners        = element(module.vpc.private_subnets, 0)

  runners_name             = "test-runner"
  runners_gitlab_url       = "https://gitlab.com"

  gitlab_runner_registration_config = {
    registration_token = var.registration_token
    description        = "runner default - auto"
    locked_to_project  = "true"
    run_untagged       = "false"
    maximum_timeout    = "3600"
    access_level       = "not_protected"
  }

  runners_off_peak_timezone   = "Australia/Sydney"
  runners_off_peak_idle_count = 0
  runners_off_peak_idle_time  = 60
  runners_off_peak_periods    = "[\"* * 0-9,17-23 * * mon-fri *\", \"* * * * * sat,sun *\"]"

  enable_gitlab_runner_ssh_access = var.enable_gitlab_runner_ssh_access
}
```

To apply that:

```text
▶ TF_VAR_registration_token=xxxxxxxx terraform apply
```

## License

Apache 2.0.
