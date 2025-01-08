#!/usr/bin/env bash
# shellcheck disable=SC2317
declare -F 'define_cidoer_ssh' >/dev/null && return 0
set -eou pipefail

declare -ax CIDOER_SSH_EXPORT_FUN=()
declare -ax CIDOER_SSH_EXPORT_VAR=()

define_cidoer_ssh() {
  declare -F 'do_ssh_exec' >/dev/null && return 0
  declare -F 'do_tint' >/dev/null || {
    [ -f "${CIDOER_DIR:-}"/cidoer.core.sh ] && {
      . "${CIDOER_DIR:-}"/cidoer.core.sh
      do_print_trace 'source' "${CIDOER_DIR:-}"/cidoer.core.sh
    }
  }
  do_ssh_check_dependencies() {
    do_check_optional_cmd ssh-keygen expect
    do_check_required_cmd ssh-agent ssh-add ssh-keyscan ssh
  }
  do_ssh_exec() {
    local -r ssh="${1:-}"
    [ "${ssh:0:4}" = 'ssh ' ] || {
      do_print_warn "$(do_stack_trace)" "Argument \$1 does not start with 'ssh '"
      return 1
    }
    [ $# -lt 2 ] && {
      $ssh || return $?
      return 0
    }
    local line script=''
    while IFS= read -r line; do
      line="$(do_trim "$line")"
      [ -z "$line" ] && continue
      printf -v script '%s\n%s' "$script" "$line"
      [[ "$line" == *' '* ]] || { declare -F "$line" >/dev/null && do_ssh_export "$line"; }
    done <<<"$(printf "%s\n" "${@:2}")"
    local var fun
    for var in "${CIDOER_SSH_EXPORT_VAR[@]}"; do
      printf -v script '%s\n%s' "$(declare -p "$var")" "$script"
    done
    for fun in "${CIDOER_SSH_EXPORT_FUN[@]}"; do
      printf -v script '%s\n%s' "$(declare -f "$fun")" "$script"
    done
    do_print_debug 'bash' "$(printf '%s\n#| %s -- /usr/bin/env bash -eu -o pipefail -s -' "$script" "$ssh")"
    printf '%s\n' "$script" | $ssh -- /usr/bin/env bash -eu -o pipefail -s -
  }
  do_ssh_export_reset() {
    CIDOER_SSH_EXPORT_FUN=()
    CIDOER_SSH_EXPORT_VAR=(CIDOER_DEBUG CIDOER_SSH_EXPORT_FUN CIDOER_SSH_EXPORT_VAR)
  }
  do_ssh_export_reset
  do_ssh_export() {
    _contains_element() {
      local -r element="${1:-}" && shift
      local item
      for item in "$@"; do [[ "$item" = "$element" ]] && return 0; done
      return 1
    }
    CIDOER_SSH_EXPORT_FUN=("${CIDOER_SSH_EXPORT_FUN[@]:-}")
    CIDOER_SSH_EXPORT_VAR=("${CIDOER_SSH_EXPORT_VAR[@]:-}")
    local name
    for name in "$@"; do
      if [ "$(type -t "$name")" = 'function' ]; then
        _contains_element "$name" "${CIDOER_SSH_EXPORT_FUN[@]}" && continue
        CIDOER_SSH_EXPORT_FUN+=("$name")
      else
        _contains_element "$name" "${CIDOER_SSH_EXPORT_VAR[@]}" && continue
        CIDOER_SSH_EXPORT_VAR+=("$name")
      fi
    done
  }
  do_ssh_print_chain() {
    if [ $# -lt 1 ]; then
      printf 'Usage: do_ssh_print_chain <[user@]host[:port]> [[user2@]host2[:port2] ... [userN@]hostN[:portN]]\n'
      printf 'Example: do_ssh_print_chain user1@host1:2202 user2@host2\n'
      return 1
    fi
    local arg user_host port_str options chain
    local -i port
    for arg in "$@"; do
      arg="$(do_trim "$arg")"
      [ -z "${arg}" ] && {
        printf 'Error: Empty argument.\n' >&2
        return 1
      }
      port=0
      user_host="${arg%:*}"
      if [[ "${arg}" == *:* ]]; then
        port_str="${arg##*:}"
        if ! [[ "${port_str}" =~ ^[0-9]+$ ]]; then
          printf 'Error: Invalid port "%s" in argument "%s". Port must be a number.\n' "${port_str}" "${arg}" >&2
          return 1
        fi
        port=port_str
      fi
      options='-T -o ConnectTimeout=3'
      [ "${port}" -gt 0 ] && options="${options} -p ${port}"
      if [ -z "${chain:-}" ]; then
        printf -v chain 'ssh %s %s' "${options}" "${user_host}"
      else
        printf -v chain '%s -- ssh %s %s' "${chain}" "${options}" "${user_host}"
      fi
    done
    printf '%s' "${chain}"
    # Chained / Nested SSH command for multi-hop connections
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
  do_ssh_add_known_host() {
    if ! command -v ssh-keyscan &>/dev/null; then
      do_print_warn "ssh-keyscan is not available. Please install it." >&2
      return 1
    fi
    if [ $# -lt 1 ] || [ $# -gt 2 ] || [ -z "$1" ]; then
      do_print_warn "Usage: do_ssh_add_known_host <hostname> [port]" >&2
      return 1
    fi
    local -r host="${1:?}"
    local -r port="${2:-22}"
    local -r known_hosts_file="${HOME:?}/.ssh/known_hosts"
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
      do_print_warn "Invalid port number." >&2
      return 2
    fi
    if ((port < 1 || port > 65535)); then
      do_print_warn "Port must be between 1 and 65535." >&2
      return 2
    fi
    if [ ! -d "${HOME}/.ssh" ]; then
      if ! mkdir -p "${HOME}/.ssh"; then
        do_print_warn "Failed to create ${HOME}/.ssh directory." >&2
        return 2
      fi
      if ! chmod 700 "${HOME}/.ssh"; then
        do_print_warn "Warning: Failed to set permissions on ${HOME}/.ssh directory." >&2
        return 2
      fi
    fi
    local host_with_port="$host"
    [ "$port" != "22" ] && host_with_port="${host}:${port}"
    if ssh-keygen -F "$host_with_port" >/dev/null 2>&1; then
      do_print_trace "Host '$host_with_port' is already in known_hosts. No action needed."
      return 0
    fi
    do_print_trace "Host '$host_with_port' not found in known_hosts. Adding..."
    local -r lock_dir='known_hosts_lock.d'
    do_lock_acquire "$lock_dir" || {
      do_print_warn "Failed to acquire lock on '$lock_dir'." >&2
      return 3
    }
    touch "$known_hosts_file" && chmod 600 "$known_hosts_file"
    if ! ssh-keyscan -H -p "$port" "$host" 2>/dev/null | grep -v '^#' >>"$known_hosts_file"; then
      do_print_warn "Failed to add host '$host_with_port' with ssh-keyscan." >&2
      return 3
    fi
    do_print_trace "Host '$host_with_port' has been successfully added."
    do_lock_release "$lock_dir"
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
    local -r pass="${!passphrase_name:-}"
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

define_cidoer_ssh
