#!/usr/bin/env bats
# shellcheck disable=SC2317

load ../cidoer.core.sh
load ../cidoer.ssh.sh

setup() {
  TEST_SSH_KEY_DIR="$(mktemp -d)"
  export TEST_SSH_KEY_DIR
  export TEST_SSH_KEY_PASSPHRASE='test+pass'
}

teardown() {
  rm -rf "${TEST_SSH_KEY_DIR:?}"
}

@test "do_ssh_add_key_file with ED25519 key" {
  ssh-keygen -q -t ed25519 -f "$TEST_SSH_KEY_DIR/id_ed25519" -N "$TEST_SSH_KEY_PASSPHRASE"
  run ls "$TEST_SSH_KEY_DIR/id_ed25519"
  [ "$status" -eq 0 ]
  run do_ssh_add_key_file "$TEST_SSH_KEY_DIR/id_ed25519" 'TEST_SSH_KEY_PASSPHRASE'
  [ "$status" -eq 0 ]
}

@test "do_ssh_add_key_file with ED25519 key (no passphrase)" {
  ssh-keygen -q -t ed25519 -f "$TEST_SSH_KEY_DIR/id_ed25519_unsafe" -N ""
  run do_ssh_add_key_file "$TEST_SSH_KEY_DIR/id_ed25519_unsafe"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Warn: Key with passphrase is recommended."* ]]
}

@test "do_ssh_add_key_file with ECDSA key" {
  ssh-keygen -q -t ecdsa -b 521 -f "$TEST_SSH_KEY_DIR/id_ecdsa" -N "$TEST_SSH_KEY_PASSPHRASE"
  run ls "$TEST_SSH_KEY_DIR/id_ecdsa"
  [ "$status" -eq 0 ]
  run do_ssh_add_key_file "$TEST_SSH_KEY_DIR/id_ecdsa" 'TEST_SSH_KEY_PASSPHRASE'
  [ "$status" -eq 0 ]
}

@test "do_ssh_add_key_file with ECDSA key (no passphrase)" {
  ssh-keygen -q -t ecdsa -b 521 -f "$TEST_SSH_KEY_DIR/id_ecdsa_unsafe" -N ""
  run do_ssh_add_key_file "$TEST_SSH_KEY_DIR/id_ecdsa_unsafe"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Warn: Key with passphrase is recommended."* ]]
}

@test "do_ssh_add_key_file with RSA key" {
  ssh-keygen -q -t rsa -b 3072 -f "$TEST_SSH_KEY_DIR/id_rsa" -N "$TEST_SSH_KEY_PASSPHRASE"
  run ls "$TEST_SSH_KEY_DIR/id_rsa"
  [ "$status" -eq 0 ]
  run do_ssh_add_key_file "$TEST_SSH_KEY_DIR/id_rsa" 'TEST_SSH_KEY_PASSPHRASE'
  [ "$status" -eq 0 ]
}

@test "do_ssh_add_key_file interactively" {
  if ! command -v expect >/dev/null 2>&1; then
    skip "Command 'expect' is not installed, skipping test."
  fi
  local path="$TEST_SSH_KEY_DIR/id_ed25519"
  ssh-keygen -q -t ed25519 -f "$path" -N "$TEST_SSH_KEY_PASSPHRASE"
  export -f do_ssh_add_key_file
  run expect <<__expect
  log_user 0
  set timeout 5
  spawn bash -c "do_ssh_add_key_file '$path' '' "
  expect {
    "Enter passphrase*" {
      send "$TEST_SSH_KEY_PASSPHRASE\r"
      expect {
        "Bad passphrase*" { exit 2 } eof
      }
    } eof
  }
  catch wait result
  exit [lindex \$result 3]
__expect
  [ "$status" -eq 0 ]
}

@test "do_ssh_add_key_file with RSA key (no passphrase)" {
  ssh-keygen -q -t rsa -b 3072 -f "$TEST_SSH_KEY_DIR/id_rsa_unsafe" -N ""
  run do_ssh_add_key_file "$TEST_SSH_KEY_DIR/id_rsa_unsafe"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Warn: Key with passphrase is recommended."* ]]
}

@test "do_ssh_add_key_file with invalid path should fail" {
  run do_ssh_add_key_file '/non/existent/path'
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Require path of key file. /non/existent/path"* ]]
}

@test "do_ssh_add_key with empty key should fail" {
  run do_ssh_add_key ''
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Require private key content"* ]]
}
