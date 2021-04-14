#!/bin/bash

if [[ "$1" == prod-* ]] ; then
  echo -e >&2 "\x1B[96mLogging in to the Prod security account.\x1B[39m"
  pass_prefix='prod/security'
else
  echo -e >&2 "\x1B[96mLogging in to the security account.\x1B[39m"
  pass_prefix='security'
fi

AWS_ACCESS_KEY_ID="$(pass $pass_prefix/aws_access_key_id)"
export AWS_ACCESS_KEY_ID

AWS_SECRET_ACCESS_KEY="$(pass $pass_prefix/aws_secret_access_key)"
export AWS_SECRET_ACCESS_KEY

unset AWS_SESSION_TOKEN

echo >&2 "Using access key ID $AWS_ACCESS_KEY_ID to get a temporary session token."

session_token_response=$(aws sts get-session-token \
  --serial-number "$(pass $pass_prefix/aws_mfa_device)" \
  --token-code "$(oathtool --totp=sha1 --base32 "$(pass $pass_prefix/aws_mfa_secret)")" 2>&1)

if [ "${session_token_response/\"SessionToken\"\:}" = "$session_token_response" ] ; then
  # Things were failing for reasons other than invalid auth and not being caught by the string match.
  # Inverted the logic to look for a success condition instead.
  echo -e >&2 "\x1B[31mInitial authentication failed with error:\x1B[39m$session_token_response"
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_SESSION_TOKEN
  exit 1
else
  echo -e >&2 "\x1B[32mInitial authentication succeeded.\x1B[39m"
fi

AWS_ACCESS_KEY_ID="$(echo "$session_token_response" | jq '.Credentials.AccessKeyId' | cut -f2 -d\" )"
export AWS_ACCESS_KEY_ID

echo >&2 "Switching to use temporary access key ID $AWS_ACCESS_KEY_ID"

AWS_SECRET_ACCESS_KEY="$(echo "$session_token_response" | jq '.Credentials.SecretAccessKey' | cut -f2 -d\" )"
export AWS_SECRET_ACCESS_KEY

AWS_SESSION_TOKEN="$(echo "$session_token_response" | jq '.Credentials.SessionToken' | cut -f2 -d\" )"
export AWS_SESSION_TOKEN
