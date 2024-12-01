#!/usr/bin/env bats

load ../cidoer.sh

setup() {
  define_util_core
  set +u
}
teardown() {
  set -u
}

@test "do_print_variable | Prints the value of a variable without prefix or suffix" {
  local VAR='value0'
  run do_print_variable 'VAR'
  [ "$status" -eq 0 ]
  [ "$output" == "${VAR}" ]
}

@test "do_print_variable | Prints the value of a variable with prefix and suffix" {
  local PREFIX_VAR_SUFFIX='value3'
  run do_print_variable 'PREFIX_' 'VAR' '_SUFFIX'
  [ "$status" -eq 0 ]
  [ "$output" == "${PREFIX_VAR_SUFFIX}" ]
}

@test "do_print_variable | Prints the value of the highest priority variable" {
  local VAR='value0'
  local VAR_SUFFIX='value1'
  local PREFIX_VAR='value2'
  local PREFIX_VAR_SUFFIX='value3'
  run do_print_variable 'VAR'
  [ "$status" -eq 0 ]
  [ "$output" == "${VAR}" ]
  run do_print_variable 'VAR' '_SUFFIX'
  [ "$status" -eq 0 ]
  [ "$output" == "${VAR_SUFFIX}" ]
  run do_print_variable 'PREFIX_' 'VAR'
  [ "$status" -eq 0 ]
  [ "$output" == "${PREFIX_VAR}" ]
  run do_print_variable 'PREFIX_' 'VAR' '_SUFFIX'
  [ "$status" -eq 0 ]
  [ "$output" == "${PREFIX_VAR_SUFFIX}" ]
}

@test "do_print_variable | Trims leading and trailing whitespace from variable value" {
  export TRIM_VAR="  value_with_spaces  "
  run do_print_variable 'TRIM_VAR'
  [ "$status" -eq 0 ]
  [ "$output" == "value_with_spaces" ]
}

@test "do_print_variable | Exits with an error when name is missing" {
  run do_print_variable
  [ "$status" == 0 ]
  [ "$output" == '' ]
}

@test "do_print_variable | Prints an empty string when no variables are set" {
  run do_print_variable 'PREFIX_' 'NON_EXISTENT_VAR' '_SUFFIX'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
