#!/usr/bin/env bash
set -eu -o pipefail

[ -f ../cidoer.jff.sh ] && source ../cidoer.jff.sh

do_print_24bit_bitmap ./kid.bmp || :
do_print_24bit_bitmap || :
