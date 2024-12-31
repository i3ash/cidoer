#!/usr/bin/env bash
set -eou pipefail

for i in 196 208 226 46 33 45 105 246; do printf '\e[38;5;%sm Color Code %03s \e[0m\n' "$i" "$i"; done
for i in 196 208 226 46 33 45 105 246; do printf '\e[48;5;%sm Color Code %03s \e[0m\n' "$i" "$i"; done
for i in {0..15}; do printf '\e[48;5;%sm %03d \e[0m' "$i" "$i"; done
printf '\n'
for i in {0..215}; do
  printf '\e[48;5;%sm %03d \e[0m' "$((i + 16))" "$((i + 16))"
  if [ $(((i + 1) % 36)) -eq 0 ]; then printf '\n'; fi
done
for i in {232..255}; do printf '\e[48;5;%sm %03d \e[0m' "$i" "$i"; done
printf '\n'

source ../cidoer.core.sh

/usr/bin/env bash additional.core.sh || do_print_warn 'bash additional.core.sh returned' "$?"
