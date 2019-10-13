#!/bin/bash -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

if [[ `echo ${user_data_trace_log}` == false ]] 
then
  set -x
fi

# Add current hostname to hosts file
tee /etc/hosts <<EOL
127.0.0.1   localhost localhost.localdomain `hostname`
EOL

for i in {1..7}
do
  echo "Attempt: ---- " $i
  yum -y update  && break || sleep 60
done

echo 'installing additional software for logging'
# installing in a loop to ensure the cli is installed.
for i in {1..7}
do
  echo "Attempt: ---- " $i
  yum install -y aws-cli awslogs jq && break || sleep 60
done

# Inject the CloudWatch Logs configuration file contents
cat > /etc/awslogs/awslogs.conf <<- EOF
[general]
state_file = /var/lib/awslogs/agent-state

[/var/log/dmesg]
file = /var/log/dmesg
log_stream_name = {instanceId}/dmesg
log_group_name = gitlab-runner-log-group
initial_position = start_of_file

[/var/log/messages]
file = /var/log/messages
log_stream_name = {instanceId}/messages
log_group_name = gitlab-runner-log-group
datetime_format = %b %d %H:%M:%S
initial_position = start_of_file

[/var/log/user-data.log]
file = /var/log/user-data.log
log_stream_name = {instanceId}/user-data
log_group_name = gitlab-runner-log-group
initial_position = start_of_file
EOF

# Set the region to send CloudWatch Logs data to (the region where the instance is located)
region=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
sed -i -e "s/region = us-east-1/region = $region/g" /etc/awslogs/awscli.conf

# Replace instance id.
instanceId=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r .instanceId)
sed -i -e "s/{instanceId}/$instanceId/g" /etc/awslogs/awslogs.conf

service awslogs start
chkconfig awslogs on

mkdir -p /etc/gitlab-runner
cat > /etc/gitlab-runner/config.toml <<- EOF
${runners_config}
EOF

curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh | bash
yum install gitlab-runner-${gitlab_runner_version} -y
curl  --fail --retry 6 -L https://github.com/docker/machine/releases/download/v${docker_machine_version}/docker-machine-`uname -s`-`uname -m` >/tmp/docker-machine && \
  chmod +x /tmp/docker-machine && \
  cp /tmp/docker-machine /usr/local/bin/docker-machine && \
  ln -s /usr/local/bin/docker-machine /usr/bin/docker-machine

# Create a dummy machine so that the cert is generated properly
# See: https://gitlab.com/gitlab-org/gitlab-runner/issues/3676
docker-machine create --driver none --url localhost dummy-machine

# Install jq if not exists
if ! [ -x "$(command -v jq)" ]; then
  yum install jq -y
fi

token=$(aws ssm get-parameters --names "${runners_ssm_token_key}" --with-decryption --region "${ssm_region}" | jq -r ".Parameters | .[0] | .Value")
if [[ `echo ${runners_token}` == "__REPLACED_BY_USER_DATA__" && `echo $token` == "null" ]]
then
  token=$(curl --request POST -L "${runners_gitlab_url}/api/v4/runners" \
    --form "token=${gitlab_runner_registration_token}" \
    --form "description=${giltab_runner_description}" \
    --form "locked=${gitlab_runner_locked_to_project}" \
    --form "run_untagged=${gitlab_runner_run_untagged}" \
    --form "maximum_timeout=${gitlab_runner_maximum_timeout}" \
    --form "access_level=${gitlab_runner_access_level}" \
    | jq -r .token)
  aws ssm put-parameter --overwrite --type SecureString  --name "${runners_ssm_token_key}" --value $token --region "${ssm_region}"
fi

sed -i.bak s/__REPLACED_BY_USER_DATA__/`echo $token`/g /etc/gitlab-runner/config.toml

service gitlab-runner restart
chkconfig gitlab-runner on

# vim: set ft=sh:
