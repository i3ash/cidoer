#!/usr/bin/env bats

@test 'do_lock_acquire | Verify that lockf/mkdir is chosen when run on macOS' {
  source ../cidoer.core.sh
  [ "$(do_os_type)" != 'darwin' ] && skip 'if not on macOS'
  [ "${CIDOER_LOCK_METHOD:-}" = 'lockf' ] || [ "${CIDOER_LOCK_METHOD:-}" = 'mkdir' ]
}

@test 'do_lock_acquire | Verify that flock is chosen when run on Linux' {
  source ../cidoer.core.sh
  [ "$(do_os_type)" != 'linux' ] && skip 'if not on Linux'
  [ "${CIDOER_LOCK_METHOD:-}" = 'flock' ]
}

@test 'do_lock_acquire | Verify that mkdir is chosen when run on Windows' {
  source ../cidoer.core.sh
  [ "$(do_os_type)" != 'windows' ] && skip 'if not on Windows'
  [ "${CIDOER_LOCK_METHOD:-}" = 'mkdir' ]
}

@test "do_lock_acquire | Acquire and release lock successfully" {
  source ../cidoer.core.sh
  local -r lock_dir='test.d'
  do_lock_acquire "$lock_dir" 5
  local -r lock_full_dir="/tmp${CIDOER_LOCK_BASE_DIR:-}/$lock_dir"
  [ -d "$lock_full_dir" ]
  [ -f "$lock_full_dir/pid" ]
  do_lock_release "$lock_dir"
  [ ! -d "$lock_full_dir" ]
  [ ! -f "$lock_full_dir/pid" ]
}
