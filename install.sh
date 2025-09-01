#!/bin/bash

# Setup Development Tools
sudo apt -y install \
    code \
    code-insiders \
    git \
    direnv \
    shellcheck \
    shfmt


snap install bash-language-server --classic