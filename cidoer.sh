#!/usr/bin/env bash
set -eou pipefail
# shellcheck disable=SC2317

define_util_core() {
  do_nothing() { :; }
  do_stack_trace() {
    printf '%s --> ' "${USER:-$(id -un)}@${HOSTNAME:-$(hostname)}"
    local fns=("${FUNCNAME[@]:1}")
    local idx
    for ((idx = ${#fns[@]} - 1; idx >= 0; idx--)); do
      printf '%s' "${fns[idx]}"
      if [ "$idx" -ne 0 ]; then printf ' '; fi
    done
    printf '\n'
  }
  do_time_now() {
    if command -v date >/dev/null 2>&1; then printf '%s' "$(date +"%Y-%m-%d %T %Z")"; fi
  }
  do_func_invoke() {
    local func_name="${1}"
    if declare -F "${func_name}" >/dev/null; then
      local exit_code=0
      "${@}" || exit_code=$?
      if [ "${exit_code}" -ne 0 ]; then
        do_print_warn "$(do_stack_trace)" "${func_name} failed with exit code ${exit_code}" >&2
      fi
    else
      do_print_trace "$(do_stack_trace)" "${func_name} is an absent function" >&2
    fi
  }
  do_print_variable() {
    if [ "$#" -le 0 ]; then return 0; fi
    local prefix="$1"
    local name="$2"
    local suffix="$3"
    local candidates=(
      "${prefix}${name}${suffix}" "${prefix}${name}" "${name}${suffix}" "${name}"
    )
    local value=''
    local candidate=''
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
  do_print_error() { printf "%s\n" "$(do_tint bold on_red "${@}")"; }
  do_print_colorful() { printf "%s\n" "$(do_tint "${@}")"; }
  do_print_os_env() {
    local key
    local value
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
    local line='==============================================================================='
    if [ ${#} -le 0 ]; then
      printf "%s\n" "$(do_tint cyan "=${line} $(do_time_now)")"
      return
    fi
    local title="${*}"
    local trimmed="${title#"${title%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    if [ -n "${trimmed}" ]; then
      printf "%s\n" "$(do_tint cyan "${trimmed} ${line:${#trimmed}} $(do_time_now)")"
    fi
  }
  do_print_debug() {
    local _enabled="${CIDOER_DEBUG:-no}"
    if [ "$_enabled" != "yes" ]; then return 0; fi
    do_print_code_lines "$@" >&2
  }
  do_print_code_bash_fn() { do_print_code_bash "$(declare -f "$@")"; }
  do_print_code_bash() {
    if command -v bat >/dev/null 2>&1; then
      do_print_code_lines 'bash' "$@"
    else
      do_print_code_lines "$@"
    fi
  }
  do_print_code_lines() {
    if [ "$#" -le 0 ]; then return 0; fi
    local stack=''
    stack="$(do_stack_trace)"
    printf "%s\n" "$(do_tint magenta '#---|--------------------' "${stack}")"
    if command -v bat >/dev/null 2>&1; then
      shift
      local code_block="$*"
      bat --language sh --paging never --number <<<"${code_block}"
    else
      local arg
      local line
      local i=1
      for arg in "$@"; do
        while IFS= read -r line; do
          printf "%s\n" "$(do_tint magenta "$(printf '#%3d|' "$i")" "$line")"
          ((i++))
        done <<<"$arg"
      done
    fi
    printf "%s\n" "$(do_tint magenta '#---|--------------------' "${stack}")"
  }
  do_tint() {
    if [ "$#" -le 0 ]; then return 0; fi
    local args=("$@")
    local styles_clear="${_CIDOER_TPUT_COLORS_CLEAR:=$(do_lookup_color reset)}"
    local styles=''
    local code
    local i=0
    while [ "$i" -lt "${#args[@]}" ]; do
      case "${args[$i]}" in bold | dim | underline | blink | reverse | hidden | \
        black | red | green | yellow | blue | magenta | cyan | white | \
        on_black | on_red | on_green | on_yellow | on_blue | on_magenta | on_cyan | on_white)
        if command -v tput >/dev/null 2>&1; then
          code=$(do_lookup_color "${args[$i]}")
          if [ -n "$code" ]; then styles+="$code"; fi
        fi
        ((i++))
        ;;
      *) break ;;
      esac
    done
    local messages=("${args[@]:$i}")
    if [ ${#messages[@]} -eq 0 ]; then return; fi
    printf '%s%s%s' "$styles" "${messages[*]}" "$styles_clear"
  }
  do_reset_tput() {
    if command -v tput >/dev/null 2>&1; then
      local tp_cmd
      if tput colors &>/dev/null && [ "$(tput colors)" -ge 256 ]; then
        local tp_cmd='tput -T xterm-256color'
      else
        local tp_cmd='tput -T xterm'
      fi
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
      _CIDOER_TPUT_COLORS_CLEAR="$(do_lookup_color reset)"
    fi
  }
  do_lookup_color() {
    if [ ${#CIDOER_TPUT_COLORS} -le 0 ]; then return 0; fi
    set +u
    local key=${1}
    set -u
    if [ -z "$key" ]; then
      printf $'do_lookup_color $1 (color) is required\n' >&2
      return 1
    fi
    local color
    for color in "${CIDOER_TPUT_COLORS[@]}"; do
      case "$color" in
      "$key="*)
        printf '%s' "${color#*=}"
        return 0
        ;;
      esac
    done
  }
  do_check_installed() {
    set +u
    local cmd="$1"
    set -u
    if [ -z "$cmd" ]; then
      printf $'do_check_installed $1 (cmd) is required\n' >&2
      return 2
    fi
    local cmd_path
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
      do_print_error "Please install the missing required commands and try again later."
      return 1
    fi
  }
  do_check_core_dependencies() {
    do_check_optional_cmd date tput bat
    do_check_required_cmd id hostname printenv
  }
  do_reset_tput
}
declare CIDOER_DEBUG='no'
declare -a CIDOER_TPUT_COLORS=()
