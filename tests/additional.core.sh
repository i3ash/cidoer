#!/usr/bin/env bash
# shellcheck disable=SC2317
set -eu -o pipefail

source ../cidoer.core.sh

do_core_check_dependencies() {
  do_check_optional_cmd tput bat git curl wget flock lockf realpath readlink
  do_check_required_cmd printenv sed awk diff || return $?
}
do_print_section
do_core_check_dependencies

do_print_dash_pair
do_func_invoke do_abc
do_func_invoke do_func_invoke do_abc
do_func_invoke do_func_invoke do_func_invoke do_abc
do_func_invoke do_print_trace do_func_invoke do_print_trace
do_func_invoke do_lookup_color || do_print_info 'do_lookup_color returned' "$?"
do_func_invoke do_check_installed hello || do_print_info 'do_check_installed returned' "$?"
do_func_invoke do_check_installed || do_print_info 'do_check_installed returned' "$?"
do_func_invoke do_check_required_cmd hello whoami || do_print_error 'do_check_required_cmd returned' "$?"
do_print_section do_func_invoke

do_file_diff _diff_v1.txt _diff_v2.txt || do_print_info 'do_file_diff returned' "$?"
do_print_section do_file_diff

source ./cidoer.sh
define_docker() {
  do_print_section "DOCKER STEPS BEGIN"
  docker_done() { do_print_section "DOCKER STEPS DONE!"; }
}
do_workflow_job build
do_workflow_job upload
do_workflow_job deploy
do_workflow_job verify init 'do'
do_workflow_job docker step1 step2 step3 'done'
do_workflow_job docker step1 step2 step3 'done'

do_check_required_cmd git grep sort tail && {
  do_print_dash_pair 'do_git_version_tag' "$(do_git_version_tag)"
  do_print_dash_pair 'do_git_count_commits_since' "$(do_git_count_commits_since "$(do_git_version_tag)")"
  do_print_dash_pair 'do_git_short_commit_hash' "$(do_git_short_commit_hash)"
  do_print_section do_git
}

do_func_invoke do_http_fetch 'https://raw.githubusercontent.com/i3ash/cidoer/refs/heads/main/stable.txt'
#do_func_invoke do_http_fetch 'http://this-domain-does-not-exist.invalid'
do_print_dash_pair 'do_os_type' "$(do_os_type)"
do_print_dash_pair 'do_host_type' "$(do_host_type)"

final_cleanup() {
  do_print_trace "$(do_stack_trace)" "Performing cleanup..."
}
do_trap_append 'final_cleanup' EXIT SIGHUP SIGINT SIGQUIT SIGTERM

do_lock_acquire 'lock_200.dir' || exit 101
do_lock_acquire 'lock_201.dir' || exit 102
do_print_section Ending
#do_lock_release 'lock_200.dir'
#do_lock_release 'lock_201.dir'

final_cleanup_done() {
  printf '%s\n' "$(bash --version)"
  do_check_bash_3_2 && {
    do_print_dash_pair 'BASH_VERSION' "${BASH_VERSION:-}"
    do_print_dash_pair 'BASH_VERSINFO' "${BASH_VERSINFO[*]}"
    do_print_dash_pair 'CIDOER_CORE_FILE' "${CIDOER_CORE_FILE:-}"
    do_print_dash_pair 'realpath' "$(realpath "$(dirname "${BASH_SOURCE[0]}")")" || :
    do_print_dash_pair 'readlink' "$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")" || :
  }
  do_print_trace "$(do_stack_trace)" "${@}"
}
do_trap_append "final_cleanup_done $(do_host_type) $(do_os_type)" EXIT
trap -p
do_print_section Ended
