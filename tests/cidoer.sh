#!/usr/bin/env bash
# shellcheck disable=SC2317
set -eou pipefail

define_build() {
  build_do() {
    do_print_warn "$(do_stack_trace)" 'TODO ...'
  }
}

define_upload() {
  upload_do() {
    do_print_warn "$(do_stack_trace)" 'TODO ...'
  }
}

define_deploy() {
  deploy_do() {
    do_print_trace "$(do_stack_trace)" ': Acceptable Failure'
    return 120
  }
  deploy_do_finally() {
    local -r status=${1:-0}
    do_print_trace "$(do_stack_trace)" "$status"
    #return "$status"
  }
}

define_verify() {
  verify_init() {
    do_print_info "$(do_stack_trace)" 'Initialized'
  }
  verify_do() {
    do_print_warn "$(do_stack_trace)" 'TODO ...'
  }
}
