#!/usr/bin/env bash

set -e

# To test different versions/forks of age-op or age, set environment AGE_OP or AGE, respectively.
# for example, to test that age-op is compatible with 'rage', use `AGE=rage test-age-op`

AGE_OP=${AGE_OP:-$(which age-op)}
AGE=${AGE:-$(which age)}

# vault for testing - this must be a unique vault name used only for testing
# the cleanup at the end of this script deletes all items in this vault
TEST_VAULT=ageop_testing_scratch_vault

# Generate random IDs for vault items
VAULT_ITEM1=$(head -c 8 /dev/random | base64 | tr -d '/+=')
VAULT_KEY1=op://$TEST_VAULT/$VAULT_ITEM1

VAULT_ITEM2=$(head -c 8 /dev/random | base64 | tr -d '/+=')
VAULT_KEY2=op://$TEST_VAULT/$VAULT_ITEM2

# For recipient-based tests - SSH key
VAULT_SSH_ITEM=$(head -c 8 /dev/random | base64 | tr -d '/+=')
VAULT_SSH_PUB_KEY="op://$TEST_VAULT/$VAULT_SSH_ITEM/public key"
VAULT_SSH_PRIV_KEY="op://$TEST_VAULT/$VAULT_SSH_ITEM/private key"

# Create temporary directory for test files
TEST_DIR=$(mktemp -d -t age-test-files.XXXXXX)

# Ensure cleanup happens even if the script fails
cleanup() {
  echo -e "\nCleaning up..."
  echo "Cleaning vault: $TEST_VAULT"
  op item list --vault $TEST_VAULT --format json 2>/dev/null | jq -r '.[] .id' | while read i; do
    op item delete "$i" 2>/dev/null || true
  done
  echo "Cleaning files: $TEST_DIR"
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Print test header
print_header() {
  echo "=================================================="
  echo "$1"
  echo "=================================================="
}

# Print test information
cat <<_START
╔══════════════════════════════════════════════════════╗
║               AGE-OP TEST SUITE                      ║
╚══════════════════════════════════════════════════════╝

Test Starting  : $(date)
AGE_OP         : $AGE_OP
AGE            : $AGE
Vault          : $TEST_VAULT
Test files     : $TEST_DIR
_START

# Generate test data file
file1=$TEST_DIR/file1
head -c 20 /dev/random | base64 > $file1
echo "Test data generated: $file1 ($(wc -c < $file1) bytes)"

# Test result checking functions
check() {
  rc=$1
  shift
  if [ $rc -eq 0 ]; then
    echo "✅ OK   $@"
  else
    echo "❌ FAIL (rc:$rc) $@"
    exit 1
  fi
}

# Expect failure with specific exit code
expect_fail() {
  rc=$1
  expected_rc=$2
  shift 2
  if [ $rc -eq $expected_rc ]; then
    echo "✅ OK   $@ (expected failure with rc:$expected_rc)"
  else
    echo "❌ FAIL $@ (expected rc:$expected_rc, got rc:$rc)"
    exit 1
  fi
}

# Generate test keys
print_header "SETUP: KEY GENERATION"

# Generate age key
key1_path=$TEST_DIR/key1
age-keygen -o "$key1_path" > "$TEST_DIR/key1_gen_out" 2>&1
check $? "age key generation"

# Generate SSH key directly in 1Password for recipient tests
op item create --category="SSH Key" --title="$VAULT_SSH_ITEM" --vault="$TEST_VAULT" --ssh-generate-key="ed25519" >/dev/null
check $? "generate SSH key in 1Password"

# Extract the public key for test verification with age
op read "$VAULT_SSH_PUB_KEY" > "$TEST_DIR/ssh_key.pub"
check $? "extract public key for verification"

# Extract the private key to a temporary file for verification tests
op read "$VAULT_SSH_PRIV_KEY" > "$TEST_DIR/ssh_key"
chmod 600 "$TEST_DIR/ssh_key"
check $? "extract private key for verification"

# SECTION 1: VERIFY AGE WORKS CORRECTLY
print_header "SECTION 1: BASIC AGE FUNCTIONALITY"

file1_enc=$TEST_DIR/file1.enc
age -e -i "$key1_path" <"$file1" > "$file1_enc"
age -d -i "$key1_path" <"$file1_enc" > "$TEST_DIR/dec1"
cmp "$TEST_DIR/dec1" "$file1"
check $? "age enc/dec with direct key file"

# SECTION 2: AGE-OP KEY GENERATION
print_header "SECTION 2: AGE-OP KEY GENERATION"

# Generate keys in 1Password vault
$AGE_OP -n -k "$VAULT_KEY1/password" >"$TEST_DIR/vault_key1_out" 2>&1
check $? "age-op generate key with explicit field"

# Test key generation with default field
$AGE_OP -n -k "$VAULT_KEY2" >"$TEST_DIR/vault_key2_out" 2>&1
check $? "age-op generate key with default field"

# SECTION 3: KEY INTEROPERABILITY
print_header "SECTION 3: KEY INTEROPERABILITY"

# Extract key from 1Password for testing
k1=$(op read "$VAULT_KEY1/password")
vault_key1_copy="$TEST_DIR/vault_key1"
echo "$k1" > "$vault_key1_copy"

# Verify that age-op generated key works with regular age
age -e -i "$vault_key1_copy" <"$file1" > "$TEST_DIR/enc2"
age -d -i "$vault_key1_copy" <"$TEST_DIR/enc2" > "$TEST_DIR/dec2"
cmp "$TEST_DIR/dec2" "$file1"
check $? "age enc/dec with age-op generated key"

# SECTION 4: CORE AGE-OP ENCRYPTION/DECRYPTION (IDENTITY BASED)
print_header "SECTION 4: CORE AGE-OP FUNCTIONALITY"

# Test basic encryption/decryption with identity key
$AGE_OP -e -k "$VAULT_KEY1/password" <"$file1" > "$TEST_DIR/enc3"
$AGE_OP -d -k "$VAULT_KEY1/password" <"$TEST_DIR/enc3" > "$TEST_DIR/dec3"
cmp "$TEST_DIR/dec3" "$file1"
check $? "age-op enc/dec with explicit field"

# Test with default field
$AGE_OP -e -k "$VAULT_KEY1" <"$file1" > "$TEST_DIR/enc4"
$AGE_OP -d -k "$VAULT_KEY1" <"$TEST_DIR/enc4" > "$TEST_DIR/dec4"
cmp "$TEST_DIR/dec4" "$file1"
check $? "age-op enc/dec with default field"

# SECTION 5: CROSS-TOOL INTEROPERABILITY
print_header "SECTION 5: CROSS-TOOL INTEROPERABILITY"

# age-op decrypt file encrypted with age
$AGE_OP -d -k "$VAULT_KEY1" <"$TEST_DIR/enc2" > "$TEST_DIR/dec2-op"
cmp "$TEST_DIR/dec2-op" "$file1"
check $? "age encrypt → age-op decrypt"

# age decrypt file encrypted with age-op
age -d -i "$vault_key1_copy" <"$TEST_DIR/enc3" > "$TEST_DIR/dec3-age"
cmp "$TEST_DIR/dec3-age" "$file1"
check $? "age-op encrypt → age decrypt"

# SECTION 6: I/O OPTIONS
print_header "SECTION 6: I/O OPTIONS"

# Test with FILE parameter
$AGE_OP -e -k "$VAULT_KEY1" "$file1" > "$TEST_DIR/enc5"
$AGE_OP -d -k "$VAULT_KEY1" "$TEST_DIR/enc5" > "$TEST_DIR/dec5"
cmp "$TEST_DIR/dec5" "$file1"
check $? "FILE parameter"

# Test with FILE='-'
$AGE_OP -e -k "$VAULT_KEY1" - <"$file1" > "$TEST_DIR/enc6"
$AGE_OP -d -k "$VAULT_KEY1" - <"$TEST_DIR/enc6" > "$TEST_DIR/dec6"
cmp "$TEST_DIR/dec6" "$file1"
check $? "FILE='-' (stdin/stdout)"

# Test -o OUTPUT, file stdin
$AGE_OP -e -k "$VAULT_KEY1" -o "$TEST_DIR/enc7" <"$file1"
$AGE_OP -d -k "$VAULT_KEY1" -o "$TEST_DIR/dec7" <"$TEST_DIR/enc7"
cmp "$TEST_DIR/dec7" "$file1"
check $? "-o OUTPUT"

# Test -o -, file stdin
$AGE_OP -e -k "$VAULT_KEY1" -o - <"$file1" >"$TEST_DIR/enc8"
$AGE_OP -d -k "$VAULT_KEY1" -o - <"$TEST_DIR/enc8" >"$TEST_DIR/dec8"
cmp "$TEST_DIR/dec8" "$file1"
check $? "-o - (stdout)"

# SECTION 7: ASCII ARMOR
print_header "SECTION 7: ASCII ARMOR"

# Test ASCII armor (-a flag)
$AGE_OP -e -a -k "$VAULT_KEY1" <"$file1" > "$TEST_DIR/enc_armored"
# Check if output contains PEM header
grep -q -- "-----BEGIN AGE ENCRYPTED FILE-----" "$TEST_DIR/enc_armored"
check $? "ASCII armor produces PEM format"

# Decrypt armored file
$AGE_OP -d -k "$VAULT_KEY1" <"$TEST_DIR/enc_armored" > "$TEST_DIR/dec_armored"
cmp "$TEST_DIR/dec_armored" "$file1"
check $? "decrypt armored file"

# SECTION 8: RECIPIENT-BASED ENCRYPTION
print_header "SECTION 8: RECIPIENT-BASED ENCRYPTION"

# Test recipient-based encryption with public key
$AGE_OP -r -k "$VAULT_SSH_PUB_KEY" <"$file1" > "$TEST_DIR/enc_recipient"
check $? "encrypt with recipient (public key)"

# Decrypt with age using private key
age -d -i "$TEST_DIR/ssh_key" <"$TEST_DIR/enc_recipient" > "$TEST_DIR/dec_recipient"
cmp "$TEST_DIR/dec_recipient" "$file1"
check $? "decrypt recipient-encrypted file with SSH private key (age)"

# Decrypt with age-op using private key stored in 1Password
# Skip this test when using rage as it has different SSH key format requirements and op generates one it doesn't like
if [[ "$AGE" != *"rage"* ]]; then
  $AGE_OP -d -k "$VAULT_SSH_PRIV_KEY" <"$TEST_DIR/enc_recipient" > "$TEST_DIR/dec_recipient_op"
  cmp "$TEST_DIR/dec_recipient_op" "$file1"
  check $? "decrypt recipient-encrypted file with 1Password key (age-op)"
else
  echo "⏩ Skipping 1Password SSH key test with rage (different key format requirements)"
fi

# SECTION 9: COMBINED FEATURES
print_header "SECTION 9: COMBINED FEATURES"

# Test recipient-based encryption with ASCII armor
$AGE_OP -r -a -k "$VAULT_SSH_PUB_KEY" <"$file1" > "$TEST_DIR/enc_recipient_armored"
grep -q -- "-----BEGIN AGE ENCRYPTED FILE-----" "$TEST_DIR/enc_recipient_armored"
check $? "recipient with armor produces PEM format"

# Decrypt armored recipient file
age -d -i "$TEST_DIR/ssh_key" <"$TEST_DIR/enc_recipient_armored" > "$TEST_DIR/dec_recipient_armored"
cmp "$TEST_DIR/dec_recipient_armored" "$file1"
check $? "decrypt armored recipient-encrypted file"

# SECTION 10: ERROR HANDLING
print_header "SECTION 10: ERROR HANDLING"

# Test invalid key path
$AGE_OP -e -k "op://nonexistent/key" <"$file1" > "$TEST_DIR/enc_error" 2>/dev/null || ec=$?
expect_fail $ec 1 "invalid key path"

# Test invalid file
$AGE_OP -d -k "$VAULT_KEY1" "nonexistent_file" > "$TEST_DIR/dec_error" 2>/dev/null || ec=$?
expect_fail $ec 1 "invalid input file"

# Test conflict in flags
$AGE_OP -e -d -k "$VAULT_KEY1" <"$file1" > "$TEST_DIR/conflict_error" 2>/dev/null || ec=$?
expect_fail $ec 1 "conflicting flags"

# SECTION 11: HELP COMMANDS
print_header "SECTION 11: HELP FUNCTIONALITY"

# Test help functionality
$AGE_OP -h | grep Examples >/dev/null
check $? "-h invokes help"
$AGE_OP --help | grep Examples >/dev/null
check $? "--help invokes help"
$AGE_OP help | grep Examples >/dev/null
check $? "help invokes help"

# Print test summary
cat <<_END
╔══════════════════════════════════════════════════════╗
║               TEST SUMMARY                           ║
╚══════════════════════════════════════════════════════╝
Test complete  : $(date)
All tests passed successfully! ✅
_END
