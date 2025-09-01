#!/usr/bin/bash
set -e


# shellcheck source=../lib/files.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/console.sh"
. ./lib/files.sh

update_initramfs