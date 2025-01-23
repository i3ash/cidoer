#!/usr/bin/env bats
# shellcheck disable=SC2317

load ../cidoer.print.sh

setup() {
  ORIGINAL_PATH="$PATH"
}

teardown() {
  PATH="$ORIGINAL_PATH"
}

@test "do_stack_trace" {
  a() { b; }
  b() { c; }
  c() {
    printf 'hello\n' >/dev/null
    do_stack_trace
  }
  run a
  [[ "$status" == 0 ]]
  [[ "${lines[0]}" == "$(whoami)@$(hostname)"*"a b c"* ]]
}
