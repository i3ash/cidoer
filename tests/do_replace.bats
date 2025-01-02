#!/usr/bin/env bats

load ../cidoer.core.sh

@test "do_file_replace | Basic replacement (single placeholder)" {
  result=$(do_file_replace \{ \} name=World <<<"Hello {name}, welcome!")
  [ "$result" = "Hello World, welcome!" ]
}

@test "do_file_replace | Multiple placeholders" {
  result=$(echo "{greet}, {name}!" | do_file_replace '{' '}' "greet=Hi" "name=Alice")
  [ "$result" = "Hi, Alice!" ]
}

@test "do_file_replace | Multiple $ prefixes in placeholder key" {
  result=$(echo $'Value: {$$key}' | do_file_replace '{' '}' "key=42")
  [ "$result" = "Value: 42" ]
}

@test "do_file_replace | Environment variable replacement" {
  export NAME="Bob"
  result=$(echo "Hello {NAME}!" | do_file_replace '{' '}')
  [ "$result" = "Hello Bob!" ]
}

@test "do_file_replace | Non-matching key" {
  result=$(echo $'Hello {unknown} {$unknown}' | do_file_replace '{' '}')
  [ "$result" = $'Hello {unknown} {$unknown}' ]
}

@test "do_file_replace | Multiple lines and multiple placeholders" {
  input="Line1: {key1}\nLine2: {key2} and {key1}\nLine3 no placeholder"
  result=$(echo -e "$input" | do_file_replace '{' '}' "key1=AAA" "key2=BBB")
  expected="Line1: AAA
Line2: BBB and AAA
Line3 no placeholder"
  [ "$result" = "$expected" ]
}

@test "do_file_replace | Different delimiters" {
  result=$(echo "Hello <name>!" | do_file_replace '<' '>' "name=Charlie")
  [ "$result" = "Hello Charlie!" ]
}

@test "do_file_replace | Empty value replacement" {
  result=$(echo "Empty {var} here" | do_file_replace '{' '}' "var=")
  [ "$result" = "Empty  here" ]
}

@test "do_file_replace | Special character values" {
  result=$(echo "User: {user}, Path: {path}" | do_file_replace '{' '}' 'user=John Doe' 'path=/tmp/some dir')
  [ "$result" = "User: John Doe, Path: /tmp/some dir" ]
}
