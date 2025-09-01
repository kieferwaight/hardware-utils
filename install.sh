#!/usr/bin/bash
set -e

sudo apt update

# Setup Development Tools
sudo apt -y install \
    code \
    code-insiders \
    git \ # direnv \
    shellcheck \
    shfmt


# snap install bash-language-server --classic

# sudo apt install bubblewrap
# sudo apt install h2o