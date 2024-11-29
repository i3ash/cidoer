#!/usr/bin/env bash

set -eou pipefail

source ../cidoer.sh

define_util_core
echo '---------- do_stack_trace'
do_stack_trace

define_util_print
echo '---------- do_print...'
do_print_trace "do_print_trace"
do_print_info "do_print_info"
do_print_warn "do_print_warn"
do_print_colorful blue "do_print_colorful blue"
do_print_colorful magenta "do_print_code_bash"
do_print_code_bash "$(declare -f do_print_code_bash)"
do_print_dash_pair 'Environment Variables'
printenv | while IFS='=' read -r key value; do
  do_print_dash_pair "$key" "$value"
done
do_print_dash_pair

echo '----------' "$(date)"
