#!/bin/bash
# shellcheck disable=SC2317
# This script is intended to be sourced. Functions are called from other scripts.

ITEMS=()

# Check if a file needs sudo to read
if_file_needs_sudo() {
    local file="$1"
    if [ -f "$file" ]; then
        if ! [ -r "$file" ]; then
            echo "File $file needs sudo to read"
            return 1
        fi
    fi
    return 0
}

# If destination exists
if_dest_exists() {
    local dest="$1"
    if [ -e "$dest" ]; then
        echo "Destination $dest already exists"
        return 1
    fi
    return 0
}

# if dest exists, ask user if they want to merge, overwrite, or skip
copy() {
    local src="$1"
    local dest="$2"
    local use_sudo="$3"
    if if_dest_exists "$dest"; then
        echo "Destination $dest already exists. What do you want to do?"
        select option in "Merge" "Overwrite" "Skip"; do
            case "$option" in
                "Merge")
                    merge "$src" "$dest" "$use_sudo"
                    break
                    ;;
                "Overwrite")
                    echo "Overwriting $dest with $src"
                    force_copy "$src" "$dest" "$use_sudo"
                    break
                    ;;
                "Skip")
                    echo "Skipping $src"
                    return
                    ;;
                *)
                    echo "Invalid option"
                    ;;
            esac
        done
    fi
}

merge() {
    local src="$1"
    local dest="$2"
    local use_sudo="$3"
    local OURS="$2.ours"
    local BASE="$2.base"
    local THEIRS="$2.theirs"

    force_copy "$src" "$THEIRS" "$use_sudo"

    # Make a dummy base if it doesn't exist
    [ -f "$BASE" ] || touch "$BASE"

    echo "Opening VS Code merge editor. Please resolve conflicts..."
    code --wait --merge "$OURS" "$BASE" "$OURS" "$THEIRS"

    rm -f "$BASE" "$THEIRS"
    mv "$OURS" "$dest"
}

# Copy src to dest, optionally using sudo. Set permissions on dest after copy.
force_copy() {
    local src="$1"
    local dest="$2"
    local use_sudo="$3"
    local prefix=""
    if [ "$use_sudo" = "1" ]; then
        prefix="sudo "
    fi
    $prefix mkdir -p "$(dirname "$dest")"
    $prefix cp "$src" "$dest"
    $prefix chown "$USER:$USER" "$dest"
    $prefix chmod 664 "$dest"

}

# Attempt to copy a file:dest pair, return 0 on success, 1 on failure
copy_attempt() {
    local pair="$1"
    local src dest answer
    src="${pair%%:*}"
    dest="${pair#*:}"

    if if_file_needs_sudo "$src"; then
        # File does not need sudo, copy normally
        copy "$src" "$dest" 0
    else
        echo "File $src requires sudo to read. Elevate to sudo? (y/n) or skip (s): "
        read -r answer
        case "$answer" in
            y|Y)
                copy "$src" "$dest" 1
                ;;
            s|S)
                echo "Skipped $src"
                ;;
            *)
                echo "Not copying $src"
                ;;
        esac
    fi
}

# Expands all entries in ITEMS and outputs a list of all file:dest pairs
expand_all_items() {
    local entry
    for entry in "${ITEMS[@]}"; do
        expand_entry "$entry"
    done
}

# Expands an entry like "/etc/default/grub:etc/default/grub" into a list of file:dest pairs
# If source is a file, returns just that pair. If a directory, recursively expands all files.
expand_entry() {
    local entry="$1"
    local src dest
    src="${entry%%:*}"
    dest="${entry#*:}"
    if [ -f "$src" ]; then
        echo "$src:$dest"
    elif [ -d "$src" ]; then
        find "$src" -type f | while read -r file; do
            rel_path="${file#"$src"/}"
            echo "$file:$dest/$rel_path"
        done
    fi
}

# Takes an entry string like "/etc/default/grub:etc/default/grub" and checks if the source is a directory
is_entry_source_dir() {
    local entry="$1"
    local src
    src="${entry%%:*}"
    if [ -d "$src" ]; then
        return 0
    else
        return 1
    fi
}

# Remove the config directory if it exists
clean_config_dir() {
    if [ -d "$CONFIG_DIR" ]; then
        rm -rf "$CONFIG_DIR"
    fi
}

# Create the config directory and initialize a git repo if not already present
init_config_dir() {
    mkdir -p "$CONFIG_DIR"
    cd "$CONFIG_DIR" || exit
    if [ ! -d .git ]; then
        git init
    fi
    cd - > /dev/null || exit
}

# Add and commit all files in the config directory
commit_config_dir() {
    cd "$CONFIG_DIR" || exit
    git add .
    git commit -m "Initial commit"
    cd - > /dev/null || exit
}

## Workflow Functions

# --- Clean workspace ---
clean_workspace() {
    clean_config_dir
}


# --- Copy files ---
copy_files() {
    expand_all_items | while read -r pair; do
        copy_attempt "$pair"
    done
}

# --- Initialize git repo ---
init_git_repo() {
    init_config_dir
}

# --- Commit all changes ---
commit_all_changes() {
    commit_config_dir
}

# --- Setup workflow ---
setup() {
    clean_workspace
    copy_files
    init_git_repo
    commit_all_changes
}


load_env() {
    # Load environment variables
    if [ -f ../.env ]; then
        . ../.env
    else
        echo "Error: .env file not found."
        exit 1
    fi

    if [ -z "$CONFIG_DIR" ]; then
        echo "Error: CONFIG_DIR is not defined."
        exit 1
    fi


    # Load ITEMS from config.txt
    if [ -f "config.txt" ]; then
        while IFS= read -r line; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            ITEMS+=("$line")
        done < "config.txt"
    else
        echo "Error: config.txt not found."
        exit 1
    fi
}

load_env