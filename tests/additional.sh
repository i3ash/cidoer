#!/usr/bin/env bash
set -eou pipefail

for i in 196 208 226 46 33 45 105 246; do printf '\e[38;5;%sm Color Code %03s \e[0m\n' "$i" "$i"; done
for i in 196 208 226 46 33 45 105 246; do printf '\e[38;5;0m\e[48;5;%sm Color Code %03s \e[0m\n' "$i" "$i"; done
for i in {0..15}; do printf '\e[48;5;%sm %03d \e[0m' "$i" "$i"; done
printf '\n'
for i in {0..215}; do
  printf '\e[7m\e[38;5;%sm%03d\e[0m ' "$((i+16))" "$((i+16))"
  if [ $(((i + 1) % 36)) -eq 0 ]; then printf '\n'; fi
done
for i in {232..255}; do printf '\e[48;5;%sm %03d \e[0m' "$i" "$i"; done
printf '\n'

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
do_workflow_job verify init 'do'
do_workflow_job docker step1 step2 step3

do_print_dash_pair 'do_git_version_tag' "$(do_git_version_tag)"
do_print_dash_pair 'do_git_count_commits_since' "$(do_git_count_commits_since "$(do_git_version_tag)")"
do_print_dash_pair 'do_git_short_commit_hash' "$(do_git_short_commit_hash)"
do_print_section do_git

do_print_dash_pair 'do_os_type' "$(do_os_type)"
do_print_dash_pair 'do_host_type' "$(do_host_type)"
