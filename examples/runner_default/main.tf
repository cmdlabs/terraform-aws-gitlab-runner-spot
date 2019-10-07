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

  ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCpVsFWujoVyCo/IopxGoilRntA52N+VS2JKTHOO847SY+56GVPd5Rj7FSdGet/r/wIqPSQGtmfxyTUseiaP8NrHxeCt9MQlrFEXBO/z/5NEfLtAS/DAbZKZBiFlJkYiHrWKNG2luINIqSAOLQk9DsgUn2zCPG7Ysdf8p02U6EzUZovpMqercPwlP0DuDspdSIHnq8gtwBzqyu2NnWnAUlREyjmscBTvHBkjFR8gQl1PNR7qApXVYR/1Qn5Z97RUbM7ld4J3wZYlZdR/Y5zR5l3G8SBn01/MddL6j/D8Gb6lYEqwB+qJGcsEnQSNCkz2aXTZEphwjpWhQ2dgBbOs7W9"

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
