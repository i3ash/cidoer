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
  do_print_trace() { do_print_colorful '0;34' "${@}"; }
  do_print_info() { do_print_colorful '0;36' "${@}"; }
  do_print_warn() { do_print_colorful '1;33' "${@}"; }
  do_print_colorful() {
    if [ $# -lt 2 ]; then return; fi
    local color_code="\033[${1}m"
    local reset_code='\033[0m'
    local trimmed_title="${2#"${2%%[![:space:]]*}"}"
    trimmed_title="${trimmed_title%"${trimmed_title##*[![:space:]]}"}"
    if [ $# -gt 2 ]; then
      if [ -z "$trimmed_title" ]; then
        printf "${color_code}%s${reset_code}\n" "${@:3}"
      else
        printf "${color_code}%s${reset_code} %s\n" "$trimmed_title" "${@:3}"
      fi
    else
      printf "${color_code}%s${reset_code}\n" "$trimmed_title"
    fi
  }
}
