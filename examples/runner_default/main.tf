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

variable "vpc_id" {}
variable "subnet_ids" {
  type = list(string)
}

module "runner" {
  source = "../../"

  key_name = "default"

  aws_region = "ap-southeast-2"

  runners_cache_bucket_name = var.bucket_name

  vpc_id       = var.vpc_id
  subnet_ids   = var.subnet_ids
  subnet_id    = var.subnet_ids[0]

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
