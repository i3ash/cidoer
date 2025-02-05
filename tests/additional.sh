#!/usr/bin/env bash

run_bash_file() {
  local -r script="${1:-}"
  [ -f "$script" ] || return 1
  /usr/bin/env bash "$script" || printf 'bash %q returned %d\n' "$script" "$?"
}

run_bash_file additional.print.sh
run_bash_file additional.core.sh
run_bash_file additional.jff.sh
run_bash_file additional.ssh.sh
