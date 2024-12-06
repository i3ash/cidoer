#!/usr/bin/env bash
# shellcheck disable=SC2317
set -eou pipefail

declare -x _COMMON_INIT_DONE
common_init() {
  if [ -n "${_COMMON_INIT_DONE:-}" ]; then return 0; fi
  do_print_info "$(do_stack_trace)" 'TODO ...'
  _COMMON_INIT_DONE='ok'
}

define_custom_build() {
  build_custom_init() { common_init; }
  build_custom_do() {
    do_print_warn "$(do_stack_trace)" 'TODO ...'
  }
}

define_custom_upload() {
  upload_custom_init() { common_init; }
  upload_custom_do() {
    do_print_warn "$(do_stack_trace)" 'TODO ...'
  }
}

define_custom_deploy() {
  deploy_custom_init() { common_init; }
  deploy_custom_do() {
    do_print_trace "$(do_stack_trace)" ': Acceptable Failure'
    return 1
  }
}

define_custom_verify() {
  verify_custom_init() { common_init; }
  verify_custom_do() {
    do_print_warn "$(do_stack_trace)" 'TODO ...'
  }
}
