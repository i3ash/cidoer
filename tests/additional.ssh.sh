#!/usr/bin/env bash
# shellcheck disable=SC2317
set -eu -o pipefail

source ../cidoer.ssh.sh

test_ssh_prepare() {
  do_ssh_check_dependencies || return $?
  eval "$(ssh-agent -s)" || return $?
  #ssh-add -D || do_print_warn 'ssh-add -D returned' "$?"
  [ -n "${KEY_01:-}" ] && do_func_invoke do_ssh_add_key "$KEY_01" KEY_01_PASSPHRASE
  do_print_trace ssh-add -l
  ssh-add -l || do_print_warn 'ssh-add -l returned' "$?"
  #printf '%q' "$(cat /tmp/id_ed25519)"
  [ -z "${SSH_HOST_01:-}" ] && return 3
  do_ssh_add_known_host "$SSH_HOST_01" "${SSH_PORT_01:-}" || do_print_warn 'do_ssh_add_known_host returned' "$?"
}

test_ssh_exec() {
  [ -z "${SSH_HOST_01:-}" ] && {
    do_print_warn "$(do_stack_trace)" 'Absent env SSH_HOST_01'
    return 1
  }
  local -r jumper="${SSH_USER_01:-upload}@${SSH_HOST_01:?}:${SSH_PORT_01:-22}"
  local -r chain="$(do_ssh_print_chain "$jumper")"
  do_print_trace "$chain"
  do_ssh_export_reset
  #CIDOER_DEBUG='yes'
  do_ssh_exec "$chain" define_cidoer_core define_cidoer_print $'
    do_print_trace "$(do_stack_trace)" "$(do_os_type)" "$(do_host_type)"
    do_print_trace "$(do_stack_trace)" "${CIDOER_SSH_EXPORT_VAR[*]}"
    do_print_trace "$(do_stack_trace)" "$(id)"
    do_print_trace "$(do_stack_trace)" "$(uname -a)"
  ' || do_print_warn 'do_ssh_exec returned' "$?"
  CIDOER_DEBUG='no'
}

test_ssh_exec_chained() {
  [ -z "${SSH_HOST_02:-}" ] && {
    do_print_warn "$(do_stack_trace)" 'Absent env SSH_HOST_02'
    return 1
  }
  local -r jumper="${SSH_USER_01:-upload}@${SSH_HOST_01:?}:${SSH_PORT_01:-22}"
  local -r target="${SSH_USER_02:-debian}@${SSH_HOST_02:?}:${SSH_PORT_02:-22}"
  local -r chain="$(do_ssh_print_chain "$jumper" "$target")"
  demo_fn() {
    do_print_dash_pair 'CIDOER_BAT_AVAILABLE' "${CIDOER_BAT_AVAILABLE:-}"
    do_print_dash_pair 'CIDOER_DIR' "${CIDOER_DIR:-}"
    do_print_dash_pair 'CIDOER_CORE_FILE' "${CIDOER_CORE_FILE:-}"
    do_print_trace "$(do_stack_trace)" "$(do_os_type)" "$(do_host_type)"
    do_print_trace "$(do_stack_trace)" "${CIDOER_SSH_EXPORT_VAR[*]}"
    do_print_trace "$(do_stack_trace)" "$(id)"
    do_print_trace "$(do_stack_trace)" "$(uname -a)"
  }
  do_print_trace "$chain"
  do_ssh_export_reset
  do_ssh_export define_cidoer_print
  #CIDOER_DEBUG='yes'
  do_ssh_exec "$chain" define_cidoer_core demo_fn || do_print_warn 'do_ssh_exec returned' "$?"
  CIDOER_DEBUG='no'
  do_print_code_bash "$(declare -f demo_fn)"
}

define_jumper_do() {
  do_print_section "JUMPER WORKFLOW STEPS BEGIN"
  jumper_do_prepare() {
    do_print_trace "$(do_stack_trace)" "$(uname -a)"
    do_print_trace "$(do_stack_trace)" "$(id)"
    eval "$(ssh-agent -s)" || return $?
    do_ssh_add_key_file ~/.ssh/id_ecdsa SSH_KEY_02_PASSPHRASE ||
      do_print_warn "$(do_stack_trace)" 'do_ssh_add_key_file() ->' "$?"
    do_ssh_add_known_host "$SSH_HOST_02" "${SSH_PORT_02:-}" ||
      do_print_warn "$(do_stack_trace)" 'do_ssh_add_known_host() ->' "$?"
    printf '%s %s\n' "$(do_stack_trace)" '---------- ---------- ----------'
  }
  jumper_do_process() {
    run_on_target() {
      do_print_trace "$(do_stack_trace)" "$(uname -a)"
      do_print_trace "$(do_stack_trace)" "$(id)"
      return 0
    }
    local -r chain="$(do_ssh_print_chain "${TARGET_02:?}")"
    do_ssh_exec "$chain" define_cidoer_print define_cidoer_core run_on_target ||
      do_print_warn "$(do_stack_trace)" $'do_ssh_exec run_on_target() ->' "$?"
    printf '%s %s\n' "$(do_stack_trace)" '---------- ---------- ----------'
  }
  jumper_do_finish() {
    ssh-agent -k
    printf '%s %s\n' "$(do_stack_trace)" '---------- ---------- ----------'
    do_print_section "JUMPER WORKFLOW STEPS DONE!"
  }
}
test_ssh_exec_jumped() {
  [ -z "${SSH_HOST_02:-}" ] && {
    do_print_warn "$(do_stack_trace)" 'Absent env SSH_HOST_02'
    return 1
  }
  local -rx TARGET_02="${SSH_USER_02:-debian}@${SSH_HOST_02:?}"
  local -r jumper="${SSH_USER_01:-upload}@${SSH_HOST_01:?}:${SSH_PORT_01:-22}"
  local -r chain="$(do_ssh_print_chain "$jumper")"
  do_print_trace "$chain" >&2
  do_ssh_export_reset
  do_ssh_export SSH_HOST_02 SSH_KEY_02_PASSPHRASE TARGET_02
  do_ssh_export define_cidoer_print define_cidoer_core
  #CIDOER_DEBUG='yes'
  do_ssh_exec "$chain" define_cidoer_ssh define_cidoer_lock \
    define_jumper_do 'do_workflow_job jumper_do prepare process finish' ||
    do_print_warn "$(do_stack_trace)" 'do_ssh_exec jumper_do() ->' "$?"
  CIDOER_DEBUG='no'
}

test_ssh_archive_dir() {
  [ -z "${SSH_HOST_01:-}" ] && {
    do_print_warn "$(do_stack_trace)" 'Absent env SSH_HOST_01'
    return 1
  }
  pushd .. >/dev/null || return $?
  local -r ssh="$(do_ssh_print_chain "${SSH_USER_01:-upload}@${SSH_HOST_01:?}:${SSH_PORT_01:-22}")"
  do_ssh_export_reset
  #CIDOER_DEBUG='yes'
  do_ssh_archive_dir 'tests' "$ssh" '/tmp/tests.tar.gz' || do_print_warn 'do_ssh_archive_dir failed with' "$?"
  CIDOER_DEBUG='no'
  popd >/dev/null || return $?
}

_on_exit() {
  do_print_trace "$(do_stack_trace)" 'exiting'
  ssh-agent -k 2>/dev/null || do_print_warn "$(do_stack_trace)" 'ssh-agent -k ->' "$?"
  [ -n "${SSH_HOST_01:-}" ] && ssh-keygen -R "$SSH_HOST_01"
}
do_trap_append '_on_exit || :' EXIT SIGHUP SIGINT SIGQUIT SIGTERM

test_ssh_prepare
do_print_section test_ssh_prepare
test_ssh_exec && do_print_section test_ssh_exec
test_ssh_exec_chained && do_print_section test_ssh_exec_chained
test_ssh_exec_jumped && do_print_section test_ssh_exec_jumped
test_ssh_archive_dir && do_print_section test_ssh_archive_dir

trap -p
do_print_dash_pair 'CIDOER_BAT_AVAILABLE' "${CIDOER_BAT_AVAILABLE:-}"
do_print_dash_pair 'CIDOER_DIR' "${CIDOER_DIR:-}"
do_print_dash_pair 'CIDOER_CORE_FILE' "${CIDOER_CORE_FILE:-}"
do_print_section Ended
