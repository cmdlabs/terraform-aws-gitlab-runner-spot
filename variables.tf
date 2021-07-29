variable "aws_region" {
  description = "Name of S3 region for the runner cache and SSM"
  type        = string
}

variable "aws_availability_zone" {
  description = "AWS availability zone ('a', 'b', 'c' etc)"
  type        = string
  default     = "a"
}

variable "tags" {
  description = "Tags for the runner instances"
  type        = list(map(string))

  default = [{
    key                 = "Name"
    value               = "gitlab-runner-manager"
    propagate_at_launch = true
  }]
}

variable "vpc_id" {
  description = "The target VPC for the docker-machine and runner instances"
  type        = string
}

variable "subnet_id" {
  description = "Subnet used for hosting the GitLab runner"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnets used for hosting the GitLab runners"
  type        = list(string)
}

variable "key_name" {
  description = "The name of the EC2 key pair to use"
  type        = string
  default     = "default"
}

variable "instance_type" {
  description = "Instance type of the GitLab Runner instance"
  type        = string
  default     = "m5a.large"
}

variable "request_spot_instance" {
  description = "Whether to request spot instances for the GitLab Runner instance"
  type        = bool
  default     = true
}

variable "spot_price" {
  description = "Spot bid price for the GitLab Runner instance"
  type        = string
  default     = "0.06"
}

variable "enable_ssh_access" {
  description = "Enables SSH access to the GitLab Runner instance"
  type        = bool
  default     = false
}

variable "ssh_cidr_blocks" {
  description = "List of CIDR blocks to allow SSH Access to docker machine and the GitLab Runner"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "gitlab_runner_version" {
  description = "Version of the GitLab Runner to install"
  type        = string
  default     = "14.1.0"
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
    tag_list           = ""
    docker_user        = ""
    docker_password    = ""
  }
}

variable "schedule_config" {
  description = "Map containing the configuration of the ASG scale-in and scale-up for the runner instance"
  type        = map
  default = {
    enabled              = true
    scale_in_recurrence  = "0 18 * * 1-5"
    scale_in_count       = 0
    scale_out_recurrence = "0 8 * * 1-5"
    scale_out_count      = 1
  }
}
variable "globals_concurrent" {
  description = "Concurrent value for the runners"
  type        = number
  default     = 10
}

variable "runners_name" {
  description = "The Runner's description, just informatory"
  type        = string
}

variable "runners_tags" {
  description = "amazonec2-tags key-value pairs for AWS extra tags, just informatory"
  type        = string
  default     = "runner-manager-name,gitlab-runner-manager"
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

variable "runners_request_concurrency" {
  description = "Limit number of concurrent requests for new jobs from GitLab"
  type        = number
  default     = 1
}

variable "runners_output_limit" {
  description = "Set maximum build log size in KB"
  type        = number
  default     = 4096
}

variable "runners_limit" {
  description = "Limit how many jobs can be handled concurrently by this token"
  type        = number
  default     = 0
}

variable "runners_docker_shm_size" {
  description = "Shared memory size for images (in bytes)"
  type        = number
  default     = 0
}

variable "runners_docker_volumes" {
  description = "List of volumes for images"
  type        = list(string)
  default     = []
}

variable "runners_cache_bucket_name" {
  type        = string
  description = "Name of the storage bucket where runner cache will be stored"
}

variable "runners_machine_idle_count" {
  description = "Number of machines that need to be created and waiting in Idle state"
  type        = number
  default     = 0
}

variable "runners_machine_idle_time" {
  description = "Time (in seconds) for machine to be in Idle state before it is removed"
  type        = number
  default     = 600
}

variable "runners_machine_max_builds" {
  description = "Builds count after which machine will be removed"
  type        = number
  default     = 0
}

variable "runners_machine_off_peak_timezone" {
  description = "Off peak idle time zone of the runners"
  type        = string
  default     = "Australia/Sydney"
}

variable "runners_machine_off_peak_idle_count" {
  description = "Off peak idle count of the runners"
  type        = number
  default     = 0
}

variable "runners_machine_off_peak_idle_time" {
  description = "Off peak idle time of the runners"
  type        = number
  default     = 0
}

variable "runners_machine_off_peak_periods" {
  description = "Time periods when the scheduler is in the OffPeak mode. A list of cron-style patterns"
  type        = list(string)
  default     = []
}
