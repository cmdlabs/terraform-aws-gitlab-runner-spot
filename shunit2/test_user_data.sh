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
  echo "${FUNCNAME[0]} $*" >> commands_log
  case "${FUNCNAME[0]} $*" in
  "aws ssm get-parameters --names $runners_ssm_token_key --with-decryption --region $ssm_region")
    echo '{"Parameters":[{"Value":"SECRETTOKEN"}]}' ;;
  *)
    echo "No response for >>> ${FUNCNAME[0]} $*" >> unknown_commands
    echo "FAIL" ;;
  esac
}

curl() {
  echo "${FUNCNAME[0]} $*" >> commands_log
  case "${FUNCNAME[0]} $*" in
  "curl -s https://169.254.169.254/latest/dynamic/instance-identity/document")
    echo '{"instanceId":"i-11111111","region":"ap-southeast-2"}' ;;
  "curl -X POST -L $runners_gitlab_url/api/v4/runners -F token=$gitlab_runner_registration_token -F description=$giltab_runner_description -F locked=$gitlab_runner_locked_to_project -F run_untagged=$gitlab_runner_run_untagged -F maximum_timeout=$gitlab_runner_maximum_timeout -F access_level=$gitlab_runner_access_level")
    echo '{"token":"ANOTHERSECRETTOKEN"}' ;;
  *)
    echo "No response for >>> ${FUNCNAME[0]} $*" >> unknown_commands
    echo "FAIL" ;;
  esac
}

setUp() {
  . "$script_under_test"
}

testConfigureCloudwatch() {
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
  config_toml='./test_config.toml'

  cat > "$config_toml" <<EOF
foo bar foo bar
this line has ##TOKEN## in it
baz qux baz qux
EOF

  runners_ssm_token_key='/mykey'
  ssm_region='ap-southeast-2'
  runners_gitlab_url='https://gitlab.com'
  gitlab_runner_registration_token='XXXXXXXX'
  giltab_runner_description='my runner'
  gitlab_runner_locked_to_project='true'
  gitlab_runner_run_untagged='true'
  gitlab_runner_maximum_timeout='10'
  gitlab_runner_access_level='debug'

  register_runner

  assertTrue "$config_toml does not have secret token in it" "grep -q SECRETTOKEN $config_toml"

  rm -f "$config_toml"
}

testUnknownCommands() {
  # Tells us if we forgot to capture responses for any AWS commands issued.
  true > expected_log
  touch unknown_commands
  assertEquals "unknown AWS commands issued somewhere" "" "$(diff -wu expected_log unknown_commands)"
}

tearDown() {
  rm -f commands_log expected_log
}

oneTimeTearDown() {
  rm -f unknown_commands
}

. shunit2
