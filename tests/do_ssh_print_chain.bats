#!/usr/bin/env bats
# shellcheck disable=SC2317

load ../cidoer.core.sh
load ../cidoer.ssh.sh

@test "do_ssh_print_chain | Single argument without port" {
  run do_ssh_print_chain "user@host"
  [ "$status" -eq 0 ]
  [[ "$output" == "ssh -T -o ConnectTimeout=3 user@host" ]]
}

@test "do_ssh_print_chain | Single argument with valid port" {
  run do_ssh_print_chain "user@host:22"
  [ "$status" -eq 0 ]
  [[ "$output" == "ssh -T -o ConnectTimeout=3 -p 22 user@host" ]]
}

@test "do_ssh_print_chain | Multiple arguments" {
  run do_ssh_print_chain "user1@host1:2202" "user2@host2"
  [ "$status" -eq 0 ]
  [[ "$output" == "ssh -A -T -o ConnectTimeout=3 -p 2202 user1@host1 -- ssh -T -o ConnectTimeout=3 user2@host2" ]]
}

@test "do_ssh_print_chain | No arguments" {
  run do_ssh_print_chain
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"Example:"* ]]
}

@test "do_ssh_print_chain | Empty argument" {
  run do_ssh_print_chain ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Empty argument."* ]]
}

@test "do_ssh_print_chain | Single argument with invalid port" {
  run do_ssh_print_chain "user@host:abc"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Invalid port"* ]]
}
