#!/usr/bin/env bash

awslogs_conf='/etc/awslogs/awslogs.conf'
awscli_conf='/etc/awslogs/awscli.conf'
config_toml='/etc/gitlab-runner/config.toml'

update_hosts_file() {
  echo "\
127.0.0.1   localhost localhost.localdomain $(hostname)" \
  >> /etc/hosts
}

update_system() {
  yum -y update
}

install_deps() {
  yum -y install aws-cli awslogs jq
}

configure_cloudwatch() {
  local instance_id region

  read -r instance_id region <<< "$(
    curl -s http://169.254.169.254/latest/dynamic/instance-identity/document \
      | jq -r '[.instanceId, .region] | @tsv'
  )"

  cat > "$awslogs_conf" <<EOF
[general]
state_file = /var/lib/awslogs/agent-state

[/var/log/dmesg]
file = /var/log/dmesg
log_stream_name = $instance_id/dmesg
log_group_name = ${gitlab_runner_log_group_name}
initial_position = start_of_file

[/var/log/messages]
file = /var/log/messages
log_stream_name = $instance_id/messages
log_group_name = ${gitlab_runner_log_group_name}
datetime_format = %b %d %H:%M:%S
initial_position = start_of_file

[/var/log/user-data.log]
file = /var/log/user-data.log
log_stream_name = $instance_id/user-data
log_group_name = ${gitlab_runner_log_group_name}
initial_position = start_of_file
EOF

  sed -i '
    s/region = us-east-1/region = '"$region"'/
  ' "$awscli_conf"

  service awslogs start
  chkconfig awslogs on
}

generate_config_toml() {
  mkdir -p /etc/gitlab-runner
  cat > "$config_toml" <<EOF
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
    --with-decryption --region "${aws_region}" | jq -r '.Parameters[0].Value')

  if [ "$token" == "null" ] ; then
    response=$(
      curl -X POST -L "${runners_url}/api/v4/runners" \
        -F "token=${gitlab_runner_registration_token}" \
        -F "description=${gitlab_runner_description}" \
        -F "locked=${gitlab_runner_locked_to_project}" \
        -F "maximum_timeout=${gitlab_runner_maximum_timeout}" \
        -F "access_level=${gitlab_runner_access_level}" \
    )

    token=$(jq -r .token <<< "$response")

    if [ "$token" == "null" ] ; then
      echo "Received the following error:"
      echo "$response"
      return
    fi

    aws ssm put-parameter --overwrite --type SecureString --name \
      "${runners_ssm_token_key}" --value "$token" --region "${aws_region}"
  fi

  sed -i 's/##TOKEN##/'"$token"'/' "$config_toml"
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

if [ "$0" == "$BASH_SOURCE" ] ; then
  main
fi

# vim: set ft=sh:
