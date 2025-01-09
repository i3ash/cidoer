#!/usr/bin/env bash
set -eu -o pipefail

source ../cidoer.core.sh

CIDOER_COLOR_BLACK='\033[38;2;20;20;20m'
CIDOER_COLOR_RED='\033[38;2;237;106;101m'
CIDOER_COLOR_GREEN='\033[38;2;70;210;70m'
CIDOER_COLOR_YELLOW='\033[38;2;190;190;0m'
CIDOER_COLOR_BLUE='\033[38;2;86;136;239m'
CIDOER_COLOR_MAGENTA='\033[38;2;168;136;246m'
CIDOER_COLOR_CYAN='\033[38;2;124;206;243m'
CIDOER_COLOR_WHITE='\033[38;2;185;185;185m'
CIDOER_COLOR_ERROR='\033[48;2;237;106;101m\033[38;2;0;0;0m'
#CIDOER_TPUT_COLORS=()

[ ${#CIDOER_TPUT_COLORS[@]} -gt 0 ] && {
  for line in "${CIDOER_TPUT_COLORS[@]}"; do
    printf "${line#*=}+++ ${line%%=*} +++$(do_lookup_color reset)%s\n"
  done
}

do_print_section 'do_print_section'
do_print_trace "do_print_trace"
do_print_info "do_print_info"
do_print_warn "do_print_warn"
do_tint "$CIDOER_COLOR_BLACK" $'do_tint $CIDOER_COLOR_BLACK'
do_tint blue 'do_tint blue'
do_tint magenta 'do_tint magenta'
# https://en.wikipedia.org/wiki/ANSI_escape_code
do_tint '\033[38;5;46m' 'do_tint with ANSI escape sequences 8-bit'
do_tint '\e[48;2;255;255;100m' '\e[38;5;21m' 'do_tint with ANSI escape sequences 24-bit'

do_print_code_bash_fn 'do_nothing' 'do_workflow_job' 'do_func_invoke'
do_print_dash_pair 'HELLO' "${HELLO:-}"
do_print_dash_pair 'do_print_dash_pair' ''
#do_print_dash_pair 'do_print_os_env' ''
#do_print_os_env
CIDOER_DEBUG='yes'
do_print_debug bash "$(declare -f define_core_utils)"
do_print_debug go '// This is a debug message'
do_print_debug txt '// This is a debug message'
do_print_debug text '// This is a debug message'
do_print_debug '// This is a debug message'
CIDOER_DEBUG='no'
do_print_section

do_core_check_dependencies
do_print_dash_pair
do_print_section

do_func_invoke do_lookup_color || do_print_info 'do_lookup_color returned' "$?"
do_func_invoke do_check_installed hello || do_print_info 'do_check_installed returned' "$?"
do_func_invoke do_check_installed || do_print_info 'do_check_installed returned' "$?"
do_func_invoke do_check_required_cmd hello whoami || do_print_error 'do_check_required_cmd returned' "$?"
do_func_invoke do_abc
do_func_invoke do_func_invoke do_abc
do_func_invoke do_func_invoke do_func_invoke do_abc
do_func_invoke do_print_trace do_func_invoke do_print_trace
do_print_section do_func_invoke
do_file_diff _diff_v1.txt _diff_v2.txt || do_print_info 'do_file_diff returned' "$?"
do_print_section do_file_diff

source ./cidoer.sh
do_workflow_job build
do_workflow_job upload
do_workflow_job deploy
do_workflow_job verify init 'do'
do_workflow_job docker step1 step2 step3

do_print_dash_pair 'do_git_version_tag' "$(do_git_version_tag)"
do_print_dash_pair 'do_git_count_commits_since' "$(do_git_count_commits_since "$(do_git_version_tag)")"
do_print_dash_pair 'do_git_short_commit_hash' "$(do_git_short_commit_hash)"
do_print_section do_git

do_func_invoke do_http_fetch 'https://raw.githubusercontent.com/i3ash/cidoer/refs/heads/main/stable.txt'
#do_func_invoke do_http_fetch 'http://this-domain-does-not-exist.invalid'
do_print_dash_pair 'do_os_type' "$(do_os_type)"
do_print_dash_pair 'do_host_type' "$(do_host_type)"
printf '%s\n' "$(bash --version)"
do_print_section
