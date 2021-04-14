#!/bin/bash

if hash aws 2>/dev/null; then
  # AWS CLI is installed.
  true
else
  # AWS CLI is not installed, warn and exit.
  echo >&2 "The 'aws' command was not found."
  echo >&2 "You may need to install the AWS command line tools: pip3 install awscli"
  echo >&2 "If you already have it installed, make sure the python package is in your \$PATH."
  exit 1
fi

get_realpath() {
  local TARGET="${1}"
  if [ -n "$(command -v realpath)" ] ; then
    TARGET=$(realpath "${1}")
  fi

  (cd "$(dirname "${TARGET}")" || exit 1; pwd)
}

BASE_DIRECTORY="$(get_realpath "$0")"
AWS_LOGIN="${BASE_DIRECTORY}/awscli-login.sh"

# shellcheck source=/dev/null
if [ -f "${AWS_LOGIN}" ] ; then
  source "${AWS_LOGIN}" "$*"
else
  echo >&2 "Could not find awscli-login.sh at ${AWS_LOGIN}"
  exit 1
fi

is_prod='false'
is_elevated='false'

case $1 in
  prod)
    accountId="123456789101"
    is_prod='true'
    ;;
  dev)
    accountId="110987654321"
    ;;
  *)
    accountId="$1"
    ;;
esac

case $2 in
  dev)
    role_name="allow-dev-access-from-other-accounts"
    is_elevated='true'
    ;;
  full)
    role_name="allow-full-access-from-other-accounts"
    is_elevated='true'
    ;;
  req-vpn)
    role_name="openvpn-allow-certificate-requests-for-external-accounts"
    ;;
  rev-vpn)
    role_name="openvpn-allow-certificate-revocations-for-external-accounts"
    ;;
  read)
    role_name="allow-read-only-access-from-other-accounts"
    ;;
  *)
    echo >&2 "Invalid access type argument specified. Must be one of 'dev', 'full', 'req-vpn', 'rev-vpn', 'read'"
    exit 1
    ;;
esac

role_arn="arn:aws:iam::$accountId:role/$role_name"

echo -e >&2 "Assuming role \x1B[95m$role_arn\x1B[39m"

assume_role_response=$(aws sts assume-role --role-arn "$role_arn" --role-session-name "$USER" --output "json" 2>&1)

if [ "${assume_role_response/error}" = "$assume_role_response" ] ; then
  echo -e >&2 "\x1B[32mAssume IAM role succeeded.\x1B[39m"
else
  echo -e >&2 "\x1B[31mAssuming IAM role failed with error:\x1B[39m$assume_role_response"
  echo unset AWS_ACCESS_KEY_ID\;
  echo unset AWS_SECRET_ACCESS_KEY\;
  echo unset AWS_SESSION_TOKEN\;
  exit 1
fi

echo export AWS_ACCESS_KEY_ID="$(echo "$assume_role_response" | jq '.Credentials.AccessKeyId' | cut -f2 -d\" )"\;

echo >&2 "Set final temporary AWS_ACCESS_KEY_ID and associated secret key and session token"

echo export AWS_SECRET_ACCESS_KEY="$(echo "$assume_role_response" | jq '.Credentials.SecretAccessKey' | cut -f2 -d\" )"\;
echo export AWS_SESSION_TOKEN="$(echo "$assume_role_response" | jq '.Credentials.SessionToken' | cut -f2 -d\" )"\;
echo export AWS_SESSION_EXPIRATION="$(echo "$assume_role_response" | jq '.Credentials.Expiration' | cut -f2 -d\" )"\;

if [ "$is_prod" = "true" ] && [ "$is_elevated" = "true" ] ; then
  echo -e >&2 ""
  echo -e >&2 "\x1B[41m\x1B[1m\x1B[97m ⚠️  You are logged into a PRODUCTION account with elevated privileges. Please be careful!️\x1B[0m"
  echo -e >&2 ""
  if type -a set_color_mode_elevated >&/dev/null; then
    echo 'set_color_mode_elevated;'
  fi
else
  if type -a set_color_mode_normal >&/dev/null; then
    echo 'set_color_mode_normal;'
  fi
fi
