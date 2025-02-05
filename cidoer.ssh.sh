#!/usr/bin/env bash
# shellcheck disable=SC2317
declare -F 'define_cidoer_ssh' >/dev/null && return 0
set -eu -o pipefail

define_cidoer_ssh() {
  declare -F 'do_ssh_exec' >/dev/null && return 0
  declare -F 'do_workflow_job' >/dev/null || { declare -F 'define_cidoer_core' >/dev/null && define_cidoer_core; }
  export CIDOER_SSH_EXPORT_FUN=()
  export CIDOER_SSH_EXPORT_VAR=()
  do_ssh_check_dependencies() {
    do_check_optional_cmd ssh-keygen expect shasum sha256sum realpath
    do_check_required_cmd ssh ssh-agent ssh-add ssh-keyscan tar gzip || return $?
  }
  do_ssh_make_bash() {
    local line script=''
    while IFS= read -r line; do
      line="$(do_trim "$line")"
      [ -z "$line" ] && continue
      printf -v script '%s\n%s' "$script" "$line"
      [[ "$line" == *' '* ]] || { declare -F "$line" >/dev/null && do_ssh_export "$line"; }
    done <<<"$(printf "%s\n" "${@}")"
    local var fun
    for var in "${CIDOER_SSH_EXPORT_VAR[@]}"; do
      printf -v script '%s\n%s' "$(declare -p "$var")" "$script"
    done
    for fun in "${CIDOER_SSH_EXPORT_FUN[@]}"; do
      printf -v script '%s\n%s' "$(declare -f "$fun")" "$script"
    done
    printf '%s\n%s\n%s\n%s\n' '#!/usr/bin/env bash' 'set -eu' 'set -o pipefail' "$script"
  }
  do_ssh_exec() {
    local -r ssh="${1:-}"
    [ "${ssh:0:4}" = 'ssh ' ] || {
      do_print_error "$(do_stack_trace)" "Argument \$1 does not start with 'ssh '"
      return 1
    }
    [ $# -lt 2 ] && {
      LC_ALL='' $ssh || return $?
      return 0
    }
    local -r bash="$(do_ssh_make_bash "${@:2}")"
    { printf '%s\n' "$bash" | LC_ALL='' $ssh -- /usr/bin/env bash -s -; } || local -r status="$?"
    do_print_code_bash_debug "$(printf '%s\n#| %s -- /usr/bin/env bash -s -' "$bash" "$ssh")"
    [ "${status:-0}" -eq 0 ] || return "${status:-0}"
  }
  do_ssh_archive_dir() {
    local -rx local_path="${1:-}"
    local -r ssh="${2:-}"
    local -rx remote_path="${3:-}"
    local param
    for param in 'local_path' 'ssh' 'remote_path'; do
      if [ -z "${!param}" ]; then
        do_print_error "$(do_stack_trace)" "Error: Parameter '$param' is required" >&2
        return 1
      fi
    done
    command -v realpath >/dev/null 2>&1 && {
      local -r resolved_path=$(realpath "$local_path" 2>/dev/null) || {
        do_print_error "$(do_stack_trace)" "Error: Invalid path or insufficient permissions: $resolved_path" >&2
        return 1
      }
    }
    [ -d "$local_path" ] || {
      do_print_error "$(do_stack_trace)" "Error: Not a directory: $local_path" >&2
      return 1
    }
    detect_sha256_cmd() {
      command -v sha256sum >/dev/null 2>&1 && {
        printf 'sha256sum'
        return 0
      }
      command -v shasum >/dev/null 2>&1 && {
        printf 'shasum -a 256'
        return 0
      }
      do_print_error "$(do_stack_trace)" 'Error: No suitable command for calculating SHA-256' >&2
      return 1
    }
    local -r sha256_cmd="$(detect_sha256_cmd)" || return "$?"
    do_ssh_export remote_path
    tar --no-xattrs --version >/dev/null 2>&1 && local -r tar_cmd='tar --no-xattrs'
    do_print_trace "$(do_stack_trace)" "<${tar_cmd:-tar} -cf - $local_path>" "<$ssh:${remote_path:-}>"
    local -r local_hash=$(${tar_cmd:-tar} -cf - "$local_path" | gzip -n | $sha256_cmd | awk '{print $1}')
    local -r lock_dir="archive-to${remote_path//\//-}.d"
    do_lock_acquire "$lock_dir" || {
      do_print_error "$(do_stack_trace)" "Failed to acquire lock on '$lock_dir'." >&2
      return 3
    }
    [ -n "${resolved_path:-}" ] && do_print_dash_pair 'realpath' "$resolved_path"
    do_print_dash_pair 'sha256sum_local' "$local_hash"
    cat_with_ssh() {
      local -r ssh="${1:?}"
      local -r bash="$(do_ssh_make_bash $'cat >${remote_path:?}')"
      LC_ALL='' $ssh "$bash" || local -r status="$?"
      do_print_code_bash_debug "$(printf '%s\n#| %s' "$bash" "$ssh")"
      [ "${status:-0}" -eq 0 ] || return "${status:-0}"
    }
    { ${tar_cmd:-tar} -cf - "$local_path" | gzip -n | cat_with_ssh "$ssh"; } || local -r status="$?"
    do_lock_release "$lock_dir" >/dev/null
    [ "${status:-0}" -eq 0 ] || {
      do_print_error "$(do_stack_trace)" "Error: Transfer failed with status ${status:-0}" >&2
      return "${status:-0}"
    }
    calculate_sha256() {
      local -r file_path="${1:?}"
      local -r output_file="${2:-${file_path}.sha256}"
      local -r sha256="$(detect_sha256_cmd)" || return "$?"
      local -r sha256_hash="$($sha256 "$file_path" | awk '{print $1}')"
      printf '%s\n' "$sha256_hash" >"$output_file"
      printf '%s\n' "$sha256_hash"
    }
    do_ssh_export detect_sha256_cmd calculate_sha256
    local -r remote_hash=$(do_ssh_exec "$ssh" $'calculate_sha256 "${remote_path:?}"') || {
      do_print_error "$(do_stack_trace)" "Error: Failed to calculate remote checksum" >&2
      return 2
    }
    do_ssh_export_reset
    do_print_dash_pair 'sha256sum_remote' "$remote_hash"
    [ "$local_hash" = "$remote_hash" ] || {
      do_print_error "$(do_stack_trace)" "Error: Checksum verification failed" >&2
      return 3
    }
    do_print_trace "$(do_stack_trace)" "Transfer completed and verified successfully"
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
        if [ $# -gt 1 ]; then local -r first_hop='ssh -A'; else local -r first_hop='ssh'; fi
        printf -v chain '%s %s %s' "${first_hop:?}" "${options}" "${user_host}"
      else
        printf -v chain '%s -- ssh %s %s' "${chain}" "${options}" "${user_host}"
      fi
    done
    printf '%s' "${chain}"
    # Chained / Nested SSH command for multi-hop connections
  }
  do_ssh_add_known_host() {
    if ! command -v ssh-keyscan >/dev/null 2>&1; then
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
    local -r key="${1:-}"
    local -r passphrase_name="${2:-}"
    [ -z "$key" ] && {
      do_print_warn 'Error: Require private key content.' >&2
      return 1
    }
    [ -d /mnt/bin ] && local -r key_dir="/mnt/bin"
    [ -z "${key_dir:-}" ] && local -r key_dir=$(mktemp -d || :)
    local -r _tmp_file="${key_dir:-/tmp}/_key_file_$$"
    _rm_in_ssh_add_key() { local -r file=${1:-} && [ -n "$file" ] && [ -f "$file" ] && { rm -f "$file" || :; }; }
    do_trap_append "_rm_in_ssh_add_key $_tmp_file || :" EXIT SIGHUP SIGINT SIGQUIT SIGTERM || true
    local -r key0="$(printf '%s' "$key" | tr -d '\r')"
    printf '%b' "$key0\n" >"${_tmp_file:-}"
    chmod 400 "$_tmp_file"
    do_ssh_add_key_file "$_tmp_file" "$passphrase_name" || local -r code=$?
    _rm_in_ssh_add_key "$_tmp_file" || true
    return "${code:-0}"
  }
  do_ssh_add_key_file() {
    local path="${1:-}"
    local passphrase_name="${2:-}"
    if ! [ -f "$path" ]; then
      do_print_warn 'Error: Require path of key file.' "$path" >&2
      return 1
    fi
    if ssh-keygen -y -f "$path" -P '' >/dev/null 2>&1; then
      do_print_warn 'Warn: Key with passphrase is recommended.' "$path" >&2
      ssh-add "$path" || return $?
      return 0
    fi
    if [ -z "$passphrase_name" ]; then
      ssh-add "$path" || return $?
      return 0
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
      local -r rc=$?
      [ "$rc" -ne 0 ] && do_print_warn 'Warn: ssh-add failed' >&2
      return "$rc"
    fi
    if [ -d /mnt/bin ]; then local -r bin_dir="/mnt/bin"; else local -r bin_dir=$(mktemp -d); fi
    local -r _askpass_script="${bin_dir:?}/_askpass_script_$$"
    _rm_askpass() { local -r file=${1:-} && [ -n "$file" ] && [ -f "$file" ] && { rm -f "$file" || :; }; }
    do_trap_append "_rm_askpass $_askpass_script || :" EXIT SIGHUP SIGINT SIGQUIT SIGTERM || true
    printf '#!/usr/bin/env bash\n%s\n' "printf '%s\n' \"$pass\"" >"${_askpass_script:-}"
    chmod 500 "$_askpass_script"
    do_print_trace "ssh-add with SSH_ASKPASS"
    DISPLAY=:0 SSH_ASKPASS="$_askpass_script" ssh-add "$path" </dev/null >/dev/null 2>&1
    rc=$?
    _rm_askpass "$_askpass_script" || true
    return $rc
  }
}

declare -F 'define_cidoer_core' >/dev/null || {
  CIDOER_DIR="${CIDOER_DIR:-$(dirname "${BASH_SOURCE[0]}")}"
  [ -f "$CIDOER_DIR"/cidoer.core.sh ] && . "$CIDOER_DIR"/cidoer.core.sh
}
define_cidoer_ssh
do_check_bats_core || do_print_trace "$(do_reverse "${BASH_SOURCE[@]}")"
