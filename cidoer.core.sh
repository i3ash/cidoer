#!/usr/bin/env bash
# shellcheck disable=SC2317
declare -F 'define_cidoer_core' >/dev/null && return 0
set -eu -o pipefail

define_cidoer_core() {
  declare -F '_print_defined' >/dev/null || { declare -F 'define_cidoer_print' >/dev/null && define_cidoer_print; }
  declare -F '_core_defined' >/dev/null && return 0
  _core_defined() { :; }
  CIDOER_DEBUG='no'
  CIDOER_OS_TYPE=''
  CIDOER_HOST_TYPE=''
  do_workflow_job() {
    local -r job_type=$(do_trim "${1:-}")
    [[ "${job_type:-}" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || {
      do_print_warn "$(do_stack_trace)" $'$1 (job_type) is invalid:' "'${1:-}'" >&2
      return 1
    }
    local -a steps=()
    local arg step
    for arg in "${@:2}"; do
      step=$(do_trim "$arg")
      [[ "${step:-}" =~ ^[a-zA-Z0-9_]*$ ]] || {
        do_print_warn "$(do_stack_trace)" "step name of '${job_type:-}' is invalid:" "'${step:-}'" >&2
        return 1
      }
      steps+=("$step")
    done
    [ ${#steps[@]} -le 0 ] && steps=('do')
    local -r lower=$(do_convert_to_lower "$job_type")
    for step in "${steps[@]}"; do
      declare -F "${lower}_${step}" >/dev/null && local -r defined=1 && break
    done
    [ "${defined:-0}" -eq 1 ] || {
      do_func_invoke "define_${lower}" "${steps[@]}" || return $?
    }
    for step in "${steps[@]}"; do
      do_func_invoke "${lower}_${step}" || return $?
    done
  }
  do_func_invoke() {
    local -r func_name="${1:-}"
    local -r func_finally="${func_name}_finally"
    [ -z "$func_name" ] && {
      do_print_warn "$(do_stack_trace)" $'$1 (func_name) is required' >&2
      return 0
    }
    declare -F "$func_name" >/dev/null || {
      do_print_trace "$(do_stack_trace)" "$func_name is an absent function" >&2
      return 0
    }
    "${@}" || local -r status=$?
    declare -F "$func_finally" >/dev/null && {
      [ "${status:-0}" -eq 0 ] || do_print_info "$(do_stack_trace)" "$func_name failed with exit code $status" >&2
      "$func_finally" "${status:-0}" || local -r code=$?
      [ "${code:-0}" -eq 0 ] || do_print_warn "$(do_stack_trace)" "$func_finally failed with exit code $code" >&2
      return "${code:-0}"
    }
    [ "${status:-0}" -eq 0 ] || do_print_warn "$(do_stack_trace)" "$func_name failed with exit code $status" >&2
    return "${status:-0}"
  }
  do_trim() {
    local var="${1:-}"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
  }
  do_reverse() {
    local -a array=("$@") reversed=()
    local -i i
    for ((i = ${#array[@]} - 1; i >= 0; i--)); do reversed+=("${array[$i]}"); done
    printf '%s' "${reversed[*]}"
  }
  do_convert_to_lower() {
    local input="${1:-}"
    do_check_bash_4 && printf '%s\n' "${input,,}" && return 0
    printf '%s\n' "$input" | sed 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/'
  }
  do_convert_to_upper() {
    local input="${1:-}"
    do_check_bash_4 && printf '%s\n' "${input^^}" && return 0
    printf '%s\n' "$input" | sed 'y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/'
  }
  do_print_variable() {
    [ "$#" -le 0 ] && return 0
    local -r prefix="${1:-}" name="${2:-}" suffix="${3:-}"
    local -ra candidates=("${prefix}${name}${suffix}" "${prefix}${name}" "${name}${suffix}" "${name}")
    local value='' candidate=''
    for candidate in "${candidates[@]}"; do
      value="${!candidate:-}"
      [ -n "$value" ] && break
    done
    local -r trimmed="${value#"${value%%[![:space:]]*}"}"
    printf '%s' "${trimmed%"${trimmed##*[![:space:]]}"}"
  }
  do_list_files() {
    local -r dir="${1:-.}"
    [ -d "$dir" ] || return 0
    local -r path="$(realpath "$dir")"
    do_print_trace "$(do_stack_trace)" "$path"
    find "$path" -type l -exec ls -lhA {} +
    find "$path" -type f -exec ls -lhA {} +
    do_print_trace "$(do_stack_trace)" "$(date)"
  }
  do_trap_append() {
    local -r new_cmd="$1" && shift
    local sig old_cmd
    for sig in "$@"; do
      do_check_bats_core && [[ "$sig" == "EXIT" || "$sig" == "ERR" ]] && continue
      old_cmd="$(trap -p "$sig" | sed -E "s/trap -- '(.*)' $sig/\1/")"
      if [[ -z "$old_cmd" || "$old_cmd" == "SIG_IGN" || "$old_cmd" == "SIG_DFL" ]]; then
        trap -- "$new_cmd" "$sig"
      else
        trap -- "$(printf "%s; %s" "$old_cmd" "$new_cmd")" "$sig"
      fi
    done
  }
  do_trap_prepend() {
    local -r new_cmd="$1" && shift
    local sig old_cmd
    for sig in "$@"; do
      do_check_bats_core && [[ "$sig" == "EXIT" || "$sig" == "ERR" ]] && continue
      old_cmd="$(trap -p "$sig" | sed -E "s/trap -- '(.*)' $sig/\1/")"
      if [[ -z "$old_cmd" || "$old_cmd" == "SIG_IGN" || "$old_cmd" == "SIG_DFL" ]]; then
        trap -- "$new_cmd" "$sig"
      else
        trap -- "$(printf "%s; %s" "$new_cmd" "$old_cmd")" "$sig"
      fi
    done
  }
  do_os_type() {
    [ -n "${CIDOER_OS_TYPE:-}" ] && {
      printf '%s\n' "${CIDOER_OS_TYPE:-}"
      return 0
    }
    if [ -z "${OSTYPE:-}" ]; then
      command -v uname >/dev/null 2>&1 && local -r os="$(uname -s)"
    else local -r os="${OSTYPE:-}"; fi
    local -r type=$(do_convert_to_lower "$os")
    case "${type:-}" in
    linux*) CIDOER_OS_TYPE='linux' ;;
    darwin*) CIDOER_OS_TYPE='darwin' ;;
    cygwin* | msys* | mingw* | windows*) CIDOER_OS_TYPE='windows' ;;
    *) CIDOER_OS_TYPE='unknown' ;;
    esac
    printf '%s\n' "${CIDOER_OS_TYPE:-}"
  }
  do_host_type() {
    [ -n "${CIDOER_HOST_TYPE:-}" ] && {
      printf '%s\n' "$CIDOER_HOST_TYPE"
      return 0
    }
    if [ -z "${HOSTTYPE:-}" ]; then
      command -v uname >/dev/null 2>&1 && local -r host="$(uname -m)"
    else local -r host="${HOSTTYPE:-}"; fi
    local -r type=$(do_convert_to_lower "$host")
    case "$type" in
    x86_64 | amd64 | x64) CIDOER_HOST_TYPE='x86_64' ;;
    i*86 | x86) CIDOER_HOST_TYPE='x86' ;;
    arm64 | aarch64) CIDOER_HOST_TYPE='arm64' ;;
    armv5* | armv6* | armv7* | aarch32) CIDOER_HOST_TYPE='arm' ;;
    armv8*) CIDOER_HOST_TYPE="$type" ;;
    ppc | powerpc) CIDOER_HOST_TYPE='ppc' ;;
    ppc64 | ppc64le) CIDOER_HOST_TYPE="$type" ;;
    mips | mips64 | mipsle | mips64le | s390x | riscv64) CIDOER_HOST_TYPE="$type" ;;
    *) CIDOER_HOST_TYPE='unknown' ;;
    esac
    printf '%s\n' "$CIDOER_HOST_TYPE"
  }
  do_check_installed() {
    if [ "$#" -le 0 ] || [ -z "$1" ]; then
      do_print_warn "$(do_stack_trace)" $'$1 (cmd) is required'
      return 2
    fi
    local cmd="$1" cmd_path
    cmd_path=$(command -v "${cmd}" 2>/dev/null)
    if [ -n "${cmd_path}" ] && [ -x "${cmd_path}" ]; then
      do_print_dash_pair "${cmd}" "${cmd_path}"
      return 0
    fi
    return 1
  }
  do_check_optional_cmd() {
    do_print_dash_pair "${FUNCNAME[0]}"
    local cmd
    for cmd in "${@}"; do
      if ! do_check_installed "$cmd"; then
        do_print_dash_pair "${cmd}" ''
      fi
    done
  }
  do_check_required_cmd() {
    do_print_dash_pair "${FUNCNAME[0]}"
    local cmd
    local missing=0
    for cmd in "${@}"; do
      do_check_installed "$cmd" || {
        do_print_dash_pair "${cmd}" "$(do_tint "${CIDOER_COLOR_RED:-red}" missing)"
        missing=1
      }
    done
    if [ "$missing" -eq 1 ]; then
      do_print_error 'Please install the missing required commands and try again later.'
      return 1
    fi
  }
  do_check_bash_3_2() {
    [ -z "${BASH_VERSION:-}" ] && return 1
    [ "${BASH_VERSINFO[0]}" -lt 3 ] && return 1
    [ "${BASH_VERSINFO[0]}" -eq 3 ] && [ "${BASH_VERSINFO[1]}" -lt 2 ] && return 1
    return 0
  }
  do_check_bash_4() {
    [ -z "${BASH_VERSION:-}" ] && return 1
    [ "${BASH_VERSINFO[0]}" -lt 4 ] && return 1
    return 0
  }
  do_check_bats_core() {
    [[ -n "${BATS_TEST_NUMBER:-}" ]] && return 0
    [[ -n "${BATS_TEST_NAME:-}" ]] && return 0
    return 1
  }
  do_check_process() {
    local name="${1:-}"
    [ -z "$name" ] && return 2
    if command -v pgrep >/dev/null 2>&1; then
      pgrep -u "${USER:-$(id -un)}" "$name" >/dev/null && return 0
    elif command -v ps >/dev/null 2>&1; then
      # shellcheck disable=SC2009
      ps aux | grep "[${name:0:1}]${name:1}" >/dev/null && return 0
    elif [[ -d /proc ]]; then
      local pid
      for pid in /proc/[0-9]*; do
        [[ -f "$pid/cmdline" && $(tr -d '\0' <"$pid/cmdline") == *"$name"* ]] && return 0
      done
    fi
    return 1
  }
  do_print_fix() {
    declare -F 'do_tint' >/dev/null || do_tint() { printf '%s\n' "- ${*:2}"; }
    declare -F 'do_print_with_color' >/dev/null || do_print_with_color() { return 1; }
    declare -F 'do_print_trace' >/dev/null || do_print_trace() { printf '%s\n' "- $*"; }
    declare -F 'do_print_info' >/dev/null || do_print_info() { printf '%s\n' "= $*"; }
    declare -F 'do_print_warn' >/dev/null || do_print_warn() { printf '%s\n' "? $*"; }
    declare -F 'do_print_error' >/dev/null || do_print_error() { printf '%s\n' "! $*"; }
    declare -F 'do_print_section' >/dev/null || do_print_section() { printf '%s\n' "== $*"; }
    declare -F 'do_print_dash_pair' >/dev/null || do_print_dash_pair() { printf '%s\n' "-- $*"; }
    declare -F 'do_print_code_lines' >/dev/null || do_print_code_lines() { printf '%s\n' "$*"; }
    declare -F 'do_print_code_bash' >/dev/null || do_print_code_bash() { do_print_code_lines "$@"; }
    declare -F 'do_print_code_bash_fn' >/dev/null || do_print_code_bash_fn() {
      do_print_code_bash "$(declare -f "$@")"
    }
    declare -F 'do_print_code_bash_debug' >/dev/null || do_print_code_bash_debug() {
      [ "${CIDOER_DEBUG:-no}" != "yes" ] && return 0
      do_print_code_bash "$@" >&2
    }
    declare -F 'do_print_debug' >/dev/null || do_print_debug() {
      [ "${CIDOER_DEBUG:-no}" != "yes" ] && return 0
      do_print_code_lines "$@" >&2
    }
    declare -F 'do_stack_trace' >/dev/null || do_stack_trace() {
      # shellcheck disable=SC2319
      local -ir status=$?
      local -i idx
      local -a filtered_fns=()
      for ((idx = ${#FUNCNAME[@]} - 2; idx > 0; idx--)); do
        [ 'do_func_invoke' != "${FUNCNAME[$idx]}" ] && filtered_fns+=("${FUNCNAME[$idx]}")
      done
      if [ ${#filtered_fns[@]} -gt 0 ]; then
        printf '%s --> %s\n' "${USER:-$(id -un)}@${HOSTNAME:-$(hostname)}" "${filtered_fns[*]}"
      else printf '%s -->\n' "${USER:-$(id -un)}@${HOSTNAME:-$(hostname)}"; fi
      return $status
    }
  }
  declare -F 'do_stack_trace' >/dev/null || do_print_fix
}

define_cidoer_lock() {
  declare -F '_core_defined' >/dev/null || { declare -F 'define_cidoer_core' >/dev/null && define_cidoer_core; }
  declare -F "do_lock_release" >/dev/null && return 0
  CIDOER_LOCK_NAMES=()
  CIDOER_LOCK_FDS=()
  [ -z "${CIDOER_LOCK_BASE_DIR:-}" ] && {
    CIDOER_LOCK_BASE_DIR="/cidoer/locks"
    mkdir -p "/tmp${CIDOER_LOCK_BASE_DIR}" || {
      [ -d "/tmp${CIDOER_LOCK_BASE_DIR}" ] || do_print_error "Failed to create lock base directory"
    }
  }
  do_lock_release() {
    local -r lock_name="${1:-}"
    local -r lock_path="/tmp${CIDOER_LOCK_BASE_DIR}/${lock_name}"
    [ -f "$lock_path/pid" ] && {
      do_print_trace "Release lock on '$lock_name'"
      rm -f "$lock_path/pid" || do_print_trace "Failed to remove pid file:" "$lock_path/pid" >&2
    }
    [ -d "$lock_path" ] && {
      rmdir "$lock_path" || do_print_trace "Failed to remove directory:" "$lock_path" >&2
    }
    local -i i idx=-1
    for i in "${!CIDOER_LOCK_NAMES[@]}"; do
      if [ "${CIDOER_LOCK_NAMES[$i]}" = "$lock_name" ]; then
        idx="$i"
        break
      fi
    done
    if [ "$idx" -ge 0 ]; then
      local fd="${CIDOER_LOCK_FDS[$idx]}"
      { [ -n "$fd" ] && eval "exec $fd>&-"; } || true
      unset "CIDOER_LOCK_NAMES[$idx]"
      unset "CIDOER_LOCK_FDS[$idx]"
    fi
  }
  do_lock_acquire() {
    local -r lock_name="${1:-}"
    local -r lock_path="/tmp${CIDOER_LOCK_BASE_DIR}/${lock_name}"
    local -r max_attempts="${2:-20}"
    local -r pid_file="${lock_path}/pid"
    local -r try_func="do_lock_try_${CIDOER_LOCK_METHOD:-mkdir}"
    local -i attempt=1
    local -i lock_acquired=0
    while [ "$attempt" -le "$max_attempts" ] && [ "$lock_acquired" -eq 0 ]; do
      if [ -d "$lock_path" ] && [ -f "$pid_file" ]; then
        local pid
        pid=$(cat "$pid_file" 2>/dev/null)
        if [ -n "$pid" ] && ! kill -0 "$pid" >/dev/null 2>&1; then
          do_lock_release "$lock_name"
        fi
      fi
      do_print_trace "Try to lock '$lock_name' with ${try_func}. [${attempt}/${max_attempts}]"
      if "$try_func" "$lock_name"; then
        lock_acquired=1
        do_trap_prepend "do_lock_release $lock_name || :" EXIT SIGHUP SIGINT SIGQUIT SIGTERM || :
        return 0
      fi
      sleep $((attempt < 5 ? 1 : 3))
      attempt=$((attempt + 1))
    done
    return 1
  }
  do_lock_try_flock() {
    command -v flock >/dev/null 2>&1 || return 1
    local -r lock_name="${1:-}"
    local -r lock_path="/tmp${CIDOER_LOCK_BASE_DIR}/${lock_name}"
    mkdir -p "$lock_path" || return 1
    local -r fd=$(_lock_next_fd) || return 2
    eval "exec $fd>\"$lock_path/pid\"" || return 3
    if flock -n "$fd"; then
      printf '%s\n' "$$" >"$lock_path/pid"
      CIDOER_LOCK_NAMES[${#CIDOER_LOCK_NAMES[@]}]="$lock_name"
      CIDOER_LOCK_FDS[${#CIDOER_LOCK_FDS[@]}]="$fd"
      return 0
    fi
    eval "exec $fd>&-" || true
    return 1
  }
  do_lock_try_lockf() {
    command -v lockf >/dev/null 2>&1 || return 1
    local -r lock_name="${1:-}"
    local -r lock_path="/tmp${CIDOER_LOCK_BASE_DIR}/${lock_name}"
    mkdir -p "$lock_path" || return 1
    local -r fd=$(_lock_next_fd) || return 2
    eval "exec $fd>\"$lock_path/pid\"" || return 3
    if lockf -t 0 "$fd"; then
      printf '%s\n' "$$" >"$lock_path/pid"
      CIDOER_LOCK_NAMES[${#CIDOER_LOCK_NAMES[@]}]="$lock_name"
      CIDOER_LOCK_FDS[${#CIDOER_LOCK_FDS[@]}]="$fd"
      return 0
    fi
    eval "exec $fd>&-" || true
    return 1
  }
  do_lock_try_mkdir() {
    local -r lock_name="${1:-}"
    local -r lock_path="/tmp${CIDOER_LOCK_BASE_DIR}/${lock_name}"
    if mkdir "$lock_path"; then
      printf '%s\n' "$$" >"$lock_path/pid"
      CIDOER_LOCK_NAMES[${#CIDOER_LOCK_NAMES[@]}]="$lock_name"
      CIDOER_LOCK_FDS[${#CIDOER_LOCK_FDS[@]}]=''
      return 0
    fi
    return 1
  }
  _lock_next_fd() {
    local -r max_fd=2048
    local fd="${_CIDOER_LOCK_FD_START:=200}"
    while ((fd <= max_fd)); do
      if (true >&"$fd") >/dev/null 2>&1; then
        fd=$((fd + 1))
      else
        _CIDOER_LOCK_FD_START=$((fd + 1))
        printf '%s' "$fd"
        return 0
      fi
    done
    do_print_error "$(do_stack_trace)" "Error: No free FD found between 200 and $max_fd." >&2
    return 1
  }
  _lock_method_confirm() {
    [ -n "${CIDOER_LOCK_METHOD:-}" ] && return 0
    CIDOER_LOCK_METHOD="mkdir"
    local -r lock_path="/tmp${CIDOER_LOCK_BASE_DIR}/check.d"
    mkdir -p "$lock_path" || {
      do_print_warn "Failed to create lock directory: $lock_path"
      return 1
    }
    local -r fd=$(_lock_next_fd) || {
      do_print_warn "Failed to get next file descriptor"
      return 1
    }
    eval "exec $fd>\"$lock_path/pid\"" || {
      do_print_warn "Failed to open lock file"
      return 1
    }
    if command -v flock >/dev/null 2>&1; then
      if flock -n "$fd"; then
        CIDOER_LOCK_METHOD="flock"
        do_print_trace "Using flock locking method"
      else
        do_print_warn "Warning: flock -n unsupported, fallback to mkdir lock."
      fi
    elif command -v lockf >/dev/null 2>&1; then
      if lockf -t 0 "$fd"; then
        CIDOER_LOCK_METHOD="lockf"
        do_print_trace "Using lockf locking method"
      else
        do_print_warn "Warning: lockf -t unsupported, fallback to mkdir lock."
      fi
    else
      do_print_trace "Using mkdir locking method (flock and lockf not available)"
    fi
    eval "exec $fd>&-" || do_print_warn "Failed to close file descriptor $fd, continuing anyway"
  }
  _lock_method_confirm
}

define_cidoer_file() {
  declare -F '_print_defined' >/dev/null || { declare -F 'define_cidoer_print' >/dev/null && define_cidoer_print; }
  declare -F "do_file_diff" >/dev/null && return 0
  do_file_diff() {
    command -v diff >/dev/null 2>&1 || {
      do_print_error "Command diff is not available."
      return 3
    }
    command -v awk >/dev/null 2>&1 || {
      do_print_error "Command awk is not available."
      return 3
    }
    local file1 file2
    read -r file1 <<<"$(printf '%q' "${1:-}")" || {
      do_print_error 'Failed to escape file1.'
      return 3
    }
    read -r file2 <<<"$(printf '%q' "${2:-}")" || {
      do_print_error 'Failed to escape file2.'
      return 3
    }
    do_print_trace "$(do_stack_trace)" "<$file1>" "<$file2>"
    [ ! -f "$file1" ] && file1='/dev/null'
    [ ! -f "$file2" ] && file2='/dev/null'
    do_print_with_color && {
      local -r color_r="${CIDOER_COLOR_RED:-$(do_lookup_color red)}"
      local -r color_g="${CIDOER_COLOR_GREEN:-$(do_lookup_color green)}"
      local -r reset="${CIDOER_COLOR_RESET:-$(do_lookup_color reset)}"
    }
    diff -U0 "$file1" "$file2" | awk "
      /^@/ {
        split(\$0, parts,    \" \")
        split(parts[2], old, \",\")
        split(parts[3], new, \",\")
        old_line = substr(old[1], 2)
        new_line = substr(new[1], 2)
        next
      }
      /^-/  { printf \"${color_r:-}-|%03d| %s${reset:-}\n\", old_line++, substr(\$0,2) }
      /^\+/ { printf \"${color_g:-}+|%03d| %s${reset:-}\n\", new_line++, substr(\$0,2) }
    "
    local -r diff_status="${PIPESTATUS[0]}"
    [ "$diff_status" -ne 0 ] && [ "$diff_status" -ne 1 ] && {
      do_print_error 'diff command failed with status' "$diff_status"
      return "$diff_status"
    }
    return "$diff_status"
  }
  do_file_replace() {
    local found_ok='false' found_value=''
    _find_value() {
      local key="${1:-}"
      local -i i
      found_ok='false'
      while [ "${key:0:1}" = '$' ]; do key="${key:1}"; done
      [[ "$key" =~ ^[a-zA-Z_-][a-zA-Z0-9_-]*$ ]] || {
        found_ok='false'
        return 0
      }
      for ((i = 0; i < ${#map_keys[@]}; i++)); do
        [ "$key" = "${map_keys[i]}" ] && {
          found_value="${map_vals[$i]}"
          found_ok='true'
          return 0
        }
      done
      _find_var "$key"
    }
    _find_var() {
      local -r key="${1:-}"
      [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || {
        found_ok='false'
        return 0
      }
      if [ -z "${!key+x}" ]; then
        found_ok='false'
      elif [ -z "${!key}" ]; then
        found_ok='true'
      else
        found_value="${!key}"
        found_ok='true'
      fi
    }
    _index_of_char() {
      local str="$1" char="$2" i=0
      while [ $i -lt ${#str} ]; do
        local c="${str:$i:1}"
        [ "$c" = "$char" ] && {
          printf '%d' $i
          return 0
        }
        i=$((i + 1))
      done
      printf '%d' -1
    }
    _replace() {
      local open_char="$1" close_char="$2"
      local line
      while IFS= read -r line || [ -n "$line" ]; do
        local result=""
        local offset=0
        local length=${#line}
        while [ $offset -lt "$length" ]; do
          local c="${line:$offset:1}"
          if [ "$c" = "$open_char" ]; then
            local close_index rest="${line:$((offset + 1))}"
            close_index=$(_index_of_char "$rest" "$close_char")
            if [ "$close_index" -lt 0 ]; then
              result="${result}${line:offset}"
              break
            else
              local key="${rest:0:$close_index}"
              _find_value "$key"
              found_value=$(bash -c "printf '%s' \"$found_value\"")
              if [ "$found_ok" = "true" ]; then
                result="${result}${found_value}"
                offset=$((offset + close_index + 2))
              else
                result="${result}${open_char}"
                offset=$((offset + 1))
              fi
            fi
          else
            local next_open rest="${line:$offset}"
            next_open=$(_index_of_char "$rest" "$open_char")
            if [ "$next_open" -lt 0 ]; then
              result="${result}${rest}"
              break
            else
              result="${result}${rest:0:$next_open}"
              offset=$((offset + next_open))
            fi
          fi
        done
        printf '%s\n' "$result"
      done
    }
    open_char="$1" close_char="$2"
    shift 2
    local kv key map_keys=() map_vals=()
    for kv in "$@"; do
      key="${kv%%=*}"
      while [ "${key:0:1}" = '$' ]; do key="${key:1}"; done
      map_keys+=("$key")
      map_vals+=("${kv#*=}")
    done
    _replace "$open_char" "$close_char"
  }
}

define_cidoer_git() {
  declare -F '_print_defined' >/dev/null || { declare -F 'define_cidoer_print' >/dev/null && define_cidoer_print; }
  declare -F "do_git_version_tag" >/dev/null && return 0
  do_git_version_tag() {
    local -r exact=$(git tag --points-at HEAD 2>/dev/null | grep -E '^[Vv]?[0-9]+' | sort -V | tail -n1)
    [ -n "$exact" ] && printf '%s' "$exact" && return 0
    local -r latest=$(git tag --merged HEAD 2>/dev/null | grep -E '^[Vv]?[0-9]+' | sort -V | tail -n1)
    [ -n "$latest" ] && printf '%s' "$latest"
  }
  do_git_count_commits_since() {
    if [ ${#} -le 0 ] || [ -z "$1" ]; then
      printf '%s' "$(git rev-list HEAD --count 2>/dev/null)"
    else
      printf '%s' "$(git rev-list "${1}"..HEAD --count 2>/dev/null)"
    fi
  }
  do_git_short_commit_hash() {
    printf '%s' "$(git rev-parse --short HEAD 2>/dev/null)"
  }
  do_git_diff() {
    git diff --quiet || return $?
    git diff --cached --quiet || return $?
    return 0
  }
  do_git_version_next() {
    local -r tag=$(do_git_version_tag)
    local count
    count=$(do_git_count_commits_since "$tag")
    do_git_diff || count=$((count + 1))
    [ "$count" -gt 0 ] && local -r ver="${tag:-0}.$count"
    local result="${ver:-${tag:-0}}"
    [[ $result =~ ^v[0-9]+ ]] && result="${result#v}"
    printf '%s' "$result"
  }
}

define_cidoer_http() {
  declare -F '_print_defined' >/dev/null || { declare -F 'define_cidoer_print' >/dev/null && define_cidoer_print; }
  declare -F "do_http_fetch" >/dev/null && return 0
  do_http_fetch() {
    local address="${1:?Usage: do_http_fetch <URL> [output]}"
    local output="${2:-}"
    local tries="${CIDOER_FETCH_RETRIES:-2}"
    local waitretry="${CIDOER_FETCH_WAIT_RETRY:-1}"
    local timeout="${CIDOER_FETCH_TIMEOUT:-20}"
    command -v wget >/dev/null 2>&1 && {
      [ -z "$output" ] && {
        wget -q --tries="$tries" --timeout="$timeout" -O - "$address" || return $?
        return 0
      }
      wget -q --tries="$tries" --timeout="$timeout" -O "$output" "$address" || return $?
      return 0
    }
    command -v curl >/dev/null 2>&1 && {
      [ -z "$output" ] && {
        curl -fsSL --retry "$tries" --retry-delay "$waitretry" --max-time "$timeout" "$address" || return $?
        return 0
      }
      curl -fsSL --retry "$tries" --retry-delay "$waitretry" --max-time "$timeout" "$address" -o "$output" || return $?
      return 0
    }
    do_print_error "$(do_stack_trace)" "Error: Neither 'wget' nor 'curl' is installed." >&2
    return 2
  }
}

export CIDOER_DIR="${CIDOER_DIR:-$(realpath "$(dirname "${BASH_SOURCE[0]}")")}"
export CIDOER_CORE_FILE="${CIDOER_CORE_FILE:-"${CIDOER_DIR:-}"/cidoer.core.sh}"
declare -F 'define_cidoer_print' >/dev/null || {
  [ -n "${CIDOER_DIR:-}" ] && [ -f "$CIDOER_DIR"/cidoer.print.sh ] && . "$CIDOER_DIR"/cidoer.print.sh
}
define_cidoer_core
do_check_bash_3_2 || {
  printf 'Error: This script requires Bash 3.2 or newer.\n' >&2
  exit 32
}
do_check_bats_core || do_print_trace "$(do_reverse "${BASH_SOURCE[@]}")"
define_cidoer_lock
define_cidoer_file
define_cidoer_git
define_cidoer_http
