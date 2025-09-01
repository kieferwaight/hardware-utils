#!/bin/bash

# Load environment variables
if [ -f .env ]; then
    . .env
else
    echo "Error: .env file not found."
    exit 1
fi

if [ -z "$CONFIG_DIR" ]; then
    echo "Error: CONFIG_DIR is not defined."
    exit 1
fi

if [ -d "$CONFIG_DIR" ]; then
    # Remove all symlinks in CONFIG_DIR
    find "$CONFIG_DIR" -type l -exec rm -v {} +
fi

# Check if CONFIG_DIR is empty and remove it if so
if [ -d "$CONFIG_DIR" ] && [ -z "$(ls -A "$CONFIG_DIR")" ]; then
    echo "$CONFIG_DIR is empty, removing directory."
    rmdir "$CONFIG_DIR"
fi

exit 0