#!/usr/bin/env bash
# shellcheck disable=SC2317
declare -F 'define_cidoer_print' >/dev/null && return 0
set -eu -o pipefail

define_cidoer_print() {
  declare -F '_print_defined' >/dev/null && return 0
  _print_defined() { :; }
  do_stack_trace() {
    # shellcheck disable=SC2319
    local -ir status=$?
    local -i idx
    local -a filtered_fns=()
    for ((idx = ${#FUNCNAME[@]} - 2; idx > 0; idx--)); do
      [ 'do_func_invoke' != "${FUNCNAME[$idx]}" ] && filtered_fns+=("${FUNCNAME[$idx]}")
    done
    if [ ${#filtered_fns[@]} -gt 0 ]; then
      printf '%s --> %s\n' "${USER:-$(id -un 2>/dev/null)}@${HOSTNAME:-$(hostname 2>/dev/null)}" "${filtered_fns[*]}"
    else printf '%s -->\n' "${USER:-$(id -un 2>/dev/null)}@${HOSTNAME:-$(hostname 2>/dev/null)}"; fi
    return $status
  }
  do_print_with_color() {
    [ -z "${CIDOER_TPUT_COLORS+x}" ] && return 1
    [ "${#CIDOER_TPUT_COLORS[@]}" -le 0 ] && return 1
    [ "${CIDOER_NO_COLOR:-no}" = 'yes' ] && return 1
    return 0
  }
  do_print_trace() { do_tint "${CIDOER_COLOR_BLUE:-blue}" "${@}"; }
  do_print_info() { do_tint "${CIDOER_COLOR_CYAN:-cyan}" "${@}"; }
  do_print_warn() { do_tint "${CIDOER_COLOR_YELLOW:-yellow}" "${@}"; }
  do_print_error() { do_tint "${CIDOER_COLOR_ERROR:-red}" bold "${@}"; }
  do_print_os_env() {
    command -v printenv >/dev/null 2>&1 || return 127
    local key value
    while IFS='=' read -r key value; do
      do_print_dash_pair "$key" "$value"
    done < <(printenv)
  }
  do_print_dash_pair() {
    local -r dashes='------------------------------------'
    local -r green="${CIDOER_COLOR_GREEN:-green}"
    local -r white="${CIDOER_COLOR_WHITE:-white}"
    [ ${#} -gt 1 ] && {
      printf "%s %s [%s]\n" "$(do_tint "$green" "$1")" "$(do_tint "$white" "${dashes:${#1}}")" "$(do_tint "$green" "$2")"
      return 0
    }
    [ ${#} -gt 0 ] && {
      printf "%s < %s >\n" "$(do_tint "$white" "$dashes-")" "$(do_tint "$white" "$1")"
      return 0
    }
    do_tint "$white" "$dashes$dashes"
  }
  do_time_now() { command -v date >/dev/null 2>&1 && printf '%s\n' "$(date +"%Y-%m-%d %T %Z")"; }
  do_print_section() {
    local -r line='==============================================================================='
    [ ${#} -le 0 ] && {
      do_tint bold "${CIDOER_COLOR_CYAN:-cyan}" "=${line} $(do_time_now)"
      return 0
    }
    local -r title=$(do_trim "${*}")
    [ -n "${title}" ] && do_tint bold "${CIDOER_COLOR_CYAN:-cyan}" "${title} ${line:${#title}} $(do_time_now)"
  }
  do_print_debug() {
    [ "${CIDOER_DEBUG:-no}" != "yes" ] && return 0
    do_print_code_lines "$@" >&2
  }
  do_print_code_bash_debug() {
    [ "${CIDOER_DEBUG:-no}" != "yes" ] && return 0
    do_print_code_bash "$@" >&2
  }
  do_print_code_bash_fn() { do_print_code_bash "$(declare -f "$@")"; }
  do_print_code_bash() {
    do_print_with_color && do_check_bat_available && {
      do_print_code_lines 'bash' "$@"
      return 0
    }
    do_print_code_lines "$@"
  }
  do_print_code_lines() {
    [ "$#" -le 0 ] && return 0
    local -r stack="$(do_stack_trace)"
    local -r magenta="${CIDOER_COLOR_MAGENTA:-magenta}"
    [ "$#" -gt 1 ] && local -r lang="$1"
    do_tint "$magenta" '#---|--------------------' "${stack}"
    if do_print_with_color && do_check_bat_available &&
      bat --list-languages | sed 's/[:,]/ /g' | grep -q " ${lang:-}"; then
      bat --language "${lang:-}" --paging never --number <<<"${*:2}" 2>/dev/null && {
        do_tint "$magenta" '#---|--------------------' "${stack}" "${lang:-}"
        return 0
      }
    fi
    local arg line i=1
    for arg in "$@"; do
      while IFS= read -r line; do
        do_tint "$magenta" "$(printf '#%3d|' "$i")" "$line"
        i=$((i + 1))
      done <<<"$arg"
    done
    do_tint "$magenta" '#---|--------------------' "${stack}"
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
    [ -z "$styles" ] || [ "${CIDOER_NO_COLOR:-no}" = 'yes' ] && {
      printf "%s\n" "${messages[*]}"
      return 0
    }
    [ -z "${_CIDOER_TPUT_COLORS_CLEAR:-}" ] && _CIDOER_TPUT_COLORS_CLEAR=$(do_lookup_color reset)
    local -r styles_clear="${_CIDOER_TPUT_COLORS_CLEAR:=\033[0m}"
    printf "$styles%s$styles_clear\n" "${messages[*]}"
  }
  do_lookup_color() {
    [ -z "${CIDOER_TPUT_COLORS+x}" ] && return 0
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
    [ "${CIDOER_NO_COLOR:-no}" = 'yes' ] && return 0
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
  do_check_bats_core() {
    [[ -n "${BATS_TEST_NUMBER:-}" ]] && return 0
    [[ -n "${BATS_TEST_NAME:-}" ]] && return 0
    return 1
  }
  do_check_bat_available() {
    [ -n "${CIDOER_BAT_AVAILABLE:-}" ] && {
      [ "${CIDOER_BAT_AVAILABLE:-}" = 'yes' ] && return 0
      return 1
    }
    for cmd in bat grep sed; do
      command -v "$cmd" >/dev/null 2>&1 || {
        CIDOER_BAT_AVAILABLE='no' && return 1
      }
    done
    CIDOER_BAT_AVAILABLE='yes'
  }
}

declare CIDOER_COLOR_BLACK
declare CIDOER_COLOR_RED
declare CIDOER_COLOR_GREEN
declare CIDOER_COLOR_YELLOW
declare CIDOER_COLOR_BLUE
declare CIDOER_COLOR_MAGENTA
declare CIDOER_COLOR_CYAN
declare CIDOER_COLOR_WHITE
declare CIDOER_COLOR_RESET
declare CIDOER_NO_COLOR
declare CIDOER_COLOR_ERROR
declare -a CIDOER_TPUT_COLORS=()
declare CIDOER_BAT_AVAILABLE

# id hostname date printenv tput grep sed bat
define_cidoer_print
do_check_bats_core || do_print_dash_pair 'CIDOER_BASH_SOURCE_PRINT' "${BASH_SOURCE[*]}"
