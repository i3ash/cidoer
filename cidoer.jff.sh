#!/usr/bin/env bash
# shellcheck disable=SC2317
declare -F 'define_cidoer_jff' >/dev/null && return 0
set -eou pipefail

define_cidoer_jff() {
  declare -F 'do_print_24bit_bitmap' >/dev/null && return 0
  do_print_24bit_bitmap() {
    local -r bmp_file="${1:-}"
    if [ -z "$bmp_file" ] || [ ! -f "$bmp_file" ]; then
      printf 'Usage: %s <bmp_file_path>\n' "${FUNCNAME[0]}"
      return 1
    fi
    local -r signature=$(_hex_read "$bmp_file" 0 2) || return $?
    if [ "$signature" != "424d" ]; then
      printf "This file is not a standard BMP (no 'BM' signature detected).\n"
      return 1
    fi
    local -r bpp_hex=$(_hex_read "$bmp_file" 0x1c 2) || return $?
    local -r bpp="$(_hex_le16_to_dec "$bpp_hex")"
    if [ "$bpp" -ne 24 ]; then
      printf 'Only 24-bit uncompressed BMP is supported. Current bpp=%d\n' "$bpp"
      return 1
    fi
    local -r comp_hex=$(_hex_read "$bmp_file" 0x1e 4) || return $?
    local -r compression="$(_hex_le32_to_dec "$comp_hex")"
    if [ "$compression" -ne 0 ]; then
      printf 'Compressed BMP files are not supported (compression=%d).\n' "$compression"
      return 1
    fi
    local -r width_hex=$(_hex_read "$bmp_file" 0x12 4) || return $?
    local -r height_hex=$(_hex_read "$bmp_file" 0x16 4) || return $?
    local -r offset_hex=$(_hex_read "$bmp_file" 0x0a 4) || return $?
    local -r size_hex=$(_hex_read "$bmp_file" 0x22 4) || return $?
    local -r width="$(_hex_le32_to_dec "$width_hex")"
    local -r height="$(_hex_le32_to_dec "$height_hex")"
    local -r data_offset="$(_hex_le32_to_dec "$offset_hex")"
    local -r image_size="$(_hex_le32_to_dec "$size_hex")"
    [ "$image_size" -eq 0 ] && image_size=$((width * height * 3))
    local -r row_bytes=$((((width * 3) + 3) & ~3))
    local col row row_data
    for ((row = height - 1; row >= 0; row--)); do
      local row_offset=$((data_offset + row * row_bytes))
      row_data=$(_hex_read "$bmp_file" "$row_offset" $((width * 3))) || return $?
      for ((col = 0; col < width; col++)); do
        local start=$((col * 6))
        local B="${row_data:start:2}"
        local G="${row_data:start+2:2}"
        local R="${row_data:start+4:2}"
        local Bd=$((16#$B))
        local Gd=$((16#$G))
        local Rd=$((16#$R))
        #printf '\033[48;2;%d;%d;%dm%s\033[0m' "${Rd}" "${Gd}" "${Bd}" '   '
        printf '\033[38;2;%d;%d;%dm%s\033[0m' "${Rd}" "${Gd}" "${Bd}" '000'
      done
      printf '\n'
    done
  }
  _hex_read() {
    local -r file="${1:-}" offset="${2:-}" length="${3:-}"
    if command -v xxd >/dev/null 2>&1; then
      xxd -p -l "$length" -s "$offset" "$file" | tr -d '\n'
    elif command -v hexdump >/dev/null 2>&1; then
      hexdump -v -e '1/1 "%02x"' -s "$offset" -n "$length" "$file" | tr -d '\n'
    else
      return 1
    fi
  }
  _hex_le16_to_dec() {
    local -r hex_le="${1:-}"
    [ "${#hex_le}" -ne 4 ] && {
      printf 0
      return 0
    }
    local -r reversed="${hex_le:2:2}${hex_le:0:2}"
    printf '%d' $((16#$reversed))
  }
  _hex_le32_to_dec() {
    local -r hex_le="${1:-}"
    [ "${#hex_le}" -ne 8 ] && {
      printf 0
      return 0
    }
    local -r reversed="${hex_le:6:2}${hex_le:4:2}${hex_le:2:2}${hex_le:0:2}"
    printf '%d' $((16#$reversed))
  }
}

define_cidoer_jff
