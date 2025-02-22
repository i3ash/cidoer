#!/usr/bin/env bash
# shellcheck disable=SC2317
declare -F 'define_ssh' >/dev/null && return 0
set -eu -o pipefail

define_ssh() {
  declare -F 'ssh_prepare' >/dev/null && return 0
  ssh_prepare() {
    do_print_section "SSH WORKFLOW BEGIN"
    do_print_dash_pair "${FUNCNAME[0]}"
    SSH_COMMAND="${ARG_SSH_COMMAND:-${SSH_PROXY_JUMP:-}}"
    do_print_dash_pair 'SSH_COMMAND' "${SSH_COMMAND-}"
    [ -z "${SSH_COMMAND-}" ] && return 11
    do_ssh_ensure_agent || return $?
    local SSH_WORK_HOME="${ARG_SSH_WORK_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    SSH_ARCHIVE_GROUP="${ARG_SSH_ARCHIVE_GROUP:-${SSH_WORK_HOME##*/}}"
    SSH_ARCHIVE_DIR="${ARG_SSH_ARCHIVE_DIR-}"
    SSH_ARCHIVE_NAME="${ARG_SSH_ARCHIVE_NAME:?}"
    SSH_ARCHIVE_PATH="${ARG_SSH_ARCHIVE_PATH:-/tmp/${SSH_ARCHIVE_GROUP:?}/${SSH_ARCHIVE_NAME:?}.tgz}"
    SSH_PROCESS_HOME="${ARG_SSH_PROCESS_HOME:-/tmp/${SSH_ARCHIVE_GROUP:?}}"
    SSH_NESTED_WORKFLOW="${ARG_SSH_NESTED_WORKFLOW:-process_${SSH_ARCHIVE_NAME}}"
    _prepare_ssh_key
    _prepare_ssh_known
    do_func_invoke ssh_prepare_do
    do_print_trace "$(do_stack_trace)" done!
  }
  ssh_upload() {
    do_print_dash_pair "${FUNCNAME[0]}"
    do_print_dash_pair 'SSH_ARCHIVE_DIR' "${SSH_ARCHIVE_DIR-}"
    do_print_dash_pair 'SSH_ARCHIVE_NAME' "${SSH_ARCHIVE_NAME-}"
    do_print_dash_pair 'SSH_ARCHIVE_PATH' "${SSH_ARCHIVE_PATH-}"
    [ -z "${SSH_ARCHIVE_NAME-}" ] && return 11
    [ -z "${SSH_ARCHIVE_PATH-}" ] && return 12
    "define_${SSH_NESTED_WORKFLOW-}" || return $?
    [ -n "${SSH_ARCHIVE_DIR-}" ] && { pushd "${SSH_ARCHIVE_DIR-}" || return $?; }
    do_ssh_archive_dir "$SSH_ARCHIVE_NAME" "$SSH_COMMAND" "$SSH_ARCHIVE_PATH" || return $?
    popd || :
    do_print_trace "$(do_stack_trace)" done!
  }
  do_ssh_export_all() {
    do_ssh_export_reset
    do_ssh_export SSH_ARCHIVE_GROUP SSH_ARCHIVE_NAME \
      SSH_ARCHIVE_PATH SSH_PROCESS_HOME SSH_NESTED_WORKFLOW
    do_ssh_export define_cidoer_print
    do_func_invoke ssh_export_do
  }
  ssh_process_finally() { return 0; }
  ssh_process() {
    do_print_dash_pair "${FUNCNAME[0]}"
    do_ssh_export_all
    do_ssh_exec "$SSH_COMMAND" define_cidoer_core "define_${SSH_NESTED_WORKFLOW-}" _process
    do_print_trace "$(do_stack_trace)" done!
  }
  _process() {
    [ -n "${SSH_ARCHIVE_NAME-}" ] || return 11
    [ -n "${SSH_ARCHIVE_PATH-}" ] || return 12
    local -r dir="${SSH_PROCESS_HOME:-/tmp}"
    mkdir -p "$dir/${SSH_ARCHIVE_NAME-}" || return $?
    pushd "$dir" >/dev/null || return $?
    tar xzf "$SSH_ARCHIVE_PATH" || return $?
    popd >/dev/null
    pushd "$dir/${SSH_ARCHIVE_NAME-}" >/dev/null || return $?
    do_print_dash_pair 'SSH_ARCHIVE_GROUP' "${SSH_ARCHIVE_GROUP-}"
    do_print_dash_pair 'SSH_ARCHIVE_NAME' "${SSH_ARCHIVE_NAME-}"
    do_print_dash_pair 'SSH_ARCHIVE_PATH' "${SSH_ARCHIVE_PATH-}"
    do_print_dash_pair 'SSH_PROCESS_HOME' "${SSH_PROCESS_HOME-}"
    do_func_invoke ssh_process_do
    popd >/dev/null
  }
  ssh_prune_finally() { return 0; }
  ssh_prune() {
    do_print_dash_pair "${FUNCNAME[0]}"
    do_ssh_export_all
    do_ssh_exec "$SSH_COMMAND" define_cidoer_core "define_${SSH_NESTED_WORKFLOW-}" _prune
    do_print_trace "$(do_stack_trace)" done!
  }
  _prune() {
    do_print_dash_pair "${FUNCNAME[0]}"
    [ -n "${SSH_ARCHIVE_PATH-}" ] || {
      do_print_warn 'SSH_ARCHIVE_PATH is absent'
      return 11
    }
    rm "${SSH_ARCHIVE_PATH:-}" || :
    rm "${SSH_ARCHIVE_PATH:-}.sha256" || :
    [ -n "${SSH_PROCESS_HOME-}" ] || {
      do_print_warn 'SSH_PROCESS_HOME is absent'
      return 12
    }
    pushd "$SSH_PROCESS_HOME" >/dev/null || return $?
    do_func_invoke ssh_prune_do || :
    [ -n "${SSH_ARCHIVE_NAME-}" ] && { rm -rf "$SSH_ARCHIVE_NAME" || :; }
    popd >/dev/null
    do_print_trace "$(do_stack_trace)" done!
  }

  ssh_finish_finally() {
    do_print_section "SSH WORKFLOW DONE!"
    return 0
  }
  ssh_finish() {
    do_print_dash_pair "${FUNCNAME[0]}"
    do_ssh_exec "$SSH_COMMAND" define_cidoer_core "define_${SSH_NESTED_WORKFLOW-}" 'do_func_invoke ssh_finish_do'
    do_print_trace "$(do_stack_trace)" done!
  }
  _prepare_ssh_key() {
    [ -n "${KEY_01:-}" ] && do_ssh_add_key "$KEY_01" KEY_01_PASSPHRASE
    do_print_trace 'ssh-add -l'
    ssh-add -l || do_print_warn 'ssh-add -l returned' "$?"
  }
  _prepare_ssh_known() {
    [ -n "${SSH_HOST_01:-}" ] && {
      do_ssh_add_known_host "$SSH_HOST_01" "${SSH_PORT_01:-}" || :
      [ -n "${SSH_HOST_02:-}" ] && {
        local -r known_hosts_file="${HOME:?}/.ssh/known_hosts"
        local -r ssh="ssh -p $SSH_PORT_01 debian@$SSH_HOST_01"
        local -r result=$(do_ssh_exec "$ssh" "ssh-keyscan -H -p 22 $SSH_HOST_02 2>/dev/null" | grep -v '^#')
        [ -n "$result" ] && {
          printf '%s\n' "$result" >>"$known_hosts_file"
        }
      }
    }
    do_trap_append '_delete_ssh_known || :' EXIT SIGHUP SIGINT SIGQUIT SIGTERM
  }
  _delete_ssh_known() {
    do_print_trace "$(do_stack_trace)" begin
    [ -n "${SSH_HOST_02:-}" ] && {
      do_print_trace "$(do_stack_trace)" "$SSH_HOST_02"
      do_ssh_rm_known_host "$SSH_HOST_02" "${SSH_PORT_02:-}" || :
    }
    [ -n "${SSH_HOST_01:-}" ] && {
      do_print_trace "$(do_stack_trace)" "$SSH_HOST_01"
      do_ssh_rm_known_host "$SSH_HOST_01" "${SSH_PORT_01:-}" || :
    }
    do_print_trace "$(do_stack_trace)" done!
  }
}

declare -F 'define_cidoer_ssh' >/dev/null || {
  CIDOER_DIR="${CIDOER_DIR:-$(dirname "${BASH_SOURCE[0]}")}"
  [ -f "$CIDOER_DIR"/cidoer.ssh.sh ] && . "$CIDOER_DIR"/cidoer.ssh.sh
}
define_ssh
do_check_bats_core || do_print_trace "$(do_reverse "${BASH_SOURCE[@]}")"
