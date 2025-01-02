#!/usr/bin/env bats

load ../cidoer.core.sh
setup() { :; }
teardown() { :; }

@test "do_func_invoke | Calls existing function successfully" {
  mock_success_func() { return 0; }
  run do_func_invoke mock_success_func arg1 arg2
  [ "$status" == 0 ]
  [ "$output" == '' ]
}

@test "do_func_invoke | Passes all arguments correctly" {
  mock_test_args() {
    [ "$1" = "arg1" ] && [ "$2" = "arg2" ] && [ "$3" = "arg3" ]
  }
  run do_func_invoke mock_test_args arg1 arg2 arg3
  [ "$status" -eq 0 ]
  [ "$output" == '' ]
}

@test "do_func_invoke | Passes wrong arguments" {
  run do_func_invoke
  [[ "$status" == 0 ]]
  [[ "$output" == *$'$1 (func_name) is required'* ]]
  run do_func_invoke ''
  [[ "$status" == 0 ]]
  [[ "$output" == *$'$1 (func_name) is required'* ]]
}

@test "do_func_invoke | Handles non-existent function" {
  run do_func_invoke non_existent_function arg1 arg2
  [[ "$status" == 0 ]]
  [[ "$output" == *'non_existent_function is an absent function'* ]]
}

@test "do_func_invoke | Handles failed function" {
  mock_failure_func() { return 99; }
  run do_func_invoke mock_failure_func arg1 arg2
  [[ "$status" == 99 ]]
  [[ "$output" == *"mock_failure_func failed with exit code 99"* ]]
}

@test "do_func_invoke | Handles failed function recovery" {
  mock_func_1() { return 120; }
  mock_func_1_finally() { return 0; }
  run do_func_invoke mock_func_1 arg1 arg2
  [[ "$status" == 0 ]]
  [[ "$output" == *"mock_func_1 failed with exit code 120"* ]]
}

@test "do_func_invoke | Handles failed function stay failed" {
  mock_func_2() { return 119; }
  mock_func_2_finally() { return "${1:?}"; }
  run do_func_invoke mock_func_2 arg1 arg2
  [[ "$status" == 119 ]]
  [[ "$output" == *"mock_func_2 failed with exit code 119"* ]]
}
