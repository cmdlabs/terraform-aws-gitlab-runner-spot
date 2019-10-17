concurrent = ${globals_concurrent}
check_interval = 0

[[runners]]
  name = "${runners_name}"
  url = "${runners_url}"
  token = "##TOKEN##"
  executor = "docker+machine"
  environment = ${runners_environment}
  request_concurrency = ${runners_request_concurrency}
  output_limit = ${runners_output_limit}
  limit = ${runners_limit}
  [runners.docker]
    tls_verify = false
    image = "${runners_docker_image}"
    privileged = true
    disable_cache = false
    shm_size = ${runners_docker_shm_size}
    pull_policy = "always"
  [runners.cache]
    Type = "s3"
    Shared = false
    [runners.cache.s3]
      ServerAddress = "s3.amazonaws.com"
      BucketName = "${runners_cache_bucket_name}"
      BucketLocation = "${aws_region}"
      Insecure = false
  [runners.machine]
    IdleCount = ${runners_machine_idle_count}
    IdleTime = ${runners_machine_idle_time}
%{ if runners_machine_max_builds != 0 ~}
    MaxBuilds = ${runners_machine_max_builds}
%{ endif ~}
    MachineDriver = "amazonec2"
    MachineName = "runner-%s"
    MachineOptions = [
      "amazonec2-instance-type=${docker_machine_instance_type}",
      "amazonec2-region=${aws_region}",
      "amazonec2-zone=${aws_availability_zone}",
      "amazonec2-vpc-id=${vpc_id}",
      "amazonec2-subnet-id=${subnet_id}",
      "amazonec2-private-address-only=true",
      "amazonec2-request-spot-instance=true",
      "amazonec2-spot-price=${docker_machine_spot_price}",
      "amazonec2-security-group=${docker_machine_security_group}",
      "amazonec2-monitoring=false",
      "amazonec2-iam-instance-profile=${docker_machine_iam_instance_profile}",
      "amazonec2-root-size=${docker_machine_root_size}",
      "amazonec2-ami=${docker_machine_ami}"
    ]
    OffPeakTimezone = "${runners_machine_off_peak_timezone}"
    OffPeakIdleCount = ${runners_machine_off_peak_idle_count}
    OffPeakIdleTime = ${runners_machine_off_peak_idle_time}
%{ if runners_machine_off_peak_periods != "" ~}
    OffPeakPeriods = ${runners_machine_off_peak_periods}
%{ endif ~}
