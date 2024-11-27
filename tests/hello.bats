#!/usr/bin/env bats

@test "hello.sh" {
  run ../hello.sh
  [ "$status" -eq 0 ]
  [ "$output" = "Hello, GitHub Actions!" ]
}
