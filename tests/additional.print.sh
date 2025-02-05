#!/usr/bin/env bash
set -eu -o pipefail

#CIDOER_NO_COLOR='yes'
source ../cidoer.print.sh
source ../cidoer.print.sh
source ../cidoer.print.sh

define_cidoer_print
define_cidoer_print

do_print_dash_pair
do_print_trace "do_print_trace"
do_print_info "do_print_info"
do_print_warn "do_print_warn"
do_print_error 'do_print_error'

# shellcheck disable=SC2034
# bashsupport disable=BP2001
customise_color_scheme() {
  CIDOER_COLOR_RESET='\033[0m'
  CIDOER_COLOR_ERROR='\033[48;2;237;106;101m\033[38;2;0;0;0m'
  CIDOER_COLOR_BLACK='\033[38;2;20;20;20m'
  CIDOER_COLOR_RED='\033[38;2;237;106;101m'
  CIDOER_COLOR_GREEN='\033[38;2;70;210;70m'
  CIDOER_COLOR_YELLOW='\033[38;2;190;190;0m'
  CIDOER_COLOR_BLUE='\033[38;2;86;136;239m'
  CIDOER_COLOR_MAGENTA='\033[38;2;168;136;246m'
  CIDOER_COLOR_CYAN='\033[38;2;124;206;243m'
  CIDOER_COLOR_WHITE='\033[38;2;185;185;185m'
}
#CIDOER_TPUT_COLORS=()
#unset CIDOER_TPUT_COLORS
do_print_with_color && {
  customise_color_scheme
  do_print_dash_pair customise_color_scheme
  do_print_trace "do_print_trace"
  do_print_info "do_print_info"
  do_print_warn "do_print_warn"
  do_print_error 'do_print_error'
}

do_print_dash_pair
do_print_dash_pair 'HELLO' "${HELLO:-}"
do_print_dash_pair 'do_time_now' "$(do_time_now)"
do_print_dash_pair 'do_reverse' "$(do_reverse 5 4 3 2 1)"
do_print_dash_pair 'do_stack_trace' "$(
  a() { b; }
  b() { c; }
  c() { do_stack_trace; }
  a
)"
#do_print_os_env
do_print_dash_pair 'do_print_with_color' "$(
  do_print_with_color
  printf '%d\n' $?
)"

CIDOER_DEBUG='yes'
do_print_code_bash_debug "$(declare -f define_core_utils)"
do_print_debug go '// This is a debug message'
do_print_debug txt '// This is a debug message'
do_print_debug text '// This is a debug message'
do_print_debug '// This is a debug message'
CIDOER_DEBUG='no'

do_print_code_bash_fn 'do_time_now' 'do_reverse' 'do_stack_trace'

do_print_with_color && {
  do_print_dash_pair
  for line in "${CIDOER_TPUT_COLORS[@]}"; do
    printf "${line#*=}+++ ${line%%=*} +++$(do_lookup_color reset)%s\n"
  done
}

do_print_dash_pair
do_tint red 'do_tint red'
do_tint yellow 'do_tint yellow'
do_tint green 'do_tint green'
do_tint cyan 'do_tint cyan'
do_tint blue 'do_tint blue'
do_tint magenta 'do_tint magenta'
do_print_dash_pair
do_tint "${CIDOER_COLOR_GREEN:-green}" $'do_tint $CIDOER_COLOR_GREEN'
do_tint '\e[48;2;60;130;60m' "${CIDOER_COLOR_BLACK:-\e[38;5;21m}" 'do_tint with ANSI escape sequences 24-bit'
do_tint '\033[38;5;46m' 'do_tint with ANSI escape sequences 8-bit'
# https://en.wikipedia.org/wiki/ANSI_escape_code
do_print_section 'do_print_section'
