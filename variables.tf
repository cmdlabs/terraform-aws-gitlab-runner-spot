variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "The target VPC for the docker-machine and runner instances"
  type        = string
}

variable "subnet_id_runners" {
  description = "Subnet used for hosting the GitLab runner"
  type        = string
}

variable "subnet_ids_gitlab_runner" {
  description = "List of subnets used for hosting the GitLab runners"
  type        = list(string)
}

variable "runners_name" {
  description = "The Runner's description, just informatory"
  type        = string
}

variable "runners_url" {
  description = "The GitLab URL for the instance to connect to"
  type        = string
}

variable "runners_environment" {
  description = "Append or overwrite environment variables"
  type        = list(string)
  default     = []
}

variable "aws_zone" {
  description = "AWS availability zone (typically 'a', 'b', or 'c'), used in config.toml"
  type        = string
  default     = "a"
}

variable "key_name" {
  description = "The name of the EC2 key pair to use"
  type        = string
  default     = "default"
}

variable "runners_limit" {
  description = "Limit for the runners, used in config.toml"
  type        = number
  default     = 0
}

variable "runners_concurrent" {
  description = "Concurrent value for the runners, used in config.toml"
  type        = number
  default     = 10
}

variable "runners_idle_time" {
  description = "Idle time of the runners, used in config.toml"
  type        = number
  default     = 600
}

variable "runners_idle_count" {
  description = "Idle count of the runners, used in config.toml"
  type        = number
  default     = 0
}

variable "runners_max_builds" {
  description = "Max builds for each runner after which it will be removed, used in config.toml"
  type        = number
  default     = 0
}

variable "runners_shm_size" {
  description = "shm_size for the runners, used in config.toml"
  type        = number
  default     = 0
}

variable "runners_monitoring" {
  description = "Enable detailed CloudWatch monitoring for spot instances"
  type        = bool
  default     = false
}

variable "runners_off_peak_timezone" {
  description = "Off peak idle time zone of the runners, used in config.toml"
  type        = string
  default     = "Australia/Sydney"
}

variable "runners_off_peak_idle_count" {
  description = "Off peak idle count of the runners, used in config.toml"
  type        = number
  default     = 0
}

variable "runners_off_peak_idle_time" {
  description = "Off peak idle time of the runners, used in config.toml"
  type        = number
  default     = 0
}

variable "runners_off_peak_periods" {
  description = "Off peak periods of the runners, used in config.toml"
  type        = string
  default     = ""
}

variable "runners_root_size" {
  description = "Runner instance root size in GB"
  type        = number
  default     = 16
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
  description = "Enables SSH Access to the GitLab Runner instance"
  type        = bool
  default     = false
}

variable "gitlab_runner_ssh_cidr_blocks" {
  description = "List of CIDR blocks to allow SSH Access to the GitLab Runner instance"
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
  description = "Configuration used to register the runner"
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

variable "enable_runner_user_data_trace_log" {
  description = "Enable bash xtrace for the user data script that creates the EC2 instance for the runner agent. Be aware this could log sensitive data such as you GitLab runner token"
  type        = bool
  default     = false
}

variable "schedule_config" {
  description = "Map containing the configuration of the ASG scale-in and scale-up for the runner instance"
  type        = map
  default = {
    scale_in_recurrence  = "0 18 * * 1-5"
    scale_in_count       = 0
    scale_out_recurrence = "0 8 * * 1-5"
    scale_out_count      = 1
  }
}
