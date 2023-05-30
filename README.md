# Simple CLI encryption without the footguns

This [`age-op`](./age-op) bash script combines the awesome [age](https://github.com/FiloSottile/age) cli for encryption and decryption, with 1password for secure key storage.
It can also create age-compatible ed25519 keys and store them in a 1password vault. 
Through the magic of 1password-host integration, it works with the various conveniences for unlocking the vault: biometrics, touch-id, apple watch (macos), yubi key, etc.

The optional scripts in [op-connect](./op-connect) make it easier to use `age-op` on remote servers (over ssh) that may not have a 1Password app installed.

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

You can use `age-op` on a remote server, or CI pipeline. 
The remote server needs to have the `op` cli and `age-op` installed. The two most common ways to authorize that machine are with a service account token, or with credentials to access a Connect Server.

### Service Account

A [service account](https://developer.1password.com/docs/service-accounts) is easy to create on the 1Password web interface,
and requires only one environment variable, `OP_SERVICE_ACCOUNT_TOKEN`. The token limits access to specific vaults, 
and has an expiration date. This is useful for automated CI, or cloud services like AWS or K8s where you can inject environment variables.
  
If you want to pass the token during an interactive ssh session, you can do one of the following:

  - when connecting to the remote server, use `ssh -o SendEnv=OP_SERVICE_ACCOUNT_TOKEN ...`.
  - Or, add ```SendEnv OP_SERVICE_ACCOUNT_TOKEN``` or ```SetEnv OP_SERVICE_ACCOUNT_TOKEN=....``` (depending on whether you want to pass the variable from your current environment, or store it in the config file) to the `.ssh/config` configuration for that host. 

You may need to add `AcceptEnv OP_SERVICE_ACCOUNT_TOKEN` to the `/etc/ssh/sshd_config` on the remote server.
 
### 1Password Connect Server

This may be more flexible than the service account approach, but has the overhead of needing to run a server (docker-compose file provided).
I use this in cases when I ssh from a primary workstation (or laptop) that has 1password installed,
and I want to use different credentials and encryption keys for different remote hosts. For the duration of the ssh session,
a local connect server handles callbacks so remote apps can get encryption keys. The credentials are short-lived
(only as long as the ssh session), fine-tuned to the target, and no keys or tokens are left behind on the remote servers.
 
See [op-connect](./op-connect) for instructions and scripts.


## Alternatives

Some of the popular alternatives to `age` I considered.

- openssl cli. Often recommended in blogs and SO, but [has significant flaws and footguns](https://security.stackexchange.com/questions/182277/is-openssl-aes-256-cbc-encryption-safe-for-offsite-backup)

- gnupg (gpg) is [less foolproof](https://github.com/FiloSottile/age/discussions/432)

- 7zip (7z) uses aes-256, but [doesn't retain unix owners and permissions](https://www.redhat.com/sysadmin/encrypting-decrypting-7zip)

- aescrypt - hard to review since the [git repo is out of date](https://github.com/paulej/AESCrypt), even though that's still linked from aescrypt dot com.

- aws encryption cli - requires AWS KMS, and I wanted 1Password

- [veracrypt](https://github.com/veracrypt/VeraCrypt), [rclone](https://github.com/rclone/rclone), [restic](https://github.com/restic/restic) 
  All three of these are well-regarded, and I used them for other use cases, but they are too heavywight (IMO) for a simple cli for encrypting stdin or a file at a time.

- Writing yet-another tool. Not worth writing another binary.

`age` is broadly used, was written by a smart and thoughtful author, and stands on the shoulders of chacha20-poly1305 (RFC7539), x25519 (RFC 7748), HKDF-SHA-256 (RFC 5869).
The short `age-op` script is easy to review, and doesn't introduce any new encryption algorithms or do anything fancy. It's a small amount
of code necessary to connect it to 1password.
All files created or read by `age-op` are 100% compatible with `age` and `rage`, so there is no lock-in or risk of incompatibility.

## Future

There may be [reasons](https://github.com/stevelr/age-op/issues/1) for building this as a plugin, or for taking advantage of future plugins. 

