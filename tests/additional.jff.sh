#!/usr/bin/env bash
set -eu -o pipefail

source ../cidoer.jff.sh

#for i in 196 208 226 46 33 45 105 246; do printf '\e[38;5;%dm Color Code %03d \e[0m\n' "$i" "$i"; done
#for i in 196 208 226 46 33 45 105 246; do printf '\e[38;5;0m\e[48;5;%dm Color Code %03d \e[0m\n' "$i" "$i"; done

for i in {0..15}; do printf '\e[48;5;%dm \e[38;5;0m%03d \e[0m' "$i" "$i"; done
printf '\n'

for i in {0..215}; do
  printf '\e[48;5;%dm \e[38;5;0m%03d \e[0m' "$((i + 16))" "$((i + 16))"
  if [ $(((i + 1) % 36)) -eq 0 ]; then printf '\n'; fi
done
for i in {232..255}; do printf '\e[48;5;%dm \e[38;5;0m%03d \e[0m' "$i" "$i"; done
printf '\n'

do_print_bitmap_24bits || :
do_print_bitmap_24bits ./rider.bmp '@@@' || exit $?

do_print_bitmap_8bits || :
do_print_bitmap_8bits ./rider.bmp '000' || exit $?
