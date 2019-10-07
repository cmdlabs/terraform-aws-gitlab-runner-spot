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

By default the EC2 instance is allowed to create the required roles, but this can be disabled by setting the option `allow_iam_service_linked_role_creation` to `false`. If disabled you must ensure the roles exist. You can create them manually or via Terraform.

```tf
resource "aws_iam_service_linked_role" "spot" {
  aws_service_name = "spot.amazonaws.com"
}

resource "aws_iam_service_linked_role" "autoscaling" {
  aws_service_name = "autoscaling.amazonaws.com"
}
```

### GitLab runner token configuration

The runner is registered on initial deployment.

To register the runner automatically set the variable `gitlab_runner_registration_config["token"]`. This token value can be found in your GitLab project, group, or global settings. For a generic runner you can find the token in the admin section. By default the runner will be locked to the target project, not run untagged. Below is an example of the configuration map.

``` hcl
gitlab_runner_registration_config = {
  registration_token = "<registration token>"
  description        = "<some description>"
  locked_to_project  = "true"
  run_untagged       = "false"
  maximum_timeout    = "3600"
  access_level       = "<not_protected OR ref_protected, ref_protected runner will only run on pipelines triggered on protected branches. Defaults to not_protected>"
}
```

For migration to the new setup simply add the runner token to the parameter store. Once the runner is started it will lookup the required values via the parameter store. If the value is `null` a new runner will be created.

```bash
# set the following variables, look up the variables in your Terraform config.
# see your Terraform variables to fill in the vars below.
aws-region=<${var.aws_region}>
token=<runner-token-see-your-gitlab-runner>
parameter-name=<${var.environment}>-<${var.secure_parameter_store_runner_token_key}>

aws ssm put-parameter --overwrite --type SecureString --name "${parameter-name}" --value ${token} --region "${aws-region}"
```

Once you have created the parameter, you must remove the variable `runners_token` from your config. The next time your gitlab runner instance is created it will look up the token from the SSM parameter store.

Finally, the runner still supports the manual runner creation. No changes are required. Please keep in mind that this setup will be removed in future releases.

### GitLab runner cache

By default the module creates a cache for the runner in S3. Old objects are automatically remove via a configurable life cycle policy on the bucket.

Creation of the bucket can be disabled and managed outside this module. A good use case is for sharing the cache cross multiple runners. For this purpose the cache is implemented as sub module. For more details see the [cache module](https://github.com/npalm/terraform-aws-gitlab-runner/tree/develop/cache). An example implementation of this use case can be find in the [runner-public](https://github.com/npalm/terraform-aws-gitlab-runner/tree/__GIT_REF__/examples/runner-public) example.

### Inputs

The below outlines the current parameters and defaults.

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-------:|:--------:|
|aws_region|AWS region.|string|""|No|
|aws_zone|AWS availability zone (typically 'a', 'b', or 'c').|string|a|No|
|vpc_id|The target VPC for the docker-machine and runner instances.|string|""|No|
|subnet_id_runners|List of subnets used for hosting the gitlab-runners.|string|""|No|
|subnet_ids_gitlab_runner|Subnet used for hosting the GitLab runner.|list(string)|""|No|
|key_name|The name of the EC2 key pair to use|string|default|No|
|instance_type|Instance type used for the GitLab runner.|string|t3.micro|No|
|runner_instance_spot_price|By setting a spot price bid price the runner agent will be created via a spot request. Be aware that spot instances can be stopped by AWS.|string|""|No|
|docker_machine_instance_type|Instance type used for the instances hosting docker-machine.|string|m5a.large|No|
|docker_machine_spot_price_bid|Spot price bid.|string|0.06|No|
|docker_machine_version|Version of docker-machine.|string|0.16.2|No|
|runners_name|Name of the runner, will be used in the runner config.toml.|string|""|No|
|runners_gitlab_url|URL of the GitLab instance to connect to.|string|""|No|
|runners_token|Token for the runner, will be used in the runner config.toml.|string|__REPLACED_BY_USER_DATA__|No|
|runners_limit|Limit for the runners, will be used in the runner config.toml.|number|0|No|
|runners_concurrent|Concurrent value for the runners, will be used in the runner config.toml.|number|10|No|
|runners_idle_time|Idle time of the runners, will be used in the runner config.toml.|number|600|No|
|runners_idle_count|Idle count of the runners, will be used in the runner config.toml.|number|0|No|
|runners_max_builds|Max builds for each runner after which it will be removed, will be used in the runner config.toml. By default set to 0, no maxBuilds will be set in the configuration.|number|0|No|
|runners_image|Image to run builds, will be used in the runner config.toml|string|docker:18.03.1-ce|No|
|runners_privileged|Runners will run in privileged mode, will be used in the runner config.toml|bool|true|No|
|runners_additional_volumes|Additional volumes that will be used in the runner config.toml, e.g Docker socket|list|[]|No|
|runners_shm_size|shm_size for the runners, will be used in the runner config.toml|number|0|No|
|runners_pull_policy|pull_policy for the runners, will be used in the runner config.toml|string|always|No|
|runners_monitoring|Enable detailed cloudwatch monitoring for spot instances.|bool|false|No|
|runners_off_peak_timezone|Off peak idle time zone of the runners, will be used in the runner config.toml.|string|""|No|
|runners_off_peak_idle_count|Off peak idle count of the runners, will be used in the runner config.toml.|number|0|No|
|runners_off_peak_idle_time|Off peak idle time of the runners, will be used in the runner config.toml.|number|0|No|
|runners_off_peak_periods|Off peak periods of the runners, will be used in the runner config.toml.|string|""|No|
|runners_root_size|Runner instance root size in GB.|number|16|No|
|create_runners_iam_instance_profile|Boolean to control the creation of the runners IAM instance profile|bool|true|No|
|runners_iam_instance_profile_name|IAM instance profile name of the runners, will be used in the runner config.toml|string|""|No|
|runners_environment_vars|Environment variables during build execution, e.g. KEY=Value, see runner-public example. Will be used in the runner config.toml|list(string)|[]|No|
|runners_pre_build_script|Script to execute in the pipeline just before the build, will be used in the runner config.toml|string|""|No|
|runners_post_build_script|Commands to be executed on the Runner just after executing the build, but before executing after_script. |string|""|No|
|runners_pre_clone_script|Commands to be executed on the Runner before cloning the Git repository. this can be used to adjust the Git client configuration first, for example. |string|""|No|
|runners_request_concurrency|Limit number of concurrent requests for new jobs from GitLab (default 1)|number|1|No|
|runners_output_limit|Sets the maximum build log size in kilobytes, by default set to 4096 (4MB)|number|4096|No|
|userdata_pre_install|User-data script snippet to insert before GitLab runner install|string|""|No|
|userdata_post_install|User-data script snippet to insert after GitLab runner install|string|""|No|
|runners_use_private_address|Restrict runners to the use of a private IP address|bool|true|No|
|docker_machine_user|Username of the user used to create the spot instances that host docker-machine.|string|docker-machine|No|
|cache_bucket_prefix|Prefix for s3 cache bucket name.|string|""|No|
|cache_bucket_name_include_account_id|Boolean to add current account ID to cache bucket name.|bool|true|No|
|cache_bucket_versioning|Boolean used to enable versioning on the cache bucket, false by default.|bool|false|No|
|cache_expiration_days|Number of days before cache objects expires.|number|1|No|
|cache_shared|Enables cache sharing between runners, false by default.|bool|false|No|
|gitlab_runner_version|Version of the GitLab runner.|string|12.3.0|No|
|enable_gitlab_runner_ssh_access|Enables SSH Access to the gitlab runner instance.|bool|false|No|
|gitlab_runner_ssh_cidr_blocks|List of CIDR blocks to allow SSH Access to the gitlab runner instance.|list(string)|[0.0.0.0/0]|No|
|docker_machine_docker_cidr_blocks|List of CIDR blocks to allow Docker Access to the docker machine runner instance.|list(string)|[0.0.0.0/0]|No|
|docker_machine_ssh_cidr_blocks|List of CIDR blocks to allow SSH Access to the docker machine runner instance.|list(string)|[0.0.0.0/0]|No|
|enable_cloudwatch_logging|Boolean used to enable or disable the CloudWatch logging.|bool|true|No|
|allow_iam_service_linked_role_creation|Boolean used to control attaching the policy to a runner instance to create service linked roles.|bool|true|No|
|docker_machine_options|List of additional options for the docker machine config. Each element of this list must be a key=value pair. E.g. '[\|list(string)|[]|No|
|instance_role_json|Default runner instance override policy, expected to be in JSON format.|string|""|No|
|docker_machine_role_json|Docker machine runner instance override policy, expected to be in JSON format.|string|""|No|
|ami_filter|List of maps used to create the AMI filter for the Gitlab runner agent AMI. Currently Amazon Linux 2 `amzn2-ami-hvm-2.0.????????-x86_64-ebs` looks to *not* be working for this configuration.|map(list(string))|(map)|No|
|ami_owners|The list of owners used to select the AMI of Gitlab runner agent instances.|list(string)|[amazon]|No|
|runner_ami_filter|List of maps used to create the AMI filter for the Gitlab runner docker-machine AMI.|map(list(string))|(map)|No|
|runner_ami_owners|The list of owners used to select the AMI of Gitlab runner docker-machine instances.|list(string)|[099720109477]|No|
|gitlab_runner_registration_config||map(string)|(map)|No|
|secure_parameter_store_runner_token_key|The key name used store the Gitlab runner token in Secure Parameter Store|string|runner-token|No|
|enable_manage_gitlab_token|Boolean to enable the management of the GitLab token in SSM. If `true` the token will be stored in SSM, which means the SSM property is a terraform managed resource. If `false` the Gitlab token will be stored in the SSM by the user-data script during creation of the the instance. However the SSM parameter is not managed by terraform and will remain in SSM after a `terraform destroy`.|bool|true|No|
|overrides|This maps provides the possibility to override some defaults. The following attributes are supported: `name_sg` overwrite the `Name` tag for all security groups created by this module. `name_runner_agent_instance` override the `Name` tag for the ec2 instance defined in the auto launch configuration. `name_docker_machine_runners` ovverrid the `Name` tag spot instances created by the runner agent.|map(string)|(map)|No|
|cache_bucket|Configuration to control the creation of the cache bucket. By default the bucket will be created and used as shared cache. To use the same cache cross multiple runners disable the cration of the cache and provice a policy and bucket name. See the public runner example for more details.|map|(map)|No|
|enable_runner_user_data_trace_log|Enable bash xtrace for the user data script that creates the EC2 instance for the runner agent. Be aware this could log sensitive data such as you GitLab runner token.|bool|false|No|
|enable_schedule|Flag used to enable/disable auto scaling group schedule for the runner instance. |bool|false|No|
|schedule_config|Map containing the configuration of the ASG scale-in and scale-up for the runner instance. Will only be used if enable_schedule is set to true. |map|(map)|No|
|runner_root_block_device|The EC2 instance root block device configuration. Takes the following keys: `delete_on_termination`, `volume_type`, `volume_size`, `iops`|map(string)|{}|No|
|enable_runner_ssm_access|Add IAM policies to the runner agent instance to connect via the Session Manager.|bool|false|No|
|runners_volumes_tmpfs|Mount temporary file systems to the main containers. Must consist of pairs of strings e.g. \|"list"|[]|No|
|runners_services_volumes_tmpfs|Mount temporary file systems to service containers. Must consist of pairs of strings e.g. \|"list"|[]|No|

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

  vpc_id                   = module.vpc.vpc_id
  subnet_ids_gitlab_runner = module.vpc.private_subnets
  subnet_id_runners        = element(module.vpc.private_subnets, 0)

  runners_name             = "test-runner"
  runners_gitlab_url       = "https://gitlab.com"
  enable_runner_ssm_access = true

  docker_machine_spot_price_bid = "0.06"

  gitlab_runner_registration_config = {
    registration_token = "GBpeL612xfp3DtEjzZsx"
    description        = "runner default - auto"
    locked_to_project  = "true"
    run_untagged       = "false"
    maximum_timeout    = "3600"
  }

  runners_off_peak_timezone   = "Australia/Sydney"
  runners_off_peak_idle_count = 0
  runners_off_peak_idle_time  = 60

  runners_privileged         = "true"
  runners_additional_volumes = ["/certs/client"]

  runners_volumes_tmpfs = [
    { "/var/opt/cache" = "rw,noexec" },
  ]

  runners_services_volumes_tmpfs = [
    { "/var/lib/mysql" = "rw,noexec" },
  ]

  # working 9 to 5 :)
  runners_off_peak_periods = "[\"* * 0-9,17-23 * * mon-fri *\", \"* * * * * sat,sun *\"]"
}
```

To apply that:

```text
▶ TF_VAR_TODO terraform apply
```

## License

Apache 2.0.
