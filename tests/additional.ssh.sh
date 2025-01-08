#!/usr/bin/env bash
set -eu -o pipefail

#declare -rx CIDOER_DIR='..'
[ -f ../cidoer.core.sh ] && source ../cidoer.core.sh
[ -f ../cidoer.ssh.sh ] && source ../cidoer.ssh.sh

test_ssh() {
  _abc="'exiting'"
  _on_exit() {
    do_print_warn "$(do_stack_trace)" "$_abc"
  }
  trap _on_exit EXIT
  ! do_ssh_agent_ensure && return 2
  #ssh-add -D || do_print_warn 'ssh-add -D returned' "$?"
  [ -n "${KEY_01:-}" ] && do_func_invoke do_ssh_add_key "$KEY_01" KEY_01_PASSPHRASE
  do_print_trace ssh-add -l
  ssh-add -l || do_print_warn 'ssh-add -l returned' "$?"
  #printf '%q' "$(cat /tmp/id_ed25519)"
  [ -z "${SSH_HOST_01:-}" ] && return 3
  do_ssh_add_known_host "$SSH_HOST_01" "${SSH_PORT_01:-}" || do_print_warn 'do_ssh_add_known_host returned' "$?"
  local -r cmd="$(do_ssh_print_chain "${SSH_USER_01:-debian}@$SSH_HOST_01")"
  CIDOER_DEBUG='yes'
  do_ssh_exec "${cmd:-}" define_cidoer_core define_cidoer_print $'
    do_print_info  "$(do_stack_trace)" "${CIDOER_SSH_EXPORT_VAR[*]}"
    do_print_trace "$(do_stack_trace)" "$(id)"
    do_print_info  "$(do_stack_trace)" "$(uname -a)"
  ' || do_print_warn 'do_ssh_exec returned' "$?"
  CIDOER_DEBUG='no'
  do_ssh_export_reset
  [ -n "${SSH_HOST_01:-}" ] && ssh-keygen -R "$SSH_HOST_01"
}

do_func_invoke do_ssh_check_dependencies

test_ssh && do_print_section do_ssh
