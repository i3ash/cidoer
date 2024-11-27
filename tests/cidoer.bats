#!/usr/bin/env bats
# shellcheck disable=SC2317

load ../cidoer.sh

setup() {
  ORIGINAL_PATH="$PATH"
  define_util_core
}

teardown() {
  PATH="$ORIGINAL_PATH"
}

@test "do_nothing" {
  run do_nothing
  [ "$status" -eq 0 ]
}

@test "do_stack_trace" {
  a() { b; }
  b() { c; }
  c() { do_stack_trace; }
  run a
  [[ "$status" == 0 ]]
  [[ "${lines[0]}" == "$(whoami)@$(hostname) --> main "*"a b c" ]]
}
