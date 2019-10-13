variable "enable_gitlab_runner_ssh_access" {}
variable "registration_token" {}

variable "bucket_name" {
  default = "config-bucket-1c5a1978-d138-4084-a3b4-fd4c403a89a0"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
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
  source = "../../"

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
