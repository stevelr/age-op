# Encryption on remote server

The 1Password [Connect Server](https://developer.1password.com/docs/connect) 
makes it easy to use [`age-op`](https://github.com/stevelr/age-op) 
on a remote server - even if the remote server doesn't have a 1Password desktop app installed.

Here are some scripts and instructions for using `age-op` on a remote server over ssh.

## Setup

On the remote host, install `age-op`, `age`, and `op`. 

Add the following line to the remote server's `/etc/ssh/sshd_config`
 
```text
AcceptEnv OP_CONNECT_HOST OP_CONNECT_TOKEN
```
and reload the sshd server's config with: `sudo systemctl -s HUP kill sshd`


## Run

Pick a name for the token (`TOKEN_NAME`) and start the connect server on your local machine.

```shell
./start-connect-server.sh -t TOKEN_NAME
```

The above script also generates an environment script using the provided token name. Source it

```shell
source token-TOKEN_NAME.env
```

That script adds two variables to your environment, `OP_CONNECT_HOST` and `OP_CONNECT_TOKEN`, and defines two aliases,
`ssh-with-token` and `stop-server`.

Connect to the server using `ssh-with-token` instead of `ssh`. That alias forwards the two `OP_*` environment variables to the remote server.

```shell
ssh-with-token remote
```

Then, run `age-op` as needed.
```
# For example, take a database backup, encrypt it, and save it on S3
FNAME=db-backup-$(date '+%Y%m%d-%H%M%S').age
pg_dump | age-op -e -k op://vault/DbBackup -o $FNAME
aws s3 cp $FNAME s3://mybucket/$FNAME
```

After you exit the ssh session, use this command to stop the connect server and delete the credentials.

```shell
stop-server
```

## Other notes

### Enabling TLS

The simple configuration described above assumes the network is trusted, and `op` 
uses unencrypted http protocol to call back to the connect server to get the key. For tighter
network security, you can [configure the Connect Server](https://developer.1password.com/docs/connect/connect-server-configuration)
to use TLS, install TLS keys, and use an `https:` scheme in `OP_CONNECT_HOST`.

### Encrypted Cache

This docker-compose.yml file uses a docker volume
to store an encrypted cache. It's safe to delete between runs,
but keeping it around may improve startup time depending on the size of vaults used.

