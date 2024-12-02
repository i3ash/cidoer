#!/usr/bin/env bash
set -eou pipefail
source ../cidoer.sh

define_util_core
# without colors
#CIDOER_TPUT_COLORS=()
do_stack_trace
do_print_section 'do_print_section'
do_print_trace "do_print_trace"
do_print_info "do_print_info"
do_print_warn "do_print_warn"
do_print_colorful blue "do_print_colorful blue"
do_print_colorful magenta "do_print_code_bash_fn"
do_print_code_bash_fn 'do_print_code_bash_fn' 'do_print_code_bash' 'do_print_code_lines'
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
