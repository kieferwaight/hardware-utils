#!/usr/bin/env bash
# @describe Linux System Administration and Development Toolkit
# @meta version 1.0.0

# @cmd Run system installation setup
# @alias i
install() {
    echo "Running system installation..."
    make install
}

# @cmd Setup configuration files and workspace
# @alias s
setup() {
    echo "Setting up workspace and configuration files..."
    make setup
}

# @cmd Clean workspace and configuration
# @alias c
clean() {
    echo "Cleaning workspace..."
    make clean
}

# @cmd Update system and configurations
# @alias u
update() {
    echo "Updating system and configurations..."
    make update
}

# @cmd Run argc examples and demos
# @alias d
demos() {
    echo "Available argc demos:"
    echo "  - demo.sh: Basic CLI demo"
    echo "  - args.sh: Argument handling examples"
    echo "  - options.sh: Options and flags examples"
    echo "  - nested-commands.sh: Nested command examples"
    echo ""
    echo "To run a demo, use: bash docs/argc/DEMO_NAME.sh --help"
    echo "Example: bash docs/argc/demo.sh --help"
}

# @cmd List available graphics and display management tools
# @alias g
graphics() {
    echo "Running graphics and display management tool..."
    export PATH="$HOME:$PATH"
    bash lib/graphics.sh "$@"
}

# @cmd Show system information
info() {
    echo "System Information:"
    uname -a
    echo ""
    echo "Available tools:"
    echo "  - make: Build system with targets (help, setup, install, clean, update)"
    echo "  - argc examples: Located in docs/argc/"
    echo "  - graphics tools: lib/graphics.sh"
    echo "  - file management: lib/files.sh"
}

# Export PATH to include argc
export PATH="$HOME:$PATH"

# Initialize argc if available
eval "$(argc --argc-eval "$0" "$@")"