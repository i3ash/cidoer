#!/usr/bin/env bash
# shellcheck disable=SC2317
declare -F 'define_cidoer_jff' >/dev/null && return 0
set -eou pipefail

define_cidoer_jff() {
  declare -F 'do_print_24bit_bitmap' >/dev/null && return 0
  do_print_bitmap_8bits() {
    [ -z "${1:-}" ] && {
      printf 'Usage: %s <bmp_file_path> [tiled_chars]\n' "${FUNCNAME[0]}" >&2
      return 1
    }
    _print_bitmap "$1" 8 "${2:-}"
  }
  do_print_bitmap_24bits() {
    [ -z "${1:-}" ] && {
      printf 'Usage: %s <bmp_file_path> [tiled_chars]\n' "${FUNCNAME[0]}" >&2
      return 1
    }
    _print_bitmap "$1" 24 "${2:-}"
  }
  _print_bitmap() {
    local -r bmp_file="${1:-}" color_bits="${2:-24}" tile="${3:-000}"
    [ -z "$bmp_file" ] && return 1
    if ! [ -f "$bmp_file" ]; then
      printf 'Not a file: %s\n' "$bmp_file" >&2
      return 1
    fi
    local header_hex
    header_hex=$(_hex_read "$bmp_file" 0 54) || return $?
    local -r signature="${header_hex:0:4}"
    if [ "$signature" != "424d" ]; then
      printf "This file is not a standard BMP (no 'BM' signature detected)\n" >&2
      return 1
    fi
    local -r bpp_offset=$((28 * 2))
    local -r bpp=$(_hex_le16_to_dec "${header_hex:bpp_offset:4}")
    if [ "$bpp" -ne 24 ]; then
      printf 'Only 24-bit uncompressed BMP is supported. Current bpp=%d\n' "$bpp" >&2
      return 1
    fi
    local -r comp_offset=$((30 * 2))
    local -r compression=$(_hex_le32_to_dec "${header_hex:comp_offset:8}")
    if [ "$compression" -ne 0 ]; then
      printf 'Compressed BMP files are not supported (compression=%d)\n' "$compression" >&2
      return 1
    fi
    local -r data_offset_offset=$((10 * 2))
    local -r data_offset=$(_hex_le32_to_dec "${header_hex:data_offset_offset:8}")
    local -r width_offset=$((18 * 2))
    local -r width=$(_hex_le32_to_dec "${header_hex:width_offset:8}")
    local -r height_offset=$((22 * 2))
    local -r height=$(_hex_le32_to_dec "${header_hex:height_offset:8}")
    local -r row_bytes=$((((width * 3) + 3) & ~3))
    local -r max_chunk_bytes="${CIDOER_READ_CHUNK_BYTES:-1048576}"
    local max_rows_for_chunk
    max_rows_for_chunk=$((max_chunk_bytes / row_bytes))
    [ "$max_rows_for_chunk" -lt 1 ] && max_rows_for_chunk=1
    [ "$max_rows_for_chunk" -gt "$height" ] && max_rows_for_chunk="$height"
    local -r chunk_rows="$max_rows_for_chunk"
    local current_row=$((height - 1))
    while [ "$current_row" -ge 0 ]; do
      local rows_left=$((current_row + 1))
      local rows_to_read="$chunk_rows"
      [ "$rows_left" -lt "$chunk_rows" ] && rows_to_read="$rows_left"
      local chunk_start_row=$((current_row - (rows_to_read - 1)))
      local file_offset=$((data_offset + chunk_start_row * row_bytes))
      local chunk_bytes=$((rows_to_read * row_bytes))
      local chunk_hex
      chunk_hex=$(_hex_read "$bmp_file" "$file_offset" "$chunk_bytes") || return $?
      local row_hex_length=$((row_bytes * 2))
      local -i row col
      for ((row = rows_to_read - 1; row >= 0; row--)); do
        local row_start=$((row * row_hex_length))
        local row_hex="${chunk_hex:row_start:row_hex_length}"
        for ((col = 0; col < width; col++)); do
          local pixel_start=$((col * 6))
          local B="${row_hex:pixel_start:2}"
          local G="${row_hex:pixel_start+2:2}"
          local R="${row_hex:pixel_start+4:2}"
          local Bd=$((16#$B))
          local Gd=$((16#$G))
          local Rd=$((16#$R))
          [ "$color_bits" -eq 8 ] && {
            local R6=$((Rd / 51))
            local G6=$((Gd / 51))
            local B6=$((Bd / 51))
            local color_index=$((16 + 36 * R6 + 6 * G6 + B6))
            printf '\033[38;5;%dm%s\033[0m' "$color_index" "$tile"
            continue
          }
          printf '\033[38;2;%d;%d;%dm%s\033[0m' "$Rd" "$Gd" "$Bd" "$tile"
        done
        printf '\n'
      done
      current_row=$((current_row - rows_to_read))
    done
  }
  _hex_read() {
    local -r file="${1:-}" offset="${2:-}" length="${3:-}"
    if command -v od >/dev/null 2>&1; then
      od -An -tx1 -j "$offset" -N "$length" "$file" | tr -d ' \n'
    elif command -v hexdump >/dev/null 2>&1; then
      hexdump -v -e '1/1 "%02x"' -s "$offset" -n "$length" "$file" | tr -d '\n'
    elif command -v xxd >/dev/null 2>&1; then
      xxd -p -l "$length" -s "$offset" "$file" | tr -d '\n'
    else
      return 120
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
