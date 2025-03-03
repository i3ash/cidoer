#!/usr/bin/env bats

load ../cidoer.core.sh

setup() {
  temp_dir="$(mktemp -d)"
  PATH="$temp_dir:$PATH"
}

teardown() {
  rm -rf "$temp_dir"
}

@test "do_http_fetch with no parameters should print usage and return error" {
  run do_http_fetch
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage: do_http_fetch"* ]]
}

@test "do_http_fetch should return a specific error code when neither wget nor curl is installed" {
  old_path="$PATH"
  # shellcheck disable=SC2123
  PATH="./non_existent_dir"
  run do_http_fetch "https://i3ash.com"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Neither 'wget' nor 'curl' is installed."* ]]
  PATH="$old_path"
}

@test "do_http_fetch with valid URL and no output file prints the content to stdout" {
  if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
    skip "Neither wget nor curl is installed, skipping test."
  fi
  run do_http_fetch "https://i3ash.com"
  [ "$status" -eq 0 ]
  [[ "$output" == *"i3ash"* ]]
}

@test "do_http_fetch with valid URL and output file saves content to the file" {
  if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
    skip "Neither wget nor curl is installed, skipping test."
  fi
  local out_file="${temp_dir}/test_output.html"
  rm -f "$out_file"
  run do_http_fetch "https://i3ash.com" "$out_file"
  [ "$status" -eq 0 ]
  [ -f "$out_file" ]
  grep "i3ash" "$out_file"
  rm -f "$out_file"
}

@test "do_http_fetch with invalid URL should fail and return an error" {
  command -v wget >/dev/null 2>&1 || command -v curl >/dev/null 2>&1 && {
    skip "Neither wget nor curl is installed, skipping test."
  }
  export CIDOER_FETCH_RETRIES=1
  export CIDOER_FETCH_WAIT_RETRY=1
  export CIDOER_FETCH_TIMEOUT=10
  run do_http_fetch "http://this-domain-does-not-exist.invalid"
  [ "$status" -ne 0 ]
  #printf '%s\n%s' "$status" "$output" >/tmp/250102.txt
}
