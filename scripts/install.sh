#!/usr/bin/bash
set -e

sudo apt update
sudo apt -y install \
    code \
    code-insiders \
    git \
    shellcheck \
    shfmt \
    curl \
    bats

curl -fsSL https://raw.githubusercontent.com/sigoden/argc/main/install.sh | sudo sh -s -- --to /usr/local/bin