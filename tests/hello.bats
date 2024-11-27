#!/usr/bin/env bats

@test "Testing hello.sh output" {
    run ../hello.sh
    [ "$status" -eq 0 ]
    [ "$output" = "Hello, GitHub Actions!" ]
}
