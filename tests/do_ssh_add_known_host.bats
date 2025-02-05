#!/usr/bin/env bats
# shellcheck disable=SC2317

load ../cidoer.core.sh
load ../cidoer.ssh.sh

do_lock_acquire() { return 0; }
do_lock_release() { return 0; }

@test 'do_ssh_add_known_host | Add host successfully (port 22)' {
  ssh-keygen -R 'github.com'
  run do_ssh_add_known_host 'github.com'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Host 'github.com' not found in known_hosts. Adding..."* ]]
  [[ "$output" == *"Host 'github.com' has been successfully added."* ]]
}

@test 'do_ssh_add_known_host | Host already in known_hosts should return success immediately' {
  _do_it_twice() {
    ssh-keygen -R 'github.com'
    do_ssh_add_known_host 'github.com'
    do_ssh_add_known_host 'github.com'
  }
  run _do_it_twice
  [ "$status" -eq 0 ]
  [[ "$output" == *"Host 'github.com' not found in known_hosts. Adding..."* ]]
  [[ "$output" == *"Host 'github.com' has been successfully added."* ]]
  [[ "$output" == *"Host 'github.com' is already in known_hosts. No action needed."* ]]
  echo "$output" >/tmp/bats-out
}

@test 'do_ssh_add_known_host | Fail to create ~/.ssh directory' {
  mkdir() {
    echo "$@"
    return 1
  }
  TEMP_HOME="$(mktemp -d)"
  REAL_HOME="$HOME"
  export HOME="$TEMP_HOME"
  run do_ssh_add_known_host 'example.com'
  export HOME="$REAL_HOME"
  unset -f mkdir
  [ "$status" -eq 2 ]
  [[ "$output" == *"Failed to create ${TEMP_HOME}/.ssh directory."* ]]
}

@test 'do_ssh_add_known_host | ssh-keyscan not available' {
  OLD_PATH="$PATH"
  # shellcheck disable=SC2123
  PATH=""
  run do_ssh_add_known_host 'example.com'
  PATH="$OLD_PATH"
  [ "$status" -eq 1 ]
  [[ "${lines[*]}" =~ 'ssh-keyscan is not available' ]]
}

@test 'do_ssh_add_known_host | ssh-keyscan fails to add host' {
  local host='github.com'
  run do_ssh_add_known_host "$host" '2'
  [ "$status" -eq 3 ]
  [[ "$output" == *"Host '$host:2' not found in known_hosts. Adding..."* ]]
  [[ "$output" == *"Failed to add host '$host:2' with ssh-keyscan."* ]]
}

@test 'do_ssh_add_known_host | No arguments should return usage error' {
  run do_ssh_add_known_host
  [ "$status" -eq 1 ]
  [[ "${lines[*]}" =~ 'Usage:' ]]
}

@test 'do_ssh_add_known_host | Too many arguments should return usage error' {
  run do_ssh_add_known_host arg1 arg2 arg3
  [ "$status" -eq 1 ]
  [[ "${lines[*]}" =~ 'Usage:' ]]
}

@test 'do_ssh_add_known_host | Empty hostname should return usage error' {
  run do_ssh_add_known_host ""
  [ "$status" -eq 1 ]
  [[ "${lines[*]}" =~ 'Usage:' ]]
}

@test 'do_ssh_add_known_host | Invalid port (non-numeric)' {
  run do_ssh_add_known_host 'example.com' 'abc'
  [ "$status" -eq 2 ]
  [[ "${lines[*]}" =~ 'Invalid port number' ]]
}

@test 'do_ssh_add_known_host | Invalid port (out of range: 0)' {
  run do_ssh_add_known_host 'example.com' 0
  [ "$status" -eq 2 ]
  [[ "${lines[*]}" =~ 'Port must be between' ]]
}

@test 'do_ssh_add_known_host | Invalid port (out of range: 99999)' {
  run do_ssh_add_known_host 'example.com' '99999'
  [ "$status" -eq 2 ]
  [[ "${lines[*]}" =~ 'Port must be between' ]]
}
