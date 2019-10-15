concurrent = ${runners_concurrent}
check_interval = 0

[[runners]]
  name = "${runners_name}"
  url = "${gitlab_url}"
  token = "##TOKEN##"
  executor = "docker+machine"
  environment = ${runners_environment_vars}
  request_concurrency = ${runners_request_concurrency}
  output_limit = ${runners_output_limit}
  limit = ${runners_limit}
  [runners.docker]
    tls_verify = false
    image = "${runners_image}"
    privileged = ${runners_privileged}
    disable_cache = false
    shm_size = ${runners_shm_size}
    pull_policy = "${runners_pull_policy}"
  [runners.cache]
    Type = "s3"
    Shared = false
    [runners.cache.s3]
      ServerAddress = "s3.amazonaws.com"
      BucketName = "${bucket_name}"
      BucketLocation = "${aws_region}"
      Insecure = false
  [runners.machine]
    IdleCount = ${runners_idle_count}
    IdleTime = ${runners_idle_time}
%{ if runners_max_builds != 0 ~}
    MaxBuilds = ${runners_max_builds}
%{ endif ~}
    MachineDriver = "amazonec2"
    MachineName = "runner-%s"
    MachineOptions = [
      "amazonec2-instance-type=${runners_instance_type}",
      "amazonec2-region=${aws_region}",
      "amazonec2-zone=${runners_aws_zone}",
      "amazonec2-vpc-id=${runners_vpc_id}",
      "amazonec2-subnet-id=${runners_subnet_id}",
      "amazonec2-private-address-only=true",
      "amazonec2-request-spot-instance=true",
      "amazonec2-spot-price=${runners_spot_price_bid}",
      "amazonec2-security-group=${runners_security_group_name}",
      "amazonec2-monitoring=${runners_monitoring}",
      "amazonec2-iam-instance-profile=${runners_instance_profile},
      "amazonec2-root-size=${runners_root_size}",
      "amazonec2-ami=${runners_ami}"
    ]
    OffPeakTimezone = "${runners_off_peak_timezone}"
    OffPeakIdleCount = ${runners_off_peak_idle_count}
    OffPeakIdleTime = ${runners_off_peak_idle_time}
%{ if runners_off_peak_periods != "" ~}
    OffPeakPeriods = ${runners_off_peak_periods}
%{ endif ~}
