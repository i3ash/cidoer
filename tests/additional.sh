#!/usr/bin/env bash
set -eou pipefail
source ../cidoer.sh

define_util_core
do_stack_trace

define_util_print
do_print_section 'do_print_section'
do_print_trace "do_print_trace"
do_print_info "do_print_info"
do_print_warn "do_print_warn"
do_print_colorful blue "do_print_colorful blue"
do_print_colorful magenta "do_print_code_bash_fn"
do_print_code_bash_fn 'do_print_code_bash_fn' 'do_print_code_bash' 'do_print_code_lines'
do_print_dash_pair 'do_print_dash_pair' ''
do_print_dash_pair 'do_print_os_env' ''
do_print_os_env
do_print_dash_pair
do_print_section
