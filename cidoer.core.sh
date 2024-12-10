#!/usr/bin/env bash
# shellcheck disable=SC2317
set -eou pipefail

define_core_utils() {
  if declare -F 'do_nothing' >/dev/null; then return 0; fi
  do_nothing() { :; }
  do_check_core_dependencies() {
    do_check_optional_cmd uname date tput bat git grep sort tail
    do_check_required_cmd id hostname printenv tr awk diff
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
      if [ 'do_func_invoke' != "${FUNCNAME[idx]}" ]; then
        filtered_fns+=("${FUNCNAME[idx]}")
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
  declare -x _CIDOER_TPUT_CMD_OK
  declare -x _CIDOER_TPUT_COLORS_CLEAR
  do_tint() {
    if [ "$#" -le 0 ]; then return 0; fi
    if [ -z "${_CIDOER_TPUT_COLORS_CLEAR:-}" ]; then
      _CIDOER_TPUT_COLORS_CLEAR=$(do_lookup_color reset)
    fi
    local styles_clear="${_CIDOER_TPUT_COLORS_CLEAR}"
    if [ -z "${_CIDOER_TPUT_CMD_OK:-}" ]; then
      if command -v tput >/dev/null 2>&1; then _CIDOER_TPUT_CMD_OK="yes"; else _CIDOER_TPUT_CMD_OK="no"; fi
    fi
    local tput_ok="${_CIDOER_TPUT_CMD_OK}"
    local args=("$@") code i=0 styles=''
    while [ "$i" -lt "${#args[@]}" ]; do
      case "${args[$i]}" in bold | dim | underline | blink | reverse | hidden | \
        black | red | green | yellow | blue | magenta | cyan | white | \
        on_black | on_red | on_green | on_yellow | on_blue | on_magenta | on_cyan | on_white)
        if [ 'yes' = "$tput_ok" ]; then
          code=$(do_lookup_color "${args[$i]}")
          if [ -n "$code" ]; then styles+="$code"; fi
        fi
        i=$((i + 1))
        ;;
      *) break ;;
      esac
    done
    local messages=("${args[@]:$i}")
    if [ ${#messages[@]} -eq 0 ]; then return; fi
    printf '%s%s%s' "$styles" "${messages[*]}" "$styles_clear"
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
    if command -v tput >/dev/null 2>&1; then
      if tput colors &>/dev/null && [ "$(tput colors)" -ge 256 ]; then
        local tp_cmd='tput -T xterm-256color'
      else local tp_cmd='tput -T xterm'; fi
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
  }
  do_reset_tput
}

if declare -F 'do_nothing' >/dev/null; then return 0; fi
declare CIDOER_OS_TYPE=''
declare CIDOER_HOST_TYPE=''
declare CIDOER_DEBUG='no'
declare -a CIDOER_TPUT_COLORS=()
define_core_utils
