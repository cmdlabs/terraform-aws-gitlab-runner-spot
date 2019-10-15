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
|aws_region|Name of S3 region for the runner cache and SSM|string|""|Yes|
|aws_availability_zone|AWS availability zone ('a', 'b', 'c' etc)|string|a|No|
|vpc_id|The target VPC for the docker-machine and runner instances|string|""|Yes|
|subnet_id|Subnet used for hosting the GitLab runner|string|""|Yes|
|subnet_ids|List of subnets used for hosting the GitLab runners|list(string)|""|Yes|
|key_name|The name of the EC2 key pair to use|string|default|No|
|enable_ssh_access|Enables SSH access to the GitLab Runner instance|bool|false|No|
|ssh_cidr_blocks|List of CIDR blocks to allow SSH Access to docker machine and the GitLab Runner|list(string)|[0.0.0.0/0]|No|
|enable_user_data_xtrace|Enable bash xtrace for the user data script that creates the EC2 instance for the runner agent. Be aware this could log sensitive data such as you GitLab runner token|bool|false|No|
|gitlab_runner_registration_config||map(string)|(map)|No|
|schedule_config|Map containing the configuration of the ASG scale-in and scale-up for the runner instance|map|(map)|No|
|globals_concurrent|Concurrent value for the runners|number|10|No|
|runners_name|The Runner's description, just informatory|string|""|Yes|
|runners_url|The GitLab URL for the instance to connect to|string|""|Yes|
|runners_environment|Append or overwrite environment variables|list(string)|[]|No|
|runners_request_concurrency|Limit number of concurrent requests for new jobs from GitLab|number|1|No|
|runners_output_limit|Set maximum build log size in KB|number|4096|No|
|runners_limit|Limit how many jobs can be handled concurrently by this token|number|0|No|
|runners_docker_shm_size|Shared memory size for images (in bytes)|number|0|No|
|runners_cache_bucket_name|Name of the storage bucket where runner cache will be stored|string|""|Yes|
|runners_machine_idle_count|Number of machines that need to be created and waiting in Idle state|number|0|No|
|runners_machine_idle_time|Time (in seconds) for machine to be in Idle state before it is removed|number|600|No|
|runners_machine_max_builds|Builds count after which machine will be removed|number|0|No|
|runners_machine_off_peak_timezone|Off peak idle time zone of the runners|string|Australia/Sydney|No|
|runners_machine_off_peak_idle_count|Off peak idle count of the runners|number|0|No|
|runners_machine_off_peak_idle_time|Off peak idle time of the runners|number|0|No|
|runners_machine_off_peak_periods|Time periods when the scheduler is in the OffPeak mode. A list of cron-style patterns|list(string)|[]|No|

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

variable "enable_ssh_access" {
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

  runners_cache_bucket_name = var.bucket_name

  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnets
  subnet_id    = module.vpc.private_subnets[0]

  runners_name = "test-runner"
  runners_url  = "https://gitlab.com"

  gitlab_runner_registration_config = {
    registration_token = var.registration_token
    description        = "runner default - auto"
    locked_to_project  = "true"
    run_untagged       = "false"
    maximum_timeout    = "3600"
    access_level       = "not_protected"
  }

  runners_machine_off_peak_timezone   = "Australia/Sydney"
  runners_machine_off_peak_idle_count = 0
  runners_machine_off_peak_idle_time  = 60
  runners_machine_off_peak_periods    = [
    "* * 0-9,17-23 * * mon-fri *",
    "* * * * * sat,sun *"
  ]

  enable_ssh_access = var.enable_ssh_access
}
```

To apply that:

```text
▶ TF_VAR_registration_token=xxxxxxxx terraform apply
```

## License

Apache 2.0.
