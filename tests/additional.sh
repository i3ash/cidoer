#!/usr/bin/env bash

set -euo pipefail

source ../cidoer.sh

define_util_core
echo '---------- do_stack_trace'
do_stack_trace

define_util_print
echo '---------- do_print...'
do_print_trace "do_print_trace"
do_print_info "do_print_info"
do_print_warn "do_print_warn"
do_print_colorful green "do_print_colorful green"
do_print_colorful magenta "do_print_code_bash"
do_print_code_bash "$(declare -f do_print_code_bash)"

echo '----------' "$(date)"
