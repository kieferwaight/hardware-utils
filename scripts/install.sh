#!/usr/bin/bash
set -e

sudo apt update
sudo apt -y install \
    code \
    code-insiders \
    git \ # direnv \
    shellcheck \
    shfmt
