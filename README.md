# Simple CLI encryption without the footguns

This [`age-op`](./age-op) bash script combines the awesome [age](https://github.com/FiloSottile/age) cli for encryption and decryption, with 1password for secure key storage.
It can also create age-compatible ed25519 keys and store them in a 1password vault. 
Through the magic of 1password-host integration, it takes advantage of the various conveniences for unlocking the vault: biometrics, touch-id, apple watch (macos), yubi key, etc.

Examples below show encryption and decryption of files and streams (stdin/stdout).
Scripts and documentation are provided showing how to use `age-op` on remote servers, CI pipelines, and edge devices.

## Dependencies:

- [age](https://github.com/FiloSottile/age) or [rage](https://github.com/str4d/rage) (To use rage, set the environment variable `AGE=rage`)
- [1password cli](https://developer.1password.com/docs/cli/) (`op`). See [installation](https://developer.1password.com/docs/cli/get-started#install) instructions for mac, linux, and windows.


## Usage Examples

For help and examples,

```
age-op [ -h | --help ]
```
 

### Encrypt 

Encrypt a file using an identity (private key):

```shell
age-op -e -k KEY_PATH [ -o OUTPUT ] [ -t TMPDIR ] [ -a ] [ FILE ]
```

Encrypt a file using a recipient (public key) - useful for SSH public keys:

```shell
age-op -r -k KEY_PATH [ -o OUTPUT ] [ -t TMPDIR ] [ -a ] [ FILE ]
```
  
Encrypt multiple files and folders:

```shell
tar czf - FILE_OR_DIR [ FILE_OR_DIR ... ] | age-op -e -k KEY_PATH -o foo.tar.gz.age
```

Encrypt database backup:

```shell
pg_dump | age-op -e -k KEY_PATH -o db-snapshot-$(date '+%Y%m%d-%H%M%S').age 
```

### Decrypt

Decrypt a file:

```shell
age-op -d -k KEY_PATH [ -o OUTPUT ] [-t TMPDIR ] [ FILE ]
```
  
Decrypt files and folders:

```shell
age-op -d -k KEY_PATH foo.tar.gz.age | tar xzf -
```

### Generate a key

Generate an age identity key and store it in the 1password vault. The type of the new item will be "Password", and the key is stored in the field named `password`.

```shell
age-op -n -k KEY_PATH
```

## Options

|             | description                                                                                                                                                                                                                                                              |
|:------------|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| -e          | Encrypt using identity (private key)                                                                                                                                                                                                                                     |
| -r          | Encrypt using recipient (public key) - works with SSH public keys                                                                                                                                                                                                        |
| -d          | Decrypt file using identity key                                                                                                                                                                                                                                          |
| -n          | Generate new identity key                                                                                                                                                                                                                                                |
| -a          | Use ASCII armor (PEM format) for encryption output                                                                                                                                                                                                                       |
| -k KEY_PATH | (required) path to key in a 1Password vault, in one of the following formats:<br/>`op://vault/title`<br/>`op://vault/title/field`<br/>`op://vault/title/section/field`<br/>The first variant can be used when the field name is `password`.                              |
| -o OUTPUT   | path to output file. If `-` or if not specified, stdout is used                                                                                                                                                                                                          |
| -t TMPDIR   | TMPDIR is a private folder where keys are briefly stored so they can be read by `age`, then quickly removed.<br/>On linux, the default is `/run/user/USERID`. On macos, the default is `$TMPDIR`. Both of these folders are usually owned by current user with mode 700. |
| FILE        | path to input file. If `-` or if not specified, stdin is used.                                                                                                                                                                                                           |
| -h          | Show help and usage information                                                                                                                                                                                                                                          |


## 1Password access: local and remote

The 1Password cli `op`, used inside `age-op`, can access a 1Password vault in one of three ways - through a locally installed desktop app, as a service account, or via a 1Password Connect Server.
The latter two methods don't require a local app, and are especially useful for headless servers, CI pipelines, and edge devices.


### Local connection to desktop app

The `op` cli should automatically connect to a locally installed app. In some cases, you may need to run 
`eval $(op signin)` to authenticate the current shell.


### Service Account

For service account authentication, `op` uses a token from 
the environment variable `OP_SERVICE_ACCOUNT_TOKEN` . The service account
is configured from the 1Password web UI, where you generate and download tokens.

Although a service account token provides limited access - access is limited to specific approved vaults, and only
until the token expiration date - it's still a secret that needs some protection.
For a CI pipeline, or in AWS or K8s where you can inject environment variables, it's straightforward
to add the token to the environment of the remote process.
If you are connecting to the server via ssh from a trusted host (e.g., your workstation or laptop), you can pass the environment variable
as part of the ssh session, either with the ssh command

```shell
ssh -o SendEnv=OP_SERVICE_ACCOUNT_TOKEN ...
```

or by adding `SendEnv` or `SetEnv` to the ssh client configuration (`~/.ssh/config`)

```
Host some-remote
    # Pass the token from my env
    SendEnv OP_SERVICE_ACCOUNT_TOKEN
    # or, send the value from this config file
    SetEnv OP_SERVICE_ACCOUNT_TOKEN=<TOKEN<>
```

On the remote host, you'll probably need to add a line to `/etc/ssh/sshd_config` to tell the ssh server to accept the environment variable.

```
AcceptEnv OP_SERVICE_ACCOUNT_TOKEN
```

### 1Password Connect Server

A 1Password Connect Server is another method `op` can use to access a vault.
Instead of connecting to the 1Password cloud, it connects to a server that you run on your own infrastructure.  

This method has the additional overhead of starting a server, but there is some additional flexibility.
See [op-connect](./op-connect) in this repository for a docker-compose file, scripts, and additional instructions.

I use this in cases when I ssh from a desktop or laptop that has 1password installed,
and I want to use different encryption keys and access policies for different remote hosts. The connect server runs for the duration of the ssh session,
handling callbacks from the remote apps. The credentials are short-lived
(only as long as the ssh session), fine-tuned to the target, and no keys or tokens are left behind on the remote servers.
 

## Alternatives

Some of the popular alternatives to `age` I considered.

- __openssl__ cli. Although often recommended in blogs and SO, it [has significant flaws and footguns](https://security.stackexchange.com/questions/182277/is-openssl-aes-256-cbc-encryption-safe-for-offsite-backup)

- __gnupg__ (gpg) has so many options [it's easy to make poor choices](https://github.com/FiloSottile/age/discussions/432), and is far from the ideal "secure by default".

- __7zip__ (7z) uses aes-256, but [doesn't retain unix ownership and permissions](https://www.redhat.com/sysadmin/encrypting-decrypting-7zip), so isn't good for archive backups.

- __aescrypt__ - hard to review since the [git repo is out of date](https://github.com/paulej/AESCrypt), even though that's still linked from aescrypt dot com.

- __aws__ encryption cli - requires AWS KMS, and I wanted 1Password

- __veracrypt__, __rclone__, and __restic__: All three of these are well-regarded, and I use them for other use cases, but they are too heavyweight (IMO) for a simple cli for encrypting stdin or a file at a time.

- Writing yet-another tool. Not worth writing another binary.

`age` is broadly used, was written by a smart and thoughtful author, and stands on the shoulders of chacha20-poly1305 (RFC7539), x25519 (RFC 7748), HKDF-SHA-256 (RFC 5869).
The short `age-op` script is easy to review, and doesn't introduce any new encryption algorithms or do anything fancy. 
All files created or read by `age-op` are 100% compatible with `age` and `rage`, so there is no lock-in or risk of incompatibility.


## Future

There may be [reasons](https://github.com/stevelr/age-op/issues/1) for building this as an age plugin, or for taking advantage of future plugins. 


## Testing

A test script is included to verify functionality:

```shell
./test-age-op.sh
```

⚠️ **Warning**: The test script creates and deletes items in a vault named `ageop_testing_scratch_vault`. Use a different vault with:

```shell
TEST_VAULT=my_test_vault ./test-age-op.sh
```

Test with rage instead of age:
```shell
AGE=rage ./test-age-op.sh
```