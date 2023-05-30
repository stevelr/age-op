#!/bin/bash
#
# Start 1Password connect server, and create transient credentials
#   Credentials limit access to specific vault
#
# See README.md for setup instructions and more information

server=$(hostname -f)
port=8080
vault=${VAULT:-$OP_VAULT}
token_name=""
account=""
session_creds=./1password-credentials.json
# expire time for token (end in s(seconds), m(minutes), or h(hours)
duration=30m

_help () {

  [ -n "$1" ] && echo Error: "$@"
  
  cat <<_HELP

$0 [flags]  : Start 1password connect server
  
flags:
   -t token        Name of token. Required  (example: "prod backup key")
   -v vault        Vault name (default $vault)
   -s server       Server name (default $server)
   -p port         Server port (default $port)
   -d duration     Token expiration (default $duration). Number followed by s(seconds),m(minutes), or h(hours)
   -a account      1Password account (only needed if using non-default account)

_HELP
}

while getopts ':ht:a:v:s:p:d:' OPTION; do
  case $OPTION in
    h) _help && exit 0;;
    t) token_name="$OPTARG" ;;
    a) account="$OPTARG" ;;
    v) vault="$OPTARG" ;;
    s) server=$OPTARG ;;
    p) port=$OPTARG ;;
    d) duration=$OPTARG ;;
    ?) _help invalid argument && exit 1;;
  esac
done
shift "$(($OPTIND -1))"

[ $# -ne 0 ] && _help Unrecognized args: "$@" && exit 1
[ -z "$token_name" ] && _help missing token && exit 1

./reset.sh "$token_name" "$session_creds"
unset OP_CONNECT_HOST OP_CONNECT_TOKEN

if [ ! -z "$account" ]; then
    ACCOUNT_ARG="--account=$account"
    account_set_env="export OP_ACCOUNT=\"$account\""
fi
if [ ! -f "$session_creds" ]; then
    op connect server create "$server" --vaults "$vault" --format json $ACCOUNT_ARG
fi
token=$(op connect token create "$token_name" --expires-in "$duration" --server "$server" --vaults "$vault" $ACCOUNT_ARG)

cat <<__ENV > "token-$token_name.env"
export OP_CONNECT_HOST="http://$server:$port"
export OP_CONNECT_TOKEN=$token
$account_set_env
alias stop-server="./reset.sh "$token_name" "$session_creds" && unset OP_CONNECT_HOST OP_CONNECT_TOKEN"
alias ssh-with-token="ssh -o SendEnv=OP_CONNECT_HOST -o SendEnv=OP_CONNECT_TOKEN"
__ENV


docker-compose up -d

# make the server sync
# the first api call always fails with a Bearer Token error.
# but it forces the esrver to sync settings and after that it works.
OP_CONNECT_HOST="http://$server:$port" OP_CONNECT_TOKEN=$token op read "op://$vault/_dummy/_dummy" $ACCOUNT_ARG >/dev/null 2>&1

cat <<__DOC

Started connect server

Created token
    name:     $token_name
    vault:    $vault
    server:   $server
    duration: $duration
    connect:  http://$server:$port
    account:  ${account:-(default)}

Complete the following steps:
    # add the token to your environment and create aliases
    source "./token-$token_name.env"
    # ssh to remote server using 'ssh-with-token' in place of 'ssh'
    ssh-with-token remote
    # stop the server
    stop-server
__DOC


