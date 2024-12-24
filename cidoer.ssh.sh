#!/usr/bin/env bash
# shellcheck disable=SC2317
if declare -F 'define_ssh_utils' >/dev/null; then return 0; fi
set -eou pipefail

define_ssh_utils() {
  if declare -F 'do_ssh_check_dependencies' >/dev/null; then return 0; fi
  if ! declare -F 'do_check_core_dependencies' >/dev/null; then
    source "${CIDOER_DIR:?}"/cidoer.core.sh
  fi
  do_ssh_check_dependencies() {
    do_check_optional_cmd whoami expect ssh-keygen ssh-keyscan
    do_check_required_cmd mkdir mktemp chmod cat rm tr ssh-agent ssh-add
  }
  do_ssh_agent_ensure() {
    if ! command -v ssh-agent >/dev/null 2>&1; then return 127; fi
    if ! command -v ssh-add >/dev/null 2>&1; then return 127; fi
    if [ -z "${SSH_AUTH_SOCK:-}" ] || ! ssh-add -l >/dev/null 2>&1; then
      local user
      user="${USER:=$(whoami)}"
      local agent_dir="/tmp/ssh-agent-${user:-}"
      mkdir -p "$agent_dir"
      if [[ -f "$agent_dir/ssh-agent.pid" ]]; then
        local agent_pid
        agent_pid=$(cat "$agent_dir/ssh-agent.pid")
        if ! kill -0 "$agent_pid" 2>/dev/null; then
          do_print_trace "Removing stale ssh-agent files..."
          rm -f "$agent_dir/ssh-agent.*"
        fi
      fi
      do_print_trace "Starting new ssh-agent..."
      eval "$(ssh-agent -a "$agent_dir/ssh-agent.sock")"
      printf '%s' "$SSH_AGENT_PID" >"$agent_dir/ssh-agent.pid"
      declare -rx SSH_AGENT_PID
      declare -rx SSH_AUTH_SOCK="$agent_dir/ssh-agent.sock"
    else
      do_print_trace "ssh-agent is already running and accessible."
    fi
  }
  do_ssh_add_key() {
    local key="${1:-}"
    local passphrase_name="${2:-}"
    if [ -z "$key" ]; then
      do_print_warn 'Error: Require private key content.' >&2
      return 1
    fi
    local key_dir
    if [ -d /mnt/bin ]; then key_dir="/mnt/bin"; else key_dir=$(mktemp -d); fi
    _tmp_file="$key_dir/_key_file_$$"
    _cleanup_tmp_file() {
      if ! [ -f "${_tmp_file:-}" ]; then return 0; fi
      rm -f "${_tmp_file}"
      unset _tmp_file
      return 0
    }
    trap _cleanup_tmp_file EXIT
    key="$(printf '%s' "$key" | tr -d '\r')"
    printf '%b' "$key\n" >"${_tmp_file:-}"
    chmod 400 "$_tmp_file"
    do_ssh_add_key_file "$_tmp_file" "$passphrase_name"
    local rc=$?
    _cleanup_tmp_file
    return $rc
  }
  do_ssh_add_key_file() {
    local path="${1:-}"
    local passphrase_name="${2:-}"
    local rc=0
    if ! [ -f "$path" ]; then
      do_print_warn 'Error: Require path of key file.' "$path" >&2
      return 1
    fi
    if ssh-keygen -y -f "$path" -P '' >/dev/null 2>&1; then
      do_print_warn 'Warn: Key with passphrase is recommended.' "$path" >&2
      ssh-add "$path"
      rc=$?
      return $rc
    fi
    if [ -z "$passphrase_name" ]; then
      ssh-add "$path"
      rc=$?
      return $rc
    fi
    set +u
    local pass="${!passphrase_name}"
    set -u
    if [ -z "$pass" ]; then
      do_print_warn 'Warn: Passphrase is absent.' "\$$passphrase_name" >&2
      return 1
    fi
    if command -v expect >/dev/null 2>&1; then
      expect <<______expect
      log_user 0
      set timeout 5
      spawn ssh-add "$path"
      expect {
        "Enter passphrase*" {
          send "$pass\r"
          expect {
            "Bad passphrase*" { exit 2 } eof
          }
        } eof
      }
      catch wait result
      exit [lindex \$result 3]
______expect
      rc=$?
      if [ "$rc" -ne 0 ]; then do_print_warn 'Warn: ssh-add failed' >&2; fi
      return "$rc"
    fi
    local bin_dir
    if [ -d /mnt/bin ]; then bin_dir="/mnt/bin"; else bin_dir=$(mktemp -d); fi
    _askpass_script="$bin_dir/_askpass_script_$$"
    _cleanup_askpass_script() {
      if ! [ -f "${_askpass_script:-}" ]; then return 0; fi
      rm -f "${_askpass_script}"
      unset _askpass_script
      return 0
    }
    trap _cleanup_askpass_script EXIT
    printf '#!/usr/bin/env bash\n%s\n' "printf '%s\n' \"$pass\"" >"${_askpass_script:-}"
    chmod 500 "$_askpass_script"
    do_print_trace "ssh-add with SSH_ASKPASS"
    DISPLAY=:0 SSH_ASKPASS="$_askpass_script" ssh-add "$path" </dev/null >/dev/null 2>&1
    rc=$?
    _cleanup_askpass_script
    return $rc
  }
}

define_ssh_utils
