#!/usr/bin/env bash
# shellcheck disable=SC2317
set -eo pipefail

define_util_core() {
  do_nothing() { :; }
  do_stack_trace() {
    printf '%s --> ' "${USER:-$(id -un)}@$(
      cat /proc/sys/kernel/hostname 2>/dev/null || hostname
    )"
    local fns=("${FUNCNAME[@]:1}")
    local idx
    for ((idx = ${#fns[@]} - 1; idx >= 0; idx--)); do
      printf '%s' "${fns[idx]}"
      if [ "$idx" -ne 0 ]; then printf ' '; fi
    done
    printf '\n'
  }
}

define_util_print() {
  do_print_variable() {
    local prefix="$1"
    local name="${2:-${1:?Variable name is required}}"
    local suffix="$3"
    local candidates=(
      "${prefix}${name}${suffix}" "${prefix}${name}" "${name}${suffix}" "${name}"
    )
    local value=''
    local candidate=''
    for candidate in "${candidates[@]}"; do
      value="${!candidate}"
      if [[ -n $value ]]; then break; fi
    done
    local trimmed="${value#"${value%%[![:space:]]*}"}"
    printf '%s' "${trimmed%"${trimmed##*[![:space:]]}"}"
  }
  do_print_trace() { printf "%s\n" "$(_print_colorful blue "${@}")"; }
  do_print_info() { printf "%s\n" "$(_print_colorful cyan "${@}")"; }
  do_print_warn() { printf "%s\n" "$(_print_colorful yellow "${@}")"; }
  do_print_colorful() { printf "%s\n" "$(_print_colorful "${@}")"; }
  do_print_os_env() {
    printenv | while IFS='=' read -r key value; do
      do_print_dash_pair "$key" "$value"
    done
  }
  do_print_dash_pair() {
    local dashes='------------------------------------'
    if [ ${#} -gt 1 ]; then
      local key
      local val
      key=${1} && val=${2}
      printf "%s %s [%s]\n" "$(_print_colorful green "${key:?}")" \
        "$(_print_colorful white "${dashes:${#key}}")" "$(_print_colorful green "${val}")"
    elif [ ${#} -gt 0 ]; then
      printf "%s %s\n" "$(_print_colorful white "${dashes}--")" "$(_print_colorful white "${1}")"
    else
      printf "%s\n" "$(_print_colorful white "${dashes}${dashes}")"
    fi
  }
  do_print_section() {
    local line='==============================================================================='
    if [ ${#} -le 0 ]; then
      printf "%s\n" "$(_print_colorful cyan "=${line} $(date +'%Y-%m-%d %T %Z')")"
      return
    fi
    local title="${*}"
    local trimmed="${title#"${title%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    if [ -n "${trimmed}" ]; then
      printf "%s\n" "$(_print_colorful cyan "${trimmed} ${line:${#trimmed}} $(date +'%Y-%m-%d %T %Z')")"
    fi
  }
  do_print_debug() {
    local _enabled="${OPTION_DEBUG:-no}"
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
    printf "%s\n" "$(_print_colorful magenta '#---|--------------------' "${stack}")"
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
          printf "%s\n" "$(_print_colorful magenta "$(printf '#%3d|' "$i")" "$line")"
          i=$((i + 1))
        done <<<"$arg"
      done
    fi
    printf "%s\n" "$(_print_colorful magenta '#---|--------------------' "${stack}")"
  }
  _print_colorful() {
    if [ "$#" -le 0 ]; then return 0; fi
    if command -v tput >/dev/null 2>&1; then
      set +e
      _print_colorful_with_tput "$@"
      set -e
    else
      local args=("$@")
      local i=0
      while [[ $i -lt ${#args[@]} ]]; do
        case "${args[$i]}" in bold | dim | underline | blink | reverse | hidden | \
          black | red | green | yellow | blue | magenta | cyan | white | \
          on_black | on_red | on_green | on_yellow | on_blue | on_magenta | on_cyan | on_white) ((i++)) ;;
        *) break ;;
        esac
      done
      local messages=("${args[@]:$i}")
      if [ ${#messages[@]} -eq 0 ]; then return; fi
      printf "%s" "${messages[*]}"
    fi
  }
  _print_colorful_with_tput() {
    if [ "$#" -le 0 ]; then return 0; fi
    local tp=''
    if command -v tput >/dev/null 2>&1; then
      if tput colors &>/dev/null && [ "$(tput colors)" -ge 256 ]; then
        tp='tput -T xterm-256color'
      else
        tp='tput -T xterm'
      fi
    fi
    local color=''
    local args=("$@")
    local i=0
    while [[ $i -lt ${#args[@]} ]]; do
      case "${args[$i]}" in
      bold) color+=$($tp bold) ;;
      dim) color+=$($tp dim) ;;
      underline) color+=$($tp smul) ;;
      blink) color+=$($tp blink) ;;
      reverse) color+=$($tp rev) ;;
      hidden) color+=$($tp invis) ;;
      black) color+=$($tp setaf 0) ;;
      red) color+=$($tp setaf 1) ;;
      green) color+=$($tp setaf 2) ;;
      yellow) color+=$($tp setaf 3) ;;
      blue) color+=$($tp setaf 4) ;;
      magenta) color+=$($tp setaf 5) ;;
      cyan) color+=$($tp setaf 6) ;;
      white) color+=$($tp setaf 7) ;;
      on_black) color+=$($tp setab 0) ;;
      on_red) color+=$($tp setab 1) ;;
      on_green) color+=$($tp setab 2) ;;
      on_yellow) color+=$($tp setab 3) ;;
      on_blue) color+=$($tp setab 4) ;;
      on_magenta) color+=$($tp setab 5) ;;
      on_cyan) color+=$($tp setab 6) ;;
      on_white) color+=$($tp setab 7) ;;
      *) break ;;
      esac
      ((i++))
    done
    local messages=("${args[@]:$i}")
    if [ ${#messages[@]} -eq 0 ]; then return; fi
    printf "%s" "${color}${messages[*]}$($tp sgr0)"
  }
}
