#!/usr/bin/env bash
# shellcheck disable=SC2317
declare -F 'define_cidoer_core' >/dev/null && return 0
set -eu -o pipefail

define_core_utils() {
  declare -F 'do_workflow_job' >/dev/null && return 0
  if [ "${BASH_VERSINFO:-0}" -lt 3 ] || [ "${BASH_VERSINFO[0]:-0}" -lt 3 ] || {
    [ "${BASH_VERSINFO[0]}" -eq 3 ] && [ "${BASH_VERSINFO[1]}" -lt 2 ]
  }; then
    printf 'Error: This script requires Bash 3.2 or newer.' >&2
    exit 32
  fi
  define_cidoer_core
  define_cidoer_lock
  define_cidoer_file
  define_cidoer_git
  define_cidoer_http
  define_cidoer_check
}

define_cidoer_core() {
  do_nothing() { :; }
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
    [ ${#steps[@]} -le 0 ] && steps+=('do')
    local -r upper=$(printf '%s' "$job_type" | tr '[:lower:]' '[:upper:]')
    local -r lower=$(printf '%s' "$job_type" | tr '[:upper:]' '[:lower:]')
    do_print_section "${upper} JOB BEGIN"
    do_func_invoke "define_${lower}" || return $?
    for step in "${steps[@]}"; do do_func_invoke "${lower}_${step}" || return $?; done
    do_print_section "${upper} JOB DONE!" && printf '\n'
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
      "$func_finally" "$status" || local -r code=$?
      [ "${code:-0}" -eq 0 ] || do_print_warn "$(do_stack_trace)" "$func_finally failed with exit code $code" >&2
      return "${code:-0}"
    }
    [ "${status:-0}" -eq 0 ] || do_print_warn "$(do_stack_trace)" "$func_name failed with exit code $status" >&2
    return "${status:-0}"
  }
  do_os_type() {
    [ -n "${CIDOER_OS_TYPE:-}" ] && {
      printf '%s\n' "$CIDOER_OS_TYPE"
      return 0
    }
    if [ -z "${OSTYPE:-}" ]; then
      command -v uname >/dev/null 2>&1 && local -r os="$(uname -s)"
    else local -r os="${OSTYPE:-}"; fi
    local -r type="$(printf '%s' "$os" | tr '[:upper:]' '[:lower:]')"
    case "${type:-}" in
    linux*) CIDOER_OS_TYPE='linux' ;;
    darwin*) CIDOER_OS_TYPE='darwin' ;;
    cygwin* | msys* | mingw* | windows*) CIDOER_OS_TYPE='windows' ;;
    *) CIDOER_OS_TYPE='unknown' ;;
    esac
    printf '%s\n' "$CIDOER_OS_TYPE"
  }
  do_host_type() {
    [ -n "${CIDOER_HOST_TYPE:-}" ] && {
      printf '%s\n' "$CIDOER_HOST_TYPE"
      return 0
    }
    if [ -z "${HOSTTYPE:-}" ]; then
      command -v uname >/dev/null 2>&1 && local -r host="$(uname -m)"
    else local -r host="${HOSTTYPE:-}"; fi
    local -r type="$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')"
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
  do_time_now() { command -v date >/dev/null 2>&1 && printf '%s\n' "$(date +"%Y-%m-%d %T %Z")"; }
  do_trim() {
    local var="${1:-}"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
  }
  do_stack_trace() {
    local idx filtered_fns=()
    for ((idx = ${#FUNCNAME[@]} - 2; idx > 0; idx--)); do
      [ 'do_func_invoke' != "${FUNCNAME[$idx]}" ] && filtered_fns+=("${FUNCNAME[$idx]}")
    done
    if [ ${#filtered_fns[@]} -gt 0 ]; then
      printf '%s --> %s\n' "${USER:-$(id -un)}@${HOSTNAME:-$(hostname)}" "${filtered_fns[*]}"
    else printf '%s -->\n' "${USER:-$(id -un)}@${HOSTNAME:-$(hostname)}"; fi
  }
  do_print_trace() { do_tint blue "${@}"; }
  do_print_info() { do_tint cyan "${@}"; }
  do_print_warn() { do_tint yellow "${@}"; }
  do_print_error() { do_tint bold black on_red "${@}"; }
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
  do_print_os_env() {
    local key value
    while IFS='=' read -r key value; do
      do_print_dash_pair "$key" "$value"
    done < <(printenv)
  }
  do_print_dash_pair() {
    local -r dashes='------------------------------------'
    [ ${#} -gt 1 ] && {
      printf "%s %s [%s]\n" "$(do_tint green "${1}")" "$(do_tint white "${dashes:${#1}}")" "$(do_tint green "${2}")"
      return 0
    }
    [ ${#} -gt 0 ] && {
      printf "%s < %s >\n" "$(do_tint white "${dashes}-")" "$(do_tint white "${1}")"
      return 0
    }
    do_tint white "${dashes}${dashes}"
  }
  do_print_section() {
    local -r line='==============================================================================='
    [ ${#} -le 0 ] && {
      do_tint bold cyan "=${line} $(do_time_now)"
      return 0
    }
    local -r title=$(do_trim "${*}")
    [ -n "${title}" ] && do_tint bold cyan "${title} ${line:${#title}} $(do_time_now)"
  }
  do_print_debug() {
    [ "${CIDOER_DEBUG:-no}" != "yes" ] && return 0
    do_print_code_lines "$@" >&2
  }
  do_print_code_bash_fn() { do_print_code_bash "$(declare -f "$@")"; }
  do_print_code_bash() {
    [ ${#CIDOER_TPUT_COLORS[@]} -gt 0 ] && command -v bat >/dev/null 2>&1 && {
      do_print_code_lines 'bash' "$@"
      return 0
    }
    do_print_code_lines "$@"
  }
  do_print_code_lines() {
    [ "$#" -le 0 ] && return 0
    local -r stack="$(do_stack_trace)"
    do_tint magenta '#---|--------------------' "${stack}"
    [ ${#CIDOER_TPUT_COLORS[@]} -gt 0 ] && command -v bat >/dev/null 2>&1 && {
      local -r lang="$1" && shift
      local -r code_block="$*"
      bat --language "$lang" --paging never --number <<<"${code_block}"
      do_tint magenta '#---|--------------------' "${stack}"
      return 0
    }
    local arg line i=1
    for arg in "$@"; do
      while IFS= read -r line; do
        do_tint magenta "$(printf '#%3d|' "$i")" "$line"
        i=$((i + 1))
      done <<<"$arg"
    done
    do_tint magenta '#---|--------------------' "${stack}"
  }
  do_tint() {
    [ "$#" -le 0 ] && return 0
    local -ra args=("$@")
    local code i=0 styles=''
    while [ "$i" -lt "${#args[@]}" ]; do
      case "${args[$i]}" in
      '\E['*m | '\e['*m | '\033['*m)
        styles+="${args[$i]}"
        i=$((i + 1))
        ;;
      bold | dim | underline | blink | reverse | hidden | \
        black | red | green | yellow | blue | magenta | cyan | white | \
        on_black | on_red | on_green | on_yellow | on_blue | on_magenta | on_cyan | on_white)
        code=$(do_lookup_color "${args[$i]}")
        [ -n "$code" ] && styles+="$code"
        i=$((i + 1))
        ;;
      *) break ;;
      esac
    done
    local -ra messages=("${args[@]:$i}")
    [ ${#messages[@]} -eq 0 ] && return 0
    [ -z "$styles" ] && {
      printf "%s\n" "${messages[*]}"
      return 0
    }
    [ -z "${_CIDOER_TPUT_COLORS_CLEAR:-}" ] && _CIDOER_TPUT_COLORS_CLEAR=$(do_lookup_color reset)
    local -r styles_clear="${_CIDOER_TPUT_COLORS_CLEAR:=\033[0m}"
    printf "$styles%s$styles_clear\n" "${messages[*]}"
  }
  declare -x _CIDOER_TPUT_COLORS_CLEAR
  do_lookup_color() {
    [ "${#CIDOER_TPUT_COLORS[@]}" -eq 0 ] && return 0
    [ "$#" -le 0 ] || [ -z "$1" ] && {
      printf $'do_lookup_color $1 (color) is required\n' >&2
      return 1
    }
    local key=${1} color
    for color in "${CIDOER_TPUT_COLORS[@]}"; do
      case "$color" in
      "$key="*)
        printf '%s' "${color#*=}"
        return 0
        ;;
      esac
    done
  }
  do_reset_tput() {
    if command -v tput >/dev/null 2>&1; then
      if tput -T xterm-256color colors >/dev/null 2>&1; then
        local -r tp_args='-T xterm-256color'
      elif tput -T xterm colors >/dev/null 2>&1; then
        local -r tp_args='-T xterm'
      fi
      local -r tp_cmd="tput ${tp_args:-}"
      local -r tp_colors=$($tp_cmd colors 2>/dev/null || printf '0')
    fi
    CIDOER_TPUT_COLORS=()
    if [ "${tp_colors:-0}" -gt 0 ]; then
      CIDOER_TPUT_COLORS=(
        "reset=$($tp_cmd sgr0)"
        "black=$($tp_cmd setaf 0)"
        "red=$($tp_cmd setaf 1)"
        "green=$($tp_cmd setaf 2)"
        "yellow=$($tp_cmd setaf 3)"
        "blue=$($tp_cmd setaf 4)"
        "magenta=$($tp_cmd setaf 5)"
        "cyan=$($tp_cmd setaf 6)"
        "white=$($tp_cmd setaf 7)"
        "on_black=$($tp_cmd setab 0)"
        "on_red=$($tp_cmd setab 1)"
        "on_green=$($tp_cmd setab 2)"
        "on_yellow=$($tp_cmd setab 3)"
        "on_blue=$($tp_cmd setab 4)"
        "on_magenta=$($tp_cmd setab 5)"
        "on_cyan=$($tp_cmd setab 6)"
        "on_white=$($tp_cmd setab 7)"
        "bold=$($tp_cmd bold)"
        "dim=$($tp_cmd dim)"
        "underline=$($tp_cmd smul)"
        "blink=$($tp_cmd blink)"
        "reverse=$($tp_cmd rev)"
        "hidden=$($tp_cmd invis)"
      )
    fi
    if [ ${#CIDOER_TPUT_COLORS[@]} -eq 0 ]; then
      CIDOER_TPUT_COLORS=(
        "reset=\033[0m"
        "black=\033[30m"
        "red=\033[31m"
        "green=\033[32m"
        "yellow=\033[33m"
        "blue=\033[34m"
        "magenta=\033[35m"
        "cyan=\033[36m"
        "white=\033[37m"
        "on_black=\033[40m"
        "on_red=\033[41m"
        "on_green=\033[42m"
        "on_yellow=\033[43m"
        "on_blue=\033[44m"
        "on_magenta=\033[45m"
        "on_cyan=\033[46m"
        "on_white=\033[47m"
        "bold=\033[1m"
        "dim=\033[2m"
        "underline=\033[4m"
        "blink=\033[5m"
        "reverse=\033[7m"
        "hidden=\033[8m"
      )
    fi
  }
  do_reset_tput
}

define_cidoer_lock() {
  declare -F 'do_lock_release' >/dev/null && return 0
  [ -z "${CIDOER_LOCK_BASE_DIR:-}" ] && {
    CIDOER_LOCK_BASE_DIR='/cidoer/locks'
    mkdir -p "/tmp$CIDOER_LOCK_BASE_DIR"
  }
  [ -z "${CIDOER_LOCK_METHOD:-}" ] && {
    if command -v flock >/dev/null 2>&1; then
      CIDOER_LOCK_METHOD="flock"
    elif command -v lockf >/dev/null 2>&1; then
      CIDOER_LOCK_METHOD="lockf"
    else
      CIDOER_LOCK_METHOD="mkdir"
    fi
  }
  do_lock_release() {
    local -r lock_path="/tmp$CIDOER_LOCK_BASE_DIR/${1:-}"
    [ -f "$lock_path/pid" ] && {
      do_print_trace "Release lock on '${1:-}'"
      rm -f "$lock_path/pid" || do_print_trace "Failed to remove pid file:" "$lock_path/pid"
    }
    [ -d "$lock_path" ] && {
      rmdir "$lock_path" 2>/dev/null || do_print_trace "Failed to remove directory:" "$lock_path"
    }
    { exec 200>&-; } 2>/dev/null
    { exec 201>&-; } 2>/dev/null
  }
  do_lock_acquire() {
    local -r lock_path="/tmp$CIDOER_LOCK_BASE_DIR/${1:-}"
    local -r lock_dir="${1:-}"
    local -i -r max_attempts="${2:-20}"
    _input_lock_dir="$lock_dir"
    _lock_release_on_sig() {
      do_lock_release "${_input_lock_dir:-}"
    }
    trap _lock_release_on_sig EXIT INT TERM
    local -r pid_file="$lock_path/pid"
    local -i pid attempt=1 lock_acquired=0
    local -r try_func="do_lock_try_${CIDOER_LOCK_METHOD:-mkdir}"
    while [ "$attempt" -le "$max_attempts" ] && [ "$lock_acquired" -eq 0 ]; do
      [ -d "$lock_path" ] && [ -f "$pid_file" ] && {
        pid="$(cat "$pid_file" 2>/dev/null)"
        [[ "$pid" =~ ^[0-9]+$ ]] && ! kill -0 "$pid" 2>/dev/null && do_lock_release "${lock_dir:-}"
      }
      do_print_trace "Try to lock '$lock_dir' with" "$try_func". "[$attempt/$max_attempts]"
      if "$try_func" "${lock_dir:-}"; then
        lock_acquired=1
        break
      fi
      sleep $((attempt < 5 ? 1 : 3))
      attempt=$((attempt + 1))
    done
    [ "$lock_acquired" -eq 1 ] && return 0 || return 1
  }
  do_lock_try_flock() {
    local -r lock_path="/tmp$CIDOER_LOCK_BASE_DIR/${1:-}"
    command -v flock >/dev/null 2>&1 || return 1
    mkdir -p "$lock_path" 2>/dev/null || return 1
    { exec 200>"$lock_path/pid"; } 2>/dev/null || return 1
    flock -n 200 2>/dev/null && {
      printf '%s\n' "$$" >"$lock_path/pid"
      return 0
    }
    { exec 200>&-; } 2>/dev/null
    return 1
  }
  do_lock_try_lockf() {
    local -r lock_path="/tmp$CIDOER_LOCK_BASE_DIR/${1:-}"
    command -v lockf >/dev/null 2>&1 || return 1
    mkdir -p "$lock_path" 2>/dev/null || return 1
    { exec 201>"$lock_path/pid"; } 2>/dev/null || return 1
    lockf -t 0 201 2>/dev/null && {
      printf '%s\n' "$$" >"$lock_path/pid"
      return 0
    }
    { exec 201>&-; } 2>/dev/null
    return 1
  }
  do_lock_try_mkdir() {
    local -r lock_path="/tmp$CIDOER_LOCK_BASE_DIR/${1:-}"
    mkdir "$lock_path" 2>/dev/null && {
      printf '%s\n' "$$" >"$lock_path/pid"
      return 0
    }
    return 1
  }
}

define_cidoer_file() {
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
    local color_r color_g reset
    color_r="$(do_lookup_color red)"
    color_g="$(do_lookup_color green)"
    reset="$(do_lookup_color reset)"
    diff -U0 "$file1" "$file2" | awk "
      /^@/ {
        split(\$0, parts,    \" \")
        split(parts[2], old, \",\")
        split(parts[3], new, \",\")
        old_line = substr(old[1], 2)
        new_line = substr(new[1], 2)
        next
      }
      /^-/  { printf \"$color_r-|%03d| %s$reset\n\", old_line++, substr(\$0,2) }
      /^\+/ { printf \"$color_g+|%03d| %s$reset\n\", new_line++, substr(\$0,2) }
    "
    local diff_status="${PIPESTATUS[0]}"
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
  do_git_version_tag() {
    local cmd
    for cmd in git grep sort tail; do
      command -v "$cmd" >/dev/null 2>&1 || {
        do_print_warn 'WARNING: Required command is missing:' " $cmd" >&2
        return 0
      }
    done
    local -r exact=$(git tag --points-at HEAD 2>/dev/null | grep -E '^[Vv]?[0-9]+' | sort -V | tail -n1)
    [ -n "$exact" ] && {
      printf '%s' "$exact"
      return 0
    }
    local -r latest=$(git tag --merged HEAD 2>/dev/null | grep -E '^[Vv]?[0-9]+' | sort -V | tail -n1)
    [ -n "$latest" ] && printf '%s' "${latest}"
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
}

define_cidoer_http() {
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

define_cidoer_check() {
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
    do_print_dash_pair 'Optional Commands'
    local cmd
    for cmd in "${@}"; do
      if ! do_check_installed "$cmd"; then
        do_print_dash_pair "${cmd}" ''
      fi
    done
  }
  do_check_required_cmd() {
    do_print_dash_pair 'Required Commands'
    local cmd
    local missing=0
    for cmd in "${@}"; do
      if ! do_check_installed "$cmd"; then
        do_print_dash_pair "${cmd}" "$(do_tint red missing)"
        missing=1
      fi
    done
    if [ "$missing" -eq 1 ]; then
      do_print_error 'Please install the missing required commands and try again later.'
      return 1
    fi
  }
  do_core_check_dependencies() {
    do_check_optional_cmd tput bat git curl wget flock lockf
    do_check_required_cmd printenv awk diff || return $?
  }
}

declare -a CIDOER_TPUT_COLORS
declare CIDOER_DEBUG
declare CIDOER_OS_TYPE
declare CIDOER_HOST_TYPE
declare CIDOER_LOCK_BASE_DIR
declare CIDOER_LOCK_METHOD

define_core_utils
