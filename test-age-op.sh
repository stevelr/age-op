#!/usr/bin/env bash

set -e

# To test different versions/forks of age-op or age, set environment AGE_OP or AGE, respectively.
# for example, to test that age-op is compatible with 'rage', use `AGE=rage test-age-op`

AGE_OP=${AGE_OP:-$(which age-op)}

# vault for testing - this must be a unique vault name used only for testing
# the cleanup at the end of this script deletes all items in this vault
TEST_VAULT=ageop_testing_scratch_vault

VAULT_ITEM1=$(head -c 8 /dev/random | base64 | tr -d '/+=')
VAULT_KEY1=op://$TEST_VAULT/$VAULT_ITEM1

VAULT_ITEM2=$(head -c 8 /dev/random | base64 | tr -d '/+=')
VAULT_KEY2=op://$TEST_VAULT/$VAULT_ITEM2

TEST_DIR=$(mktemp -d -t age-test-files.XXXXXX)

cat <<_START
Test Starting  : $(date)
AGE_OP         : $AGE_OP
AGE            : ${AGE:-$(which age)}
Vault          : $TEST_VAULT
Test files     : $TEST_DIR
_START


# generate random data
file1=$TEST_DIR/file1
head -c 20 /dev/random | base64 > $file1

check() {
  rc=$1
  shift
  if [ $rc -eq 0 ]; then
    echo "OK   $@"
  else
    echo "FAIL (rc:$rc) $@"
    exit 1
  fi
}

key1_path=$TEST_DIR/key1
age-keygen -o "$key1_path" > "$TEST_DIR/key1_gen_out" 2>&1
check $? age key generation


# basic sanity check with 'age'

file1_enc=$TEST_DIR/file1.enc

age -e -i "$key1_path" <"$file1"     > "$file1_enc"
age -d -i "$key1_path" <"$file1_enc" > "$TEST_DIR/dec1"
cmp "$TEST_DIR/dec1" "$file1"
check $? age enc1/dec1 with key1

# age-op key generate

$AGE_OP -n -k "$VAULT_KEY1/password" >"$TEST_DIR/vault_key1_out" 2>&1
check $? age-op generate VAULT_KEY1

# should work with or without /password
$AGE_OP -n -k "$VAULT_KEY2" >"$TEST_DIR/vault_key2_out" 2>&1
check $? age-op generate VAULT_KEY2

k1=$(op read "$VAULT_KEY1/password")

# verify that age-op key is compatible with age
vault_key1_copy="$TEST_DIR/vault_key1"
cat >"$vault_key1_copy" <<_EOF
$k1
_EOF

age -e -i "$vault_key1_copy" <"$file1" > "$TEST_DIR/enc2"
age -d -i "$vault_key1_copy" <"$TEST_DIR/enc2" > "$TEST_DIR/dec2"
cmp "$TEST_DIR/dec2" "$file1"
check $? age enc2/dec2 with vault_key1_copy

# now use the key with age-op

$AGE_OP -e -k "$VAULT_KEY1/password" <"$file1" > "$TEST_DIR/enc3"
$AGE_OP -d -k "$VAULT_KEY1/password" <"$TEST_DIR/enc3" > "$TEST_DIR/dec3"
cmp "$TEST_DIR/dec3" "$file1"
check $? age-op enc3/dec3 with VAULT_KEY1/password

# check interoperability (1)
# age-op decrypt file encrypted with age
$AGE_OP -d -k "$VAULT_KEY1" <"$TEST_DIR/enc2" > "$TEST_DIR/dec2-op"
cmp "$TEST_DIR/dec2-op" "$file1"
check $? interop age enc age-op dec

# interoperability (2)
# age decrypt file encrypted with age-op
age -d -i "$vault_key1_copy" <"$TEST_DIR/enc3" > "$TEST_DIR/dec3-age"
cmp "$TEST_DIR/dec3-age" "$file1"
check $? interop age-op enc age dec

# optional field in key path
$AGE_OP -e -k "$VAULT_KEY1" <"$file1" > "$TEST_DIR/enc4"
$AGE_OP -d -k "$VAULT_KEY1" <"$TEST_DIR/enc4" > "$TEST_DIR/dec4"
cmp "$TEST_DIR/dec4" "$file1"
check $? age-op enc4/dec4 with VAULT_KEY1

# use FILE input instead of stdin
$AGE_OP -e -k "$VAULT_KEY1" "$file1" > "$TEST_DIR/enc5"
$AGE_OP -d -k "$VAULT_KEY1" "$TEST_DIR/enc5" > "$TEST_DIR/dec5"
cmp "$TEST_DIR/dec5" "$file1"
check $? age-op enc4/dec4 with VAULT_KEY1, FILE param

# use FILE=-
$AGE_OP -e -k "$VAULT_KEY1" - <"$file1" > "$TEST_DIR/enc6"
$AGE_OP -d -k "$VAULT_KEY1" - <"$TEST_DIR/enc6" > "$TEST_DIR/dec6"
cmp "$TEST_DIR/dec6" "$file1"
check $? age-op enc6/dec6 with VAULT_KEY1, FILE '-'

# use -o OUTPUT, file stdin
$AGE_OP -e -k "$VAULT_KEY1" -o "$TEST_DIR/enc7" <"$file1"
$AGE_OP -d -k "$VAULT_KEY1" -o "$TEST_DIR/dec7" <"$TEST_DIR/enc7"
cmp "$TEST_DIR/dec7" "$file1"
check $? age-op enc7/dec7 with VAULT_KEY1, -o OUTPUT, file stdin

# use -o -, file stdin
$AGE_OP -e -k "$VAULT_KEY1" -o - <"$file1" >"$TEST_DIR/enc8"
$AGE_OP -d -k "$VAULT_KEY1" -o - <"$TEST_DIR/enc8" >"$TEST_DIR/dec8"
cmp "$TEST_DIR/dec8" "$file1"
check $? age-op enc8/dec8 with VAULT_KEY1, -o -, file stdin

# help arg
$AGE_OP -h | grep Examples >/dev/null
check $? age-op -h invokes help
$AGE_OP --help | grep Examples >/dev/null
check $? age-op --help invokes help
$AGE_OP help | grep Examples >/dev/null
check $? age-op help invokes help

# if all succeeded, clean up
cat <<_CLEAN1
Cleaning vault : $TEST_VAULT
_CLEAN1
for i in $(op item list --vault $TEST_VAULT --format json | jq -r '.[] .id'); do
  op item delete "$i"
done

# remove folder
cat <<_CLEAN2
Cleaning files : $TEST_DIR
_CLEAN2
rm -rf "$TEST_DIR"

cat <<_END
Test complete  : $(date)
_END
