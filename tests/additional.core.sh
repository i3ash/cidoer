#!/usr/bin/env bash
set -eu -o pipefail

source ../cidoer.core.sh
#CIDOER_DEBUG='yes'
#CIDOER_TPUT_COLORS=()
if [ ${#CIDOER_TPUT_COLORS} -gt 0 ]; then
  for line in "${CIDOER_TPUT_COLORS[@]}"; do
    printf "${line#*=}+++ ${line%%=*} +++$(do_lookup_color reset)%s\n"
  done
fi

do_stack_trace
do_print_section 'do_print_section'
do_print_trace "do_print_trace"
do_print_info "do_print_info"
do_print_warn "do_print_warn"
do_print_colorful blue "do_print_colorful blue"
do_print_colorful magenta "do_print_code_bash_fn"
do_print_code_bash_fn 'do_print_code_bash_fn' 'do_print_code_bash' 'do_print_code_lines'
do_print_debug bash "$(declare -f define_core_utils)"
do_print_dash_pair 'HELLO' "${HELLO:-}"
do_print_dash_pair 'do_print_dash_pair' ''
#do_print_dash_pair 'do_print_os_env' ''
#do_print_os_env
do_print_section

do_check_core_dependencies
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
do_diff _diff_v1.txt _diff_v2.txt || do_print_info 'do_diff returned' "$?"
do_print_section do_diff

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