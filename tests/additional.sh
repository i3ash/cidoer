#!/usr/bin/env bash

set -euo pipefail

source ../cidoer.sh

define_util_core
echo '---------- do_stack_trace'
do_stack_trace

define_util_print
echo '---------- do_print...'
do_print_trace "Trace: This is a debug message."
do_print_info "Info: Operation successful."
do_print_warn "Warning: Disk space is low."

echo '----------' "$(date)"
