#!/usr/bin/env bash
set -eou pipefail

source ../cidoer.core.sh
#CIDOER_DEBUG='yes'
#CIDOER_TPUT_COLORS=()

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

do_func_invoke do_lookup_color
do_func_invoke do_check_installed hello
do_func_invoke do_check_installed
do_func_invoke do_check_required_cmd hello whoami
do_func_invoke do_abc
do_func_invoke do_func_invoke do_abc
do_func_invoke do_func_invoke do_func_invoke do_abc
do_func_invoke do_print_trace do_func_invoke do_print_trace
do_print_section do_func_invoke
do_diff _diff_v1.txt _diff_v2.txt || do_print_info 'do_diff returned' "$?"
do_print_section do_diff

bash --version
printf '\n'

source cidoer.sh
do_workflow_job build
do_workflow_job upload
do_workflow_job deploy
do_workflow_job verify
do_workflow_job docker_hub_push

do_print_dash_pair 'do_git_version_tag' "$(do_git_version_tag)"
do_print_dash_pair 'do_git_count_commits_since' "$(do_git_count_commits_since "$(do_git_version_tag)")"
do_print_dash_pair 'do_git_short_commit_hash' "$(do_git_short_commit_hash)"
do_print_section do_git
