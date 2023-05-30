# Simple CLI encryption without the footguns

This `age-op` bash script combines the awesome [age](https://github.com/FiloSottile/age) cli for encryption and decryption, with 1password for secure key storage.
It can also create age-compatible ed25519 keys and store them in 1password vault. 
Through the magic of 1password-host integration, it works with the various conveniences for unlocking the vault: biometrics, touch-id, apple watch (macos), yubi key, etc.

The optional scripts in [op-connect](./op-connect) make it easier to use `age-op` on remote server (over ssh) that may not have a 1Password app installed.

Works in streaming modes (encrypting/decrypting from stdin or to stdout).

## Dependencies:

- [age](https://github.com/FiloSottile/age) or [rage](https://github.com/str4d/rage) (To use rage, set the environment variable `AGE=rage`)
- [1password cli](https://developer.1password.com/docs/cli/) (`op`). See [installation](https://developer.1password.com/docs/cli/get-started#install) instructions for mac, linux, and windows.


## Usage Examples

For help and examples,

```
age-op [-h | --help]
```
 

### Encrypt 

Encrypt a single file

```shell
age-op -e -k KEY_PATH [ -o OUTPUT ] [ -t TMPDIR ] [ FILE ]
    If FILE is '-' or not specified, stdin is encrypted
    If OUTPUT is '-' or not specified, the output is sent to stdout
```
  
Encrypt one or more files or folders to a tar file

```shell
tar czf - FILE_OR_DIR [ FILE_OR_DIR ... ] | age-op -e -k KEY_PATH -o foo.tar.gz.age
```

### Decrypt

Decrypt a file

```shell
age-op -d -k KEY_PATH [ -o OUTPUT ] [-t TMPDIR ] [ FILE ]
    If FILE is '-' or not specified, stdin is decrypted
    If OUTPUT is '-' or not specified, the output is sent to stdout
```
  
Decrypt a tar file

```shell
age-op -d -k KEY_PATH foo.tar.gz.age | tar xzf -
```

### Generate a key

Generate an age ed25519 key and store it in the 1password vault. The type of the new item will be "Password"

```shell
age-op -n -k KEY_PATH
```

## Options

**`KEY_PATH`** 

`age-op` works with any type of 1password item (Password, Login, etc.), as long as one of the fields contains an age-compatible key.
For simplicity, these examples generate and use items of type "Password", which conventionally use the field name `password` for the secret.

When using the defaults, the KEY_PATH can be specified as `op://vault/title`, and the field name `password` will be filled in.

KEY_PATH can also be of the form  `op://vault/title/field` or `op://vault/title/section/field`


**`TMPDIR`** 

TMPDIR is the temporary folder where key will be briefly written and quickly removed.
On linux, the default is `/run/user/USERID`. On macos, the default is `$TMPDIR`
Both of these folders are usually owned by current user with mode 700.
  
**1Password configuration**

The 1Password cli connects with the 1Password app if it's installed on your local machine.
If it doesn't connect, or if a 1Password is not installed, you can authenticate to the `op` cli with one of the following methods:
  - signing in with `eval $(op signin)`
  - For use with a service account, set the environment variable `OP_SERVICE_ACCOUNT_TOKEN`
  - For use with a 1Password Connect Server, set `OP_CONNECT_HOST` and `OP_CONNECT_TOKEN`


## Using on remote servers

You can use `age-op` on a remote server, for example to make encrypted backups and send them to s3. The remote server needs to have the `op` cli and `age-op` installed.

Case 1: With 1Password Connect Server

- see [op-connect](./op-connect) for instructions


Case 2: With a [service account](https://developer.1password.com/docs/service-accounts) and service token

- The remote process must have `OP_SERVICE_ACCOUNT_TOKEN` set (you can create this manually in the 1password web interface). If you don't want to store this on the remote server, you can set it in a local environment,
  do one of the following:
  - when connecting to the remote server, use `ssh -o SendEnv=OP_SERVICE_ACCOUNT_TOKEN ...`
  - add ```SendEnv OP_SERVICE_ACCOUNT_TOKEN``` or ```SetEnv OP_SERVICE_ACCOUNT_TOKEN=....``` to the `.ssh/config` configuration for that host. 

You may need to add `AcceptEnv OP_SERVICE_ACCOUNT_TOKEN` to the `/etc/ssh/sshd_config` on the remote server.
 
