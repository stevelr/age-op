#!/bin/bash

token_name="$1"
creds=${2:-./1password-credentials.json}

docker-compose rm -sf 2>/dev/null
unset OP_CONNECT_HOST
unset OP_CONNECT_TOKEN
for svr in $(op connect server list --format json | jq -r '.[] .id'); do
   op connect server rm "$svr"
done
rm -f "$creds" "token-${token_name}.env"

