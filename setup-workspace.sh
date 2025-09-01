#!/bin/bash

set -e

. ./lib/files.sh

clean_workspace
# expand_all_items


copy "/etc/logrotate.d/btmp" "etc/logrotate.d/btmp" 0