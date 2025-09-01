#!/bin/bash
#
# files.sh - File management utilities for config backup/restore.
# Intended to be sourced by other scripts.
#
# Main entry points:
#   setup   - Clean workspace, copy files, initialize git, commit.
#   update  - Commit changes, copy files, commit again.
#   clean   - Remove config directory.
#
set -euo pipefail

# --- Globals ---
declare -a ITEM_LIST=()
EDITOR="${EDITOR:-code}"
DRY_RUN="${DRY_RUN:-0}"
INTERACTIVE="${INTERACTIVE:-1}"

# --- Colors ---
readonly RED="\033[1;31m"
readonly GREEN="\033[1;32m"
readonly YELLOW="\033[1;33m"
readonly CYAN="\033[1;36m"
readonly RESET="\033[0m"

# --- Logging & Error Handling ---
log()    { printf "%b\n" "${GREEN}[*]${RESET} $1"; }
warn()   { printf "%b\n" "${YELLOW}[!]${RESET} $1"; }
info()   { printf "%b\n" "${CYAN}[*]${RESET} $1"; }
error()  { printf "%b\n" "${RED}[!]${RESET} $1" >&2; }
fail()   { error "$1"; exit 1; }


# --- Prerequisite Checks ---
BASH_MAJOR_VERSION="${BASH_VERSION%%.*}"
if [ "${BASH_MAJOR_VERSION:-0}" -lt 4 ]; then
    fail "Bash 4.0+ is required."
fi

if ! command -v git >/dev/null 2>&1; then
    fail "Git is required."
fi


# --- File Utilities ---

# Returns 0 if file exists and requires sudo to read
file_requires_sudo() {
    local file="$1"
    [ -f "$file" ] && [ ! -r "$file" ]
}

# Returns 0 if destination file exists
destination_exists() {
    local file="$1"
    [ -f "$file" ]
}

# Returns 0 if files differ, 1 if identical or missing
files_differ() {
    local file1="$1"
    local file2="$2"
    [ -f "$file1" ] && [ -f "$file2" ] && ! cmp -s "$file1" "$file2"
}

# Sanitizes a file path by resolving symlinks and checking for invalid components
sanitize_path() {
    local path="$1"
    # Allow non-existent destination files, but check for invalid components
    if [[ "$path" == *".."* ]]; then
        fail "Invalid path (contains ..): $path"
    fi
    if [[ "$path" = /* ]]; then
        : # absolute paths are allowed
    fi
    if [ -e "$path" ]; then
        realpath "$path" 2>/dev/null || fail "Invalid path: $path"
    else
        # For non-existent files, check parent dir
        local parent
        parent="$(dirname -- "$path")"
        if [ -d "$parent" ]; then
            realpath "$parent" 2>/dev/null >/dev/null || fail "Invalid parent directory: $parent"
        fi
    fi
}

# --- Copy/Merge Logic ---

copy_file() {
    local src="$1"
    local dest="$2"
    local use_sudo="$3"

    if [ "$INTERACTIVE" -eq 0 ]; then
        force_copy "$src" "$dest" "$use_sudo"
        return
    fi

    if destination_exists "$dest"; then
        log "Destination $dest already exists."
        if files_differ "$src" "$dest"; then
            log "Source $src and destination $dest differ."
            log "Choose action:"
            select option in "Merge" "Overwrite" "Skip"; do
                case "$option" in
                    "Merge") merge_files "$src" "$dest" "$use_sudo"; break ;;
                    "Overwrite") force_copy "$src" "$dest" "$use_sudo"; break ;;
                    "Skip") log "Skipping $src"; return ;;
                    *) warn "Invalid option" ;;
                esac
            done < /dev/tty
        else
            log "Source $src and destination $dest are identical. Skipping."
        fi
    else
        force_copy "$src" "$dest" "$use_sudo"
    fi
}

merge_files() {
    local src="$1"
    local dest="$2"
    local use_sudo="$3"
    local OURS="$dest.ours"
    local BASE="$dest.base"
    local THEIRS="$dest.theirs"
    local prefix=""
    [ "$use_sudo" = "1" ] && prefix="sudo "

    $prefix mkdir -p "$(dirname "$BASE")"
    if [ ! -f "$BASE" ]; then
        $prefix touch "$BASE"
    fi

    force_copy "$src" "$THEIRS" "$use_sudo"
    force_copy "$dest" "$OURS" "$use_sudo"

    log "Opening $EDITOR merge editor. Resolve conflicts..."
    if [ "$DRY_RUN" -eq 1 ]; then
        log "Dry run: skipping actual merge."
    else
        "$EDITOR" --wait --merge "$OURS" "$THEIRS" "$BASE" "$dest"
    fi

    $prefix rm -f "$BASE" "$THEIRS" "$OURS"
}

force_copy() {
    local src="$1"
    local dest="$2"
    local use_sudo="$3"
    local prefix=""
    [ "$use_sudo" = "1" ] && prefix="sudo "

    if [ "$DRY_RUN" -eq 1 ]; then
        log "Dry run: would copy $src -> $dest (sudo=$use_sudo)"
        return
    fi

    $prefix mkdir -p "$(dirname "$dest")"
    if [ -f "$src" ]; then
        local perms
        perms=$(stat -c "%a" "$src")
        $prefix install -m "$perms" "$src" "$dest"
        $prefix chown "$(id -un):$(id -gn)" "$dest"
    fi
    log "Copied $src -> $dest"
}

copy_attempt() {
    local pair="$1"
    local src dest answer
    src="${pair%%:*}"
    dest="${pair#*:}"
    sanitize_path "$src"
    sanitize_path "$dest"

    if file_requires_sudo "$src"; then
        prompt="${CYAN}File $src requires sudo to read. Elevate to sudo? (y), skip (s), abort (n): ${RESET}"
        printf "%b" "$prompt"
        read -r answer </dev/tty
        case "$answer" in
            y|Y) copy_file "$src" "$dest" 1 ;;
            s|S) log "Skipped $src" ;;
            n|N) fail "Aborted by user." ;;
            *) warn "Invalid input, skipping $src" ;;
        esac
    else
        copy_file "$src" "$dest" 0
    fi
}

# --- Entry Expansion Utilities ---

expand_all_items() {
    local entry
    for entry in "${ITEM_LIST[@]}"; do
        expand_entry "$entry"
    done
}

expand_entry() {
    local entry="$1"
    local src dest rel_path
    src="${entry%%:*}"
    dest="$CONFIG_PATH/${entry#*:}"
    if [ -f "$src" ]; then
        echo "$src:$dest"
    elif [ -d "$src" ]; then
        find "$src" -type f | while read -r file; do
            rel_path="${file#"$src"/}"
            echo "$file:$dest/$rel_path"
        done
    fi
}

item_source_is_dir() {
    local entry="$1"
    local src="${entry%%:*}"
    [ -d "$src" ]
}

# --- Config Directory Management ---

clean_config_path() {
    [ -n "$CONFIG_PATH" ] && [ -d "$CONFIG_PATH" ] && {
        if [ "$DRY_RUN" -eq 1 ]; then
            log "Dry run: would remove $CONFIG_PATH"
        else
            sudo rm -rf "$CONFIG_PATH"
            log "Removed $CONFIG_PATH"
        fi
    }
}

init_config_path() {
    mkdir -p "$CONFIG_PATH"
    cd "$CONFIG_PATH" || return 1
    [ ! -d .git ] && git init
    cd - >/dev/null || return 1
}

commit_config_path() {
    local message="${1:-Update}"
    pushd "$CONFIG_PATH" >/dev/null || fail "Cannot access $CONFIG_PATH"
    git add .
    if ! git diff --cached --quiet; then
        if [ "$DRY_RUN" -eq 1 ]; then
            log "Dry run: would commit changes"
        else
            git commit -m "$message"
        fi
    else
        log "No changes to commit."
    fi
    popd >/dev/null || exit
}

# --- Workflow Functions ---
clean() { clean_config_path; }
copy_files() { expand_all_items | while read -r pair; do copy_attempt "$pair"; done; }
init_git_repo() { init_config_path; }
commit_all_changes() { commit_config_path; }
setup() { clean; copy_files; init_git_repo; commit_all_changes; }
update() { commit_all_changes; copy_files; commit_all_changes; }

# --- Environment Loader ---
load_env() {
    [ -f .env ] || fail "Error: .env file not found."
    # Only source if it contains expected variables (basic check)
    if grep -q "^CONFIG_PATH=" .env; then
        # shellcheck source=../.env
        . .env
    else
        fail "Invalid .env file."
    fi
    [ -n "$CONFIG_PATH" ] || fail "Error: CONFIG_PATH is not defined."
    [ -f "config.txt" ] || fail "Error: config.txt not found."
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        ITEM_LIST+=("$line")
    done <"config.txt"
}

# --- Script Initialization ---
load_env
# Expose main entry points: setup, update, clean
