#!/usr/bin/env bash
# shellcheck disable=SC2317
set -eo pipefail

define_util_core() {
  do_nothing() { :; }
  do_stack_trace() {
    printf '%s --> ' "${USER:-$(id -un)}@$(
      cat /proc/sys/kernel/hostname 2>/dev/null || hostname
    )"
    local fns=("${FUNCNAME[@]:1}")
    local idx
    for ((idx = ${#fns[@]} - 1; idx >= 0; idx--)); do
      printf '%s' "${fns[idx]}"
      if [ "$idx" -ne 0 ]; then printf ' '; fi
    done
    printf '\n'
  }
}
