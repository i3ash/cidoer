#!/usr/bin/env bash
# shellcheck disable=SC2317
if declare -F 'define_core_utils' >/dev/null; then return 0; fi
set -eou pipefail

define_core_utils() {
  if declare -F 'do_nothing' >/dev/null; then return 0; fi
  do_nothing() { :; }
  do_check_core_dependencies() {
    do_check_optional_cmd uname date tput bat git grep sort tail curl wget flock lockf
    do_check_required_cmd id hostname printenv tr awk diff rm rmdir
  }
  do_workflow_job() {
    local job_type
    job_type=$(do_trim "$1")
    if ! [[ "$job_type" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
      do_print_warn "$(do_stack_trace)" $'$1 (job_type) is not a valid format'
      return 1
    fi
    local upper lower
    upper=$(printf '%s' "$job_type" | tr '[:lower:]' '[:upper:]')
    lower=$(printf '%s' "$job_type" | tr '[:upper:]' '[:lower:]')
    do_print_section "${upper} JOB BEGIN"
    do_func_invoke "define_${lower}"
    local args=("$@")
    local arg step i=0
    for arg in "${args[@]:1}"; do
      step=$(do_trim "$arg")
      if [[ -n "$step" ]] && [[ "$step" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        do_func_invoke "${lower}_${step}"
        i=$((i + 1))
      fi
    done
    if [ $i -eq 0 ]; then do_func_invoke "${lower}_do"; fi
    do_print_section "${upper} JOB DONE!" && printf '\n'
  }
  do_os_type() {
    if [ -n "${CIDOER_OS_TYPE:-}" ]; then
      printf '%s' "$CIDOER_OS_TYPE"
      return 0
    fi
    local system
    if [ -n "${OSTYPE:-}" ]; then
      system="${OSTYPE:-}"
    else
      if command -v uname >/dev/null 2>&1; then system="$(uname -s | tr '[:upper:]' '[:lower:]')"; fi
    fi
    case "$system" in
    linux*) system='linux' ;;
    darwin*) system='darwin' ;;
    cygwin* | msys* | mingw* | windows*) system='windows' ;;
    *) system='unknown' ;;
    esac
    CIDOER_OS_TYPE="${system}"
    printf '%s' "$CIDOER_OS_TYPE"
  }
  do_host_type() {
    if [ -n "${CIDOER_HOST_TYPE:-}" ]; then
      printf '%s' "$CIDOER_HOST_TYPE"
      return 0
    fi
    local arch type
    if [ -n "${HOSTTYPE:-}" ]; then
      arch="${HOSTTYPE:-}"
    else
      if command -v uname >/dev/null 2>&1; then arch="$(uname -m)"; fi
    fi
    arch="$(printf '%s' "$arch" | tr '[:upper:]' '[:lower:]')"
    case "$arch" in
    x86_64 | amd64 | x64) type='x86_64' ;;
    i*86 | x86) type='x86' ;;
    arm64 | aarch64) type='arm64' ;;
    armv5* | armv6* | armv7* | aarch32) type='arm' ;;
    armv8*) type="$arch" ;;
    ppc | powerpc) type='ppc' ;;
    ppc64 | ppc64le) type="$arch" ;;
    mips | mips64 | mipsle | mips64le | s390x | riscv64) type="$arch" ;;
    *) type='unknown' ;;
    esac
    CIDOER_HOST_TYPE="$type"
    printf '%s' "$CIDOER_HOST_TYPE"
  }
  do_git_version_tag() {
    local cmd
    for cmd in git grep sort tail; do
      if ! command -v "$cmd" >/dev/null 2>&1; then
        do_print_warn 'WARNING: Required command is missing:' " $cmd" >&2
        return 0
      fi
    done
    local exact latest
    exact=$(git tag --points-at HEAD 2>/dev/null | grep -E '^[Vv]?[0-9]+' | sort -V | tail -n1)
    if [ -n "$exact" ]; then
      printf '%s' "$exact"
    else
      latest=$(git tag --merged HEAD 2>/dev/null | grep -E '^[Vv]?[0-9]+' | sort -V | tail -n1)
      if [ -n "$latest" ]; then printf '%s' "${latest}"; fi
    fi
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
  do_stack_trace() {
    local idx filtered_fns=()
    for ((idx = ${#FUNCNAME[@]} - 2; idx > 0; idx--)); do
      if [ 'do_func_invoke' != "${FUNCNAME[$idx]}" ]; then
        filtered_fns+=("${FUNCNAME[$idx]}")
      fi
    done
    if [ ${#filtered_fns[@]} -gt 0 ]; then
      printf '%s --> %s\n' "${USER:-$(id -un)}@${HOSTNAME:-$(hostname)}" "${filtered_fns[*]}"
    else printf '%s -->\n' "${USER:-$(id -un)}@${HOSTNAME:-$(hostname)}"; fi
  }
  do_time_now() {
    if command -v date >/dev/null 2>&1; then printf '%s' "$(date +"%Y-%m-%d %T %Z")"; fi
  }
  do_func_invoke() {
    if [ "$#" -le 0 ] || [ -z "$1" ]; then
      do_print_warn "$(do_stack_trace)" $'$1 (func_name) is required' >&2
      return 0
    fi
    local func_name="${1}"
    if declare -F "${func_name}" >/dev/null; then
      local exit_code=0
      "${@}" || exit_code=$?
      if [ "${exit_code}" -ne 0 ]; then
        do_print_warn "$(do_stack_trace)" "${func_name} failed with exit code ${exit_code}" >&2
      fi
    else do_print_trace "$(do_stack_trace)" "${func_name} is an absent function" >&2; fi
  }
  do_trim() {
    local var="${1:-}"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
  }
  do_print_variable() {
    if [ "$#" -le 0 ]; then return 0; fi
    local prefix="$1" name="$2" suffix="$3"
    local candidates=(
      "${prefix}${name}${suffix}" "${prefix}${name}" "${name}${suffix}" "${name}"
    )
    local value='' candidate=''
    set +u
    for candidate in "${candidates[@]}"; do
      value="${!candidate}"
      if [ -n "$value" ]; then break; fi
    done
    set -u
    local trimmed="${value#"${value%%[![:space:]]*}"}"
    printf '%s' "${trimmed%"${trimmed##*[![:space:]]}"}"
  }
  do_print_trace() { printf "%s\n" "$(do_tint blue "${@}")"; }
  do_print_info() { printf "%s\n" "$(do_tint cyan "${@}")"; }
  do_print_warn() { printf "%s\n" "$(do_tint yellow "${@}")"; }
  do_print_error() { printf "%s\n" "$(do_tint bold black on_red "${@}")"; }
  do_print_colorful() { printf "%s\n" "$(do_tint "${@}")"; }
  do_print_os_env() {
    local key value
    while IFS='=' read -r key value; do
      do_print_dash_pair "$key" "$value"
    done < <(printenv)
  }
  do_print_dash_pair() {
    local dashes='------------------------------------'
    if [ ${#} -gt 1 ]; then
      printf "%s %s [%s]\n" "$(do_tint green "${1}")" \
        "$(do_tint white "${dashes:${#1}}")" "$(do_tint green "${2}")"
    elif [ ${#} -gt 0 ]; then
      printf "%s < %s >\n" "$(do_tint white "${dashes}-")" "$(do_tint white "${1}")"
    else
      printf "%s\n" "$(do_tint white "${dashes}${dashes}")"
    fi
  }
  do_print_section() {
    local title line='==============================================================================='
    if [ ${#} -le 0 ]; then
      printf "%s\n" "$(do_tint bold cyan "=${line} $(do_time_now)")"
      return
    fi
    title=$(do_trim "${*}")
    if [ -n "${title}" ]; then
      printf "%s\n" "$(do_tint bold cyan "${title} ${line:${#title}} $(do_time_now)")"
    fi
  }
  do_print_debug() {
    if [ "${CIDOER_DEBUG:-no}" != "yes" ]; then return 0; fi
    do_print_code_lines "$@" >&2
  }
  do_print_code_bash_fn() { do_print_code_bash "$(declare -f "$@")"; }
  do_print_code_bash() {
    if command -v bat >/dev/null 2>&1 && [ -n "${CIDOER_TPUT_COLORS:-}" ]; then
      do_print_code_lines 'bash' "$@"
    else do_print_code_lines "$@"; fi
  }
  do_print_code_lines() {
    if [ "$#" -le 0 ]; then return 0; fi
    local stack=''
    stack="$(do_stack_trace)"
    printf "%s\n" "$(do_tint magenta '#---|--------------------' "${stack}")"
    if command -v bat >/dev/null 2>&1 && [ -n "${CIDOER_TPUT_COLORS:-}" ]; then
      local lang="$1"
      shift
      local code_block="$*"
      bat --language "$lang" --paging never --number <<<"${code_block}"
    else
      local arg line i=1
      for arg in "$@"; do
        while IFS= read -r line; do
          printf "%s\n" "$(do_tint magenta "$(printf '#%3d|' "$i")" "$line")"
          i=$((i + 1))
        done <<<"$arg"
      done
    fi
    printf "%s\n" "$(do_tint magenta '#---|--------------------' "${stack}")"
  }
  declare -x _CIDOER_TPUT_COLORS_CLEAR
  do_tint() {
    if [ "$#" -le 0 ]; then return 0; fi
    if [ -z "${_CIDOER_TPUT_COLORS_CLEAR:-}" ]; then
      _CIDOER_TPUT_COLORS_CLEAR=$(do_lookup_color reset)
    fi
    local styles_clear="${_CIDOER_TPUT_COLORS_CLEAR}"
    local args=("$@") code i=0 styles=''
    while [ "$i" -lt "${#args[@]}" ]; do
      case "${args[$i]}" in bold | dim | underline | blink | reverse | hidden | \
        black | red | green | yellow | blue | magenta | cyan | white | \
        on_black | on_red | on_green | on_yellow | on_blue | on_magenta | on_cyan | on_white)
        code=$(do_lookup_color "${args[$i]}")
        if [ -n "$code" ]; then styles+="$code"; fi
        i=$((i + 1))
        ;;
      *) break ;;
      esac
    done
    local messages=("${args[@]:$i}")
    if [ ${#messages[@]} -eq 0 ]; then return; fi
    printf "$styles%s$styles_clear" "${messages[*]}"
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
  do_diff() {
    if ! command -v diff >/dev/null 2>&1; then
      do_print_error "Command diff is not available."
      return 3
    fi
    if ! command -v awk >/dev/null 2>&1; then
      do_print_error "Command awk is not available."
      return 3
    fi
    local file1 file2
    set +u
    if ! read -r file1 <<<"$(printf '%q' "$1")"; then
      do_print_error 'Failed to escape file1.'
      return 3
    fi
    if ! read -r file2 <<<"$(printf '%q' "$2")"; then
      do_print_error 'Failed to escape file2.'
      return 3
    fi
    set -u
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
    if [ "$diff_status" -ne 0 ] && [ "$diff_status" -ne 1 ]; then
      do_print_error 'diff command failed with status' "$diff_status"
      return "$diff_status"
    fi
    return "$diff_status"
  }
  do_lookup_color() {
    if [ -z "${CIDOER_TPUT_COLORS:-}" ]; then return 0; fi
    if [ "$#" -le 0 ] || [ -z "$1" ]; then
      printf $'do_lookup_color $1 (color) is required\n' >&2
      return 1
    fi
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
    CIDOER_TPUT_COLORS=()
    if command -v tput >/dev/null 2>&1; then
      local tp_cmd colors
      tp_cmd='tput'
      if tput -T xterm-256color colors >/dev/null 2>&1; then
        tp_cmd='tput -T xterm-256color'
      elif tput -T xterm colors >/dev/null 2>&1; then
        tp_cmd='tput -T xterm'
      fi
      colors=$($tp_cmd colors 2>/dev/null || printf '0')
      if [ "$colors" -gt 0 ]; then
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
    fi
    if [ ${#CIDOER_TPUT_COLORS[@]} -le 0 ]; then
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
  do_replace() {
    local found_ok='false' found_value=''
    _find_value() {
      local key="$1" i
      found_ok='false'
      while [ "${key:0:1}" = '$' ]; do key="${key:1}"; done
      for ((i = 0; i < ${#map_keys[@]}; i++)); do
        if [ "$key" = "${map_keys[i]}" ]; then
          found_value="${map_vals[i]}"
          found_ok='true'
          return
        fi
      done
      _find_var "$1"
    }
    _find_var() {
      local key="$1"
      while [ "${key:0:1}" = '$' ]; do key="${key:1}"; done
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
        if [ "$c" = "$char" ]; then
          printf '%d' $i
          return 0
        fi
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
  do_http_fetch() {
    local address="${1:?Usage: do_http_fetch <URL> [output]}"
    local output="${2:-}"
    local tries="${CIDOER_FETCH_RETRIES:-2}"
    local waitretry="${CIDOER_FETCH_WAIT_RETRY:-1}"
    local timeout="${CIDOER_FETCH_TIMEOUT:-20}"
    if command -v wget >/dev/null 2>&1; then
      if [ -n "$output" ]; then
        wget -q --tries="$tries" --timeout="$timeout" -O "$output" "$address" || {
          do_print_error "$(do_stack_trace)" "Error: wget failed." >&2
          return 1
        }
      else
        wget -q --tries="$tries" --timeout="$timeout" -O - "$address" || {
          do_print_error "$(do_stack_trace)" "Error: wget failed." >&2
          return 1
        }
      fi
    elif command -v curl >/dev/null 2>&1; then
      if [ -n "$output" ]; then
        curl -fsSL --retry "$tries" --retry-delay "$waitretry" --max-time "$timeout" "$address" -o "$output" || {
          do_print_error "$(do_stack_trace)" "Error: curl failed." >&2
          return 1
        }
      else
        curl -fsSL --retry "$tries" --retry-delay "$waitretry" --max-time "$timeout" "$address" || {
          do_print_error "$(do_stack_trace)" "Error: curl failed." >&2
          return 1
        }
      fi
    else
      do_print_error "$(do_stack_trace)" "Error: Neither 'wget' nor 'curl' is installed." >&2
      return 2
    fi
  }
  do_lock_try_flock() {
    local -r lock_path="/tmp$CIDOER_LOCK_BASE_DIR/${1:-}"
    command -v flock >/dev/null 2>&1 || return 1
    mkdir -p "$lock_path" 2>/dev/null || return 1
    { exec 200>"$lock_path/pid"; } 2>/dev/null || return 1
    if flock -n 200 2>/dev/null; then
      printf '%s\n' "$$" >"$lock_path/pid"
      return 0
    fi
    { exec 200>&-; } 2>/dev/null
    return 1
  }
  do_lock_try_lockf() {
    local -r lock_path="/tmp$CIDOER_LOCK_BASE_DIR/${1:-}"
    command -v lockf >/dev/null 2>&1 || return 1
    mkdir -p "$lock_path" 2>/dev/null || return 1
    { exec 201>"$lock_path/pid"; } 2>/dev/null || return 1
    if lockf -t 0 201 2>/dev/null; then
      printf '%s\n' "$$" >"$lock_path/pid"
      return 0
    fi
    { exec 201>&-; } 2>/dev/null
    return 1
  }
  do_lock_try_mkdir() {
    local -r lock_path="/tmp$CIDOER_LOCK_BASE_DIR/${1:-}"
    if mkdir "$lock_path" 2>/dev/null; then
      printf '%s\n' "$$" >"$lock_path/pid"
      return 0
    fi
    return 1
  }
  do_lock_release() {
    local -r lock_path="/tmp$CIDOER_LOCK_BASE_DIR/${1:-}"
    if [ -f "$lock_path/pid" ]; then
      do_print_trace "Release lock on '${1:-}'"
      rm -f "$lock_path/pid" || do_print_trace "Failed to remove pid file:" "$lock_path/pid"
    fi
    if [ -d "$lock_path" ]; then
      rmdir "$lock_path" 2>/dev/null || do_print_trace "Failed to remove directory:" "$lock_path"
    fi
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
      if [ -d "$lock_path" ] && [ -f "$pid_file" ]; then
        pid="$(cat "$pid_file" 2>/dev/null)"
        if [[ "$pid" =~ ^[0-9]+$ ]] && ! kill -0 "$pid" 2>/dev/null; then
          do_lock_release "${lock_dir:-}"
        fi
      fi
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
}

declare CIDOER_OS_TYPE=''
declare CIDOER_HOST_TYPE=''
declare CIDOER_DEBUG='no'
declare -a CIDOER_TPUT_COLORS=()

if command -v flock >/dev/null 2>&1; then
  declare -r CIDOER_LOCK_METHOD="flock"
elif command -v lockf >/dev/null 2>&1; then
  declare -r CIDOER_LOCK_METHOD="lockf"
else
  declare -r CIDOER_LOCK_METHOD="mkdir"
fi
declare -r CIDOER_LOCK_BASE_DIR='/cidoer/locks'
mkdir -p "/tmp$CIDOER_LOCK_BASE_DIR"

define_core_utils
if [ "${BASH_VERSINFO:-0}" -lt 3 ] || [ "${BASH_VERSINFO[0]:-0}" -lt 3 ] ||
  { [ "${BASH_VERSINFO[0]}" -eq 3 ] && [ "${BASH_VERSINFO[1]}" -lt 2 ]; }; then
  do_print_error 'Error: This script requires Bash 3.2 or newer.' >&2
  exit 1
fi
