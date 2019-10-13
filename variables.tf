variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "The target VPC for the docker-machine and runner instances"
  type        = string
}

variable "subnet_id_runners" {
  description = "List of subnets used for hosting the gitlab-runners"
  type        = string
}

variable "subnet_ids_gitlab_runner" {
  description = "Subnet used for hosting the GitLab runner"
  type        = list(string)
}

variable "aws_zone" {
  description = "AWS availability zone (typically 'a', 'b', or 'c'), will be used in the runner config.toml"
  type        = string
  default     = "a"
}

variable "key_name" {
  description = "The name of the EC2 key pair to use"
  type        = string
  default     = "default"
}

variable "runners_name" {
  description = "Name of the runner, will be used in the runner config.toml"
  type        = string
}

variable "runners_gitlab_url" {
  description = "URL of the GitLab instance to connect to"
  type        = string
}

variable "runners_token" {
  description = "Token for the runner, will be used in the runner config.toml"
  type        = string
  default     = "__REPLACED_BY_USER_DATA__"
}

variable "runners_limit" {
  description = "Limit for the runners, will be used in the runner config.toml"
  type        = number
  default     = 0
}

variable "runners_concurrent" {
  description = "Concurrent value for the runners, will be used in the runner config.toml"
  type        = number
  default     = 10
}

variable "runners_idle_time" {
  description = "Idle time of the runners, will be used in the runner config.toml"
  type        = number
  default     = 600
}

variable "runners_idle_count" {
  description = "Idle count of the runners, will be used in the runner config.toml"
  type        = number
  default     = 0
}

variable "runners_max_builds" {
  description = "Max builds for each runner after which it will be removed, will be used in the runner config.toml. By default set to 0, no maxBuilds will be set in the configuration"
  type        = number
  default     = 0
}

variable "runners_shm_size" {
  description = "shm_size for the runners, will be used in the runner config.toml"
  type        = number
  default     = 0
}

variable "runners_monitoring" {
  description = "Enable detailed cloudwatch monitoring for spot instances"
  type        = bool
  default     = false
}

variable "runners_off_peak_timezone" {
  description = "Off peak idle time zone of the runners, will be used in the runner config.toml"
  type        = string
  default     = "Australia/Sydney"
}

variable "runners_off_peak_idle_count" {
  description = "Off peak idle count of the runners, will be used in the runner config.toml"
  type        = number
  default     = 0
}

variable "runners_off_peak_idle_time" {
  description = "Off peak idle time of the runners, will be used in the runner config.toml"
  type        = number
  default     = 0
}

variable "runners_off_peak_periods" {
  description = "Off peak periods of the runners, will be used in the runner config.toml"
  type        = string
  default     = ""
}

variable "runners_root_size" {
  description = "Runner instance root size in GB"
  type        = number
  default     = 16
}

variable "runners_environment_vars" {
  description = "Environment variables during build execution, e.g. KEY=Value, see runner-public example. Will be used in the runner config.toml"
  type        = list(string)
  default     = []
}

variable "runners_request_concurrency" {
  description = "Limit number of concurrent requests for new jobs from GitLab (default 1)"
  type        = number
  default     = 1
}

variable "runners_output_limit" {
  description = "Sets the maximum build log size in kilobytes, by default set to 4096 (4MB)"
  type        = number
  default     = 4096
}

variable "cache_bucket_name" {
  type        = string
  description = "The bucket name of the S3 cache bucket"
}

variable "cache_expiration_days" {
  description = "Number of days before cache objects expires"
  type        = number
  default     = 1
}

variable "enable_gitlab_runner_ssh_access" {
  description = "Enables SSH Access to the gitlab runner instance"
  type        = bool
  default     = false
}

variable "gitlab_runner_ssh_cidr_blocks" {
  description = "List of CIDR blocks to allow SSH Access to the gitlab runner instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "docker_machine_docker_cidr_blocks" {
  description = "List of CIDR blocks to allow Docker Access to the docker machine runner instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "docker_machine_ssh_cidr_blocks" {
  description = "List of CIDR blocks to allow SSH Access to the docker machine runner instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "gitlab_runner_registration_config" {
  description = "Configuration used to register the runner. See the README for an example, or reference the examples in the examples directory of this repo"
  type        = map(string)

  default = {
    registration_token = ""
    description        = ""
    locked_to_project  = ""
    run_untagged       = ""
    maximum_timeout    = ""
    access_level       = ""
  }
}

variable "secure_parameter_store_runner_token_key" {
  description = "The key name used store the Gitlab runner token in Secure Parameter Store"
  type        = string
  default     = "runner-token"
}

variable "enable_manage_gitlab_token" {
  description = "Boolean to enable the management of the GitLab token in SSM. If `true` the token will be stored in SSM, which means the SSM property is a terraform managed resource. If `false` the Gitlab token will be stored in the SSM by the user-data script during creation of the the instance. However the SSM parameter is not managed by terraform and will remain in SSM after a `terraform destroy`"
  type        = bool
  default     = true
}

variable "cache_bucket" {
  description = "Configuration to control the creation of the cache bucket. By default the bucket will be created and used as shared cache. To use the same cache cross multiple runners disable the cration of the cache and provice a policy and bucket name. See the public runner example for more details"
  type        = map

  default = {
    create = true
    policy = ""
    bucket = ""
  }
}

variable "enable_runner_user_data_trace_log" {
  description = "Enable bash xtrace for the user data script that creates the EC2 instance for the runner agent. Be aware this could log sensitive data such as you GitLab runner token"
  type        = bool
  default     = false
}

variable "schedule_config" {
  description = "Map containing the configuration of the ASG scale-in and scale-up for the runner instance. Will only be used if enable_schedule is set to true. "
  type        = map
  default = {
    scale_in_recurrence  = "0 18 * * 1-5"
    scale_in_count       = 0
    scale_out_recurrence = "0 8 * * 1-5"
    scale_out_count      = 1
  }
}

variable "enable_runner_ssm_access" {
  description = "Add IAM policies to the runner agent instance to connect via the Session Manager"
  type        = bool
  default     = false
}

variable "runners_volumes_tmpfs" {
  description = "Mount temporary file systems to the main containers. Must consist of pairs of strings e.g. \"/var/lib/mysql\" = \"rw,noexec\", see example"
  type        = "list"
  default     = []
}

variable "runners_services_volumes_tmpfs" {
  description = "Mount temporary file systems to service containers. Must consist of pairs of strings e.g. \"/var/lib/mysql\" = \"rw,noexec\", see example"
  type        = "list"
  default     = []
}
