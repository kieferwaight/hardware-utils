#!/bin/bash
# shellcheck disable=SC2317
#
# files.sh - File management utilities for config backup/restore.
# Intended to be sourced by other scripts.
#
# Main entry points:
#   setup   - Clean workspace, copy files, initialize git, commit.
#   update  - Commit changes, copy files, commit again.
#   clean   - Remove config directory.
#

# --- Globals ---
ITEMS=()

# --- Logging & Error Handling ---
log() {
    echo "[*] $1"
}

err() {
    echo "[!] $1" >&2
}

throw() {
    echo "[!] $1" >&2
    exit 1
}

# --- File Utilities ---

# Returns 0 if file exists and needs sudo to read, else 1
if_file_needs_sudo() {
    local file="$1"
    [ -f "$file" ] && [ ! -r "$file" ]
}

# Returns 0 if destination file exists
if_dest_exists() {
    local file="$1"
    [ -f "$file" ]
}

# Returns 0 if files differ, 1 if identical or missing
if_files_are_different() {
    local file1="$1"
    local file2="$2"
    [ -f "$file1" ] && [ -f "$file2" ] && ! cmp -s "$file1" "$file2"
}

# --- Copy/Merge Logic ---

# Copy src to dest, handling merge/overwrite/skip if dest exists
copy() {
    local src="$1"
    local dest="$2"
    local use_sudo="$3"

    if if_dest_exists "$dest"; then
        log "Destination $dest already exists."
        if if_files_are_different "$src" "$dest"; then
            log "Source $src and destination $dest differ."
            log "What do you want to do?"
            # Redirect input to /dev/tty so it comes from the keyboard
            select option in "Merge" "Overwrite" "Skip"; do
                case "$option" in
                    "Merge")
                        merge "$src" "$dest" "$use_sudo"
                        log "Merge completed."
                        break
                        ;;
                    "Overwrite")
                        log "Overwriting $dest with $src"
                        force_copy "$src" "$dest" "$use_sudo"
                        break
                        ;;
                    "Skip")
                        log "Skipping $src"
                        return
                        ;;
                    *)
                        log "Invalid option"
                        ;;
                esac
            done < /dev/tty
        else
            log "Source $src and destination $dest are identical. Skipping."
            return
        fi
    else
        log "Copying $src to $dest"
        force_copy "$src" "$dest" "$use_sudo"
    fi
}

# Merge src and dest using VS Code merge editor
merge() {
    local src="$1"
    local dest="$2"
    local use_sudo="$3"
    local OURS="$dest.ours"
    local BASE="$dest.base"
    local THEIRS="$dest.theirs"

    mkdir -p "$(dirname "$BASE")"
    [ -f "$BASE" ] || touch "$BASE"

    force_copy "$src" "$THEIRS" "$use_sudo"
    force_copy "$dest" "$OURS" 0

    log "Opening VS Code merge editor. Please resolve conflicts..."
    code --wait --merge "$OURS" "$THEIRS" "$BASE" "$dest"

    rm -f "$BASE" "$THEIRS" "$OURS"
}

# Copy src to dest, optionally using sudo, and set permissions
force_copy() {
    local src="$1"
    local dest="$2"
    local use_sudo="$3"
    local prefix=""

    [ "$use_sudo" = "1" ] && prefix="sudo "
    $prefix mkdir -p "$(dirname "$dest")"
    $prefix cp "$src" "$dest"
    $prefix chown "$(id -un):$(id -gn)" "$dest"
    $prefix chmod 664 "$dest"
}

# Attempt to copy a file:dest pair, prompt for sudo if needed
copy_attempt() {
    local pair="$1"
    local src dest answer
    src="${pair%%:*}"
    dest="${pair#*:}"

    if if_file_needs_sudo "$src"; then
        log "File $src requires sudo to read. Elevate to sudo? (y/n) or skip (s): "
        read -r answer < /dev/tty
        case "$answer" in
            y | Y) copy "$src" "$dest" 1 ;;
            s | S) log "Skipped $src" ;;
            *) log "Not copying $src" ;;
        esac
    else
        copy "$src" "$dest" 0
    fi
}

# --- Entry Expansion Utilities ---

# Expand all entries in ITEMS to file:dest pairs
expand_all_items() {
    local entry
    for entry in "${ITEMS[@]}"; do
        expand_entry "$entry"
    done
}

# Expand entry "/etc/foo:etc/foo" or "/etc/dir:etc/dir"
expand_entry() {
    local entry="$1"
    local src dest rel_path
    src="${entry%%:*}"
    dest="$CONFIG_DIR/${entry#*:}"
    if [ -f "$src" ]; then
        echo "$src:$dest"
    elif [ -d "$src" ]; then
        find "$src" -type f | while read -r file; do
            rel_path="${file#"$src"/}"
            echo "$file:$dest/$rel_path"
        done
    fi
}

# Returns 0 if entry's source is a directory
is_entry_source_dir() {
    local entry="$1"
    local src="${entry%%:*}"
    [ -d "$src" ]
}

# --- Config Directory Management ---

# Remove the config directory if it exists
clean_config_dir() {
    if [ -n "$CONFIG_DIR" ] && [ -d "$CONFIG_DIR" ]; then
        sudo rm -rf "$CONFIG_DIR"
    fi
}

# Create config directory and initialize git repo if needed
init_config_dir() {
    mkdir -p "$CONFIG_DIR"
    cd "$CONFIG_DIR" || exit 1
    [ ! -d .git ] && git init
    cd - >/dev/null || exit 1
}

# Add and commit all files in config directory
commit_config_dir() {
    cd "$CONFIG_DIR" || exit 1
    git add .
    if ! git diff --cached --quiet; then
        git commit -m "Update"
    else
        log "No changes to commit."
    fi
    cd - >/dev/null || exit 1
}

# --- Workflow Functions (Main Entry Points) ---

# Remove config directory (clean workspace)
clean() {
    clean_config_dir
}

# Copy all files from ITEMS to config directory
copy_files() {
    expand_all_items | while read -r pair; do
        copy_attempt "$pair"
    done
}

# Initialize git repo in config directory
init_git_repo() {
    init_config_dir
}

# Commit all changes in config directory
commit_all_changes() {
    commit_config_dir
}

# Full setup: clean, copy, init git, commit
setup() {
    clean
    copy_files
    init_git_repo
    commit_all_changes
}

# Update: commit, copy, commit again
update() {
    commit_all_changes
    copy_files
    commit_all_changes
}

# --- Environment Loader ---

# Load .env and config.txt, populate CONFIG_DIR and ITEMS
load_env() {
    if [ -f .env ]; then
        # shellcheck source=../.env
        . .env
    else
        throw "Error: .env file not found."
    fi

    if [ -z "$CONFIG_DIR" ]; then
        throw "Error: CONFIG_DIR is not defined."
    fi

    if [ -f "config.txt" ]; then
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^# ]] && continue
            ITEMS+=("$line")
        done <"config.txt"
    else
        throw "Error: config.txt not found."
    fi
}

# --- Script Initialization ---

load_env
# Main entry points: setup, update, clean
