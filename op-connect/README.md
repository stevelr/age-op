# Encryption on remote server

The 1Password [Connect Server](https://developer.1password.com/docs/connect) 
makes it easy to use `op` and [`age-op`](https://github.com/stevelr/age-op) 
on a remote server. The scripts here make it somewhat easier to use.

Run `start-connect-server -t TOKEN_NAME` and follow the instructions.
TOKEN_NAME is any name for this purpose, such as "prod backup key".

The [`start-connect-server`](./start-connect-server) script starts docker containers with the 1p connect server,
and generates a token-\*.env script. (the actual file name is printed by start-connect-server).

After sourcing token-*.env, your bash or zsh environment contains these variables:
    `OP_CONNECT_HOST`
    `OP_CONNECT_TOKEN`
and these aliases:
    `ssh-with-token`
    `stop-server`

The env variables are used by the 1Password cli `op` and [`age-op`](https://github.com/stevelr/age-op) (which uses `op`).
The alias `ssh-with-token` passes these vars to a remote shell,
so you can have temporary access to a 1Password vault even if the remote server
is headless doesn't have 1password app installed. (the `op` cli is needed, though)
The protocol for connecting back uses http:, not https:. The network is assumed to be trusted.

A remote ssh server needs some configuration to make this work:
1. install the `op` cli program, and install [`age-op`](https://github.com/stecelr/age-op) if needed
2. Add the following line to the remote server's /etc/ssh/sshd_config:

```
AcceptEnv OP_CONNECT_HOST OP_CONNECT_TOKEN
```

and reload the sshd server's config with: `sudo systemctl -s HUP kill sshd`


When you no longer need the environment and server, type

```
stop-server
```

This will stop the server and delete the temporary credentials.

This docker-compose.yml file creates a docker volume `op-connect_op-cred-cache`
containing an encrypted cache. It's safe to delete between runs,
but keeping it around may improve startup time depending on the size of vaults used.

