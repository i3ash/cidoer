#!/usr/bin/env bash
set -eu -o pipefail

[ -f ../cidoer.jff.sh ] && source ../cidoer.jff.sh

do_print_bitmap_8bits ./kid.bmp || exit $?
do_print_bitmap_24bits ./kid.bmp || exit $?
do_print_24bit_bitmap || :
