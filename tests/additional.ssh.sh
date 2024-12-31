#!/usr/bin/env bash
set -eu -o pipefail

[ -f ../cidoer.core.sh ] && source ../cidoer.core.sh
[ -f ../cidoer.ssh.sh ] && source ../cidoer.ssh.sh

do_func_invoke do_ssh_check_dependencies

test_ssh() {
  _abc="'exiting'"
  _on_exit() {
    do_print_warn "$(do_stack_trace)" "$_abc"
  }
  trap _on_exit EXIT
  ! do_ssh_agent_ensure && return 2
  #ssh-add -D || do_print_warn 'ssh-add -D returned' "$?"
  do_func_invoke do_ssh_add_key "${KEY_01:-}" KEY_01_PASSPHRASE
  do_print_trace ssh-add -l
  ssh-add -l || do_print_warn 'ssh-add -l returned' "$?"
  #printf '%q' "$(cat /tmp/id_ed25519)"
  [ -z "${SSH_HOST_01:-}" ] && return 3
  do_ssh_add_known_host "$SSH_HOST_01" "${SSH_PORT_01:-}" || do_print_warn 'do_ssh_add_known_host returned' "$?"
  local -r chain="$(do_ssh_print_chain "${SSH_USER_01:-debian}@$SSH_HOST_01")"
  do_ssh_export define_cidoer_core define_cidoer_ssh
  #CIDOER_DEBUG='yes'
  do_ssh_exec "$chain" $'
    define_cidoer_core
    define_cidoer_ssh
    do_print_info "$(do_stack_trace)" "${CIDOER_SSH_EXPORT_VAR[*]}"
    do_print_info "$(do_stack_trace)" "$(id)"
  '
  #CIDOER_DEBUG='no'
  do_ssh_export_reset
  ssh-keygen -R "$SSH_HOST_01"
}

test_ssh && do_print_section do_ssh
