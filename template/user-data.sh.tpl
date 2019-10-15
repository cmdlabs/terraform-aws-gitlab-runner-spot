#!/usr/bin/env bash

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

[ "${enable_user_data_xtrace}" == "true" ] && set -x

update_hosts_file() {
  echo "\
127.0.0.1   localhost localhost.localdomain $(hostname)" \
  >> /etc/hosts
}

update_system() {
  yum -y update
}

install_deps() {
  echo 'installing additional software for logging'
  yum -y install aws-cli awslogs jq
}

configure_cloudwatch() {
  local instance_id=$(curl -s \
    https://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .instanceId)

  cat > /etc/awslogs/awslogs.conf <<EOF
[general]
state_file = /var/lib/awslogs/agent-state

[/var/log/dmesg]
file = /var/log/dmesg
log_stream_name = $instance_id/dmesg
log_group_name = gitlab-runner-log-group
initial_position = start_of_file

[/var/log/messages]
file = /var/log/messages
log_stream_name = $instance_id/messages
log_group_name = gitlab-runner-log-group
datetime_format = %b %d %H:%M:%S
initial_position = start_of_file

[/var/log/user-data.log]
file = /var/log/user-data.log
log_stream_name = $instance_id/user-data
log_group_name = gitlab-runner-log-group
initial_position = start_of_file
EOF

  local region=$(curl -s \
    https://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)

  sed -i '
    s/region = us-east-1/region = '"$region"'/
  ' /etc/awslogs/awscli.conf

  service awslogs start
  chkconfig awslogs on
}

generate_config_toml() {
  mkdir -p /etc/gitlab-runner
  cat > /etc/gitlab-runner/config.toml <<EOF
${runners_config}
EOF
}

install_gitlab_runner() {
  curl -L \
    https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh | bash
  yum -y install gitlab-runner-"${gitlab_runner_version}"
  curl --fail --retry 6 -L \
    https://github.com/docker/machine/releases/download/v"${docker_machine_version}"/docker-machine-"$(uname -s)"-"$(uname -m)" > /tmp/docker-machine
  chmod +x /tmp/docker-machine
  cp /tmp/docker-machine /usr/local/bin/docker-machine
  ln -s /usr/local/bin/docker-machine /usr/bin/docker-machine

  # Create a dummy machine so that the cert is generated properly
  # See: https://gitlab.com/gitlab-org/gitlab-runner/issues/3676
  docker-machine create --driver none --url localhost dummy-machine
}

register_runner() {
  token=$(aws ssm get-parameters --names "${runners_ssm_token_key}" \
    --with-decryption --region "${ssm_region}" | jq -r '.Parameters[].Value')

  if [ "$token" == "null" ] ; then
    token=$(curl --request POST -L "${runners_gitlab_url}/api/v4/runners" \
        --form "token=${gitlab_runner_registration_token}" \
        --form "description=${giltab_runner_description}" \
        --form "locked=${gitlab_runner_locked_to_project}" \
        --form "run_untagged=${gitlab_runner_run_untagged}" \
        --form "maximum_timeout=${gitlab_runner_maximum_timeout}" \
        --form "access_level=${gitlab_runner_access_level}" \
      | jq -r .token)

    aws ssm put-parameter --overwrite --type SecureString --name \
      "${runners_ssm_token_key}" --value "$token" --region "${ssm_region}"
  fi

  sed -i 's/##TOKEN##/'"$token"'/' /etc/gitlab-runner/config.toml
}

start_gitlab_runner() {
  service gitlab-runner restart
  chkconfig gitlab-runner on
}

main() {
  update_hosts_file
  update_system
  install_deps
  configure_cloudwatch
  generate_config_toml
  install_gitlab_runner
  register_runner
  start_gitlab_runner
}

if [ "$0" == "${BASH_SOURCE[0]}" ] ; then
  main
fi

# vim: set ft=sh:
