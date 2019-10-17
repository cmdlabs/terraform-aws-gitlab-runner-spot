#!/usr/bin/env bash

if [ "$(uname -s)" == "Darwin" ] ; then
  if [ ! -x /usr/local/bin/gsed ] ; then
    echo "On Mac OS X you need to install gnu-sed:"
    echo "$ brew install gnu-sed"
    exit 1
  fi

  shopt -s expand_aliases
  alias base64='/usr/local/bin/gbase64'
  alias sed='/usr/local/bin/gsed'
fi

script_under_test='template/user-data.sh.tpl'

aws() {
  case "${FUNCNAME[0]} $*" in

  "aws ssm get-parameters --names $runners_ssm_token_key --with-decryption --region $aws_region")
    echo '{"Parameters":[{"Value":"SECRETTOKEN"}]}' ;;

  "aws ssm put-parameter --overwrite --type SecureString --name $runners_ssm_token_key --value $token --region $aws_region")
    echo '{"Version":"1"}' ;;

  esac
}

setUp() {
  . "$script_under_test"
}

testConfigureCloudwatch() {
  curl() { echo '{"instanceId":"i-11111111","region":"ap-southeast-2"}' ; }

  service() { : ; }
  chkconfig() { : ; }

  awslogs_conf='./test_awslogs.conf'
  awscli_conf='./test_awscli.conf'

  cat > "$awscli_conf" <<EOF
foo bar foo bar
region = us-east-1
baz qux baz qux
EOF

  configure_cloudwatch

  assertTrue "$awslogs_conf does not contain instance_id" "grep -q i-11111111 $awslogs_conf"
  assertTrue "$awscli_conf does not contain region" "grep -q ap-southeast-2 $awscli_conf"

  rm -f "$awslogs_conf" "$awscli_conf"
}

testRegisterRunner() {
  curl() { echo '{"token":"ANOTHERSECRETTOKEN"}' ; }

  config_toml='./test_config.toml'

  cat > "$config_toml" <<EOF
foo bar foo bar
this line has ##TOKEN## in it
baz qux baz qux
EOF

  runners_ssm_token_key='/mykey'
  aws_region='ap-southeast-2'
  runners_url='https://gitlab.com'
  gitlab_runner_registration_token='XXXXXXXX'
  gitlab_runner_description='my runner'
  gitlab_runner_locked_to_project='true'
  gitlab_runner_maximum_timeout='10'
  gitlab_runner_access_level='debug'

  register_runner

  assertTrue "$config_toml does not have secret token in it" "grep -q SECRETTOKEN $config_toml"

  rm -f "$config_toml"
}

. shunit2
