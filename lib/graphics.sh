#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# graphics.sh - Linux Display/GPU Manager CLI
# ------------------------------------------------------------------------------
set -euo pipefail

. ./lib/console.sh
. ./lib/files.sh

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

command_exists() { command -v "$1" >/dev/null 2>&1; }

require_cmd() {
    local cmd="$1"
    if ! command_exists "$cmd"; then
        fail "Required command not found: $cmd"
    fi
}

xrandr_parse() {
    local pattern="${1:?pattern required}"
    require_cmd xrandr || return 1
    xrandr --query | grep "$pattern"
}

ensure_arg() {
    local val="$1" name="$2"
    if [[ -z "${val:-}" ]]; then
        fail "Missing argument: $name"
        return 1
    fi
}

# Get first connected display (internal)
_display_first_connected() {
    xrandr_parse " connected" | awk 'NR==1 {print $1}'
}

# Pretty print a header
_header() { printf "\n== %s ==\n" "$1"; }

# ------------------------------------------------------------------------------
# Low-level Mode Helpers (internal)
# ------------------------------------------------------------------------------

mode_generate() {
    local width="$1" height="$2" refresh="${3:-60}"
    require_cmd cvt || return 1
    cvt "$width" "$height" "$refresh" 2>/dev/null | grep Modeline || return 1
}

_mode_parse() {
    local cvt_out="$1"
    local -n _name_ref=$2
    local -n _line_ref=$3
    _name_ref=$(awk '{print $2}' <<<"$cvt_out" | tr -d '"')
    _line_ref=$(cut -d' ' -f3- <<<"$cvt_out")
}

_mode_ensure() {
    local display="$1" mode_name="$2" mode_line="$3"
    if ! xrandr | grep -q "^\\s*${mode_name}\\s"; then
        info "Adding new mode: $mode_name"
        xrandr --newmode "$mode_name" "$mode_line"
        xrandr --addmode "$display" "$mode_name"
    fi
}

mode_activate() {
    local display="$1" mode_name="$2"
    ensure_arg "$display" "display_name" || return 1
    ensure_arg "$mode_name" "mode_name" || return 1
    xrandr --output "$display" --mode "$mode_name"
}

mode_apply() {
    local display="$1" width="$2" height="$3" rate="$4"
    ensure_arg "$display" "display_name" || return 1
    ensure_arg "$width" "width" || return 1
    ensure_arg "$height" "height" || return 1
    ensure_arg "$rate" "refresh_rate" || return 1

    info "Generating modeline for ${width}x${height}@${rate}..."
    local cvt_out mode_name mode_line
    if ! cvt_out=$(mode_generate "$width" "$height" "$rate"); then
        fail "Failed to generate modeline"
        return 1
    fi
    _mode_parse "$cvt_out" mode_name mode_line
    _mode_ensure "$display" "$mode_name" "$mode_line"

    info "Activating mode: $mode_name"
    if mode_activate "$display" "$mode_name"; then
        success "✅ Success: ${width}x${height}@${rate}Hz on $display"
    else
        fail "❌ Failed applying mode"
        return 1
    fi
}

mode_current() {
    local display="$1"
    ensure_arg "$display" "display_name" || return 1
    xrandr --query | awk -v disp="$display" '
        $1==disp {in=1; next}
        in && $1 ~ /^[0-9]+x[0-9]+/ {print $1; exit}
    '
}

# ------------------------------------------------------------------------------
# GPU Commands
# ------------------------------------------------------------------------------

# @cmd List all detected GPUs
gpu_list() { lspci | grep -E "VGA|3D|Display"; }

# @cmd Get detailed GPU info
# @arg gpu_name  Filter by GPU name (optional)
gpu_details() {
    local gpu="${argc_gpu_name:-}"
    if [[ -n "$gpu" ]]; then
        sudo lshw -C display | grep -A 20 -i "$gpu"
    else
        sudo lshw -C display
    fi
}

# ------------------------------------------------------------------------------
# Display Commands
# ------------------------------------------------------------------------------

# @cmd List all connected displays
display_list() { xrandr_parse " connected" | awk '{print $1}'; }

# @cmd Show verbose display identifiers/resolution sections
display_verbose() {
    xrandr --verbose | grep -E "^\s*Identifier|^\s*Resolution|^\s*Refresh Rate"
}

# @cmd List all resolutions for a display (marks current)
# @arg display_name  Display name (default: first connected)
display_resolutions() {
    local display="${argc_display_name:-$(_display_first_connected)}"
    ensure_arg "$display" "display_name" || return 1
    xrandr | awk -v disp="$display" '
        $0 ~ "^"disp" " {in_disp=1; next}
        in_disp && $1 ~ /^[0-9]+x[0-9]+/ {
            cur=""
            for(i=2;i<=NF;i++) if ($i ~ /\*/) cur="*"
            printf "%-12s %s\n", $1, cur
        }
        in_disp && NF==0 {in_disp=0}
    '
}

# @cmd Get current active mode for a display
# @arg display_name  Display name (default: first connected)
display_current_mode() {
    local display="${argc_display_name:-$(_display_first_connected)}"
    ensure_arg "$display" "display_name" || return 1
    mode_current "$display"
}

# @cmd Apply (generate if needed) a resolution mode
# @arg display_name  Display name (default: first connected)
# @arg width!        Width in pixels
# @arg height!       Height in pixels
# @arg refresh       Refresh rate (default: 60)
display_apply_mode() {
    local display="${argc_display_name:-$(_display_first_connected)}"
    local width="${argc_width:-}"
    local height="${argc_height:-}"
    local refresh="${argc_refresh:-60}"
    mode_apply "$display" "$width" "$height" "$refresh"
}

# @cmd Activate an existing mode by its exact name
# @arg display_name  Display name (default: first connected)
# @arg mode_name!    Exact xrandr mode string (e.g. 1920x1080)
display_activate_mode() {
    local display="${argc_display_name:-$(_display_first_connected)}"
    local mode_name="${argc_mode_name:-}"
    ensure_arg "$display" "display_name" || return 1
    ensure_arg "$mode_name" "mode_name" || return 1
    if mode_activate "$display" "$mode_name"; then
        success "Activated $mode_name on $display"
    else
        fail "Failed to activate $mode_name on $display"
    fi
}

# @cmd Generate only (print) a modeline (does not apply)
# @arg width!   Width
# @arg height!  Height
# @arg refresh  Refresh (default: 60)
mode_generate_print() {
    local width="${argc_width:-}"
    local height="${argc_height:-}"
    local refresh="${argc_refresh:-60}"
    ensure_arg "$width" "width" || return 1
    ensure_arg "$height" "height" || return 1
    if out=$(mode_generate "$width" "$height" "$refresh"); then
        echo "$out"
    else
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Aggregate / Convenience
# ------------------------------------------------------------------------------

# @cmd Summary of displays & current modes
display_summary() {
    _header "Connected Displays"
    display_list
    while read -r d; do
        [[ -z "$d" ]] && continue
        cur=$(mode_current "$d" || true)
        echo " - $d (current: ${cur:-unknown})"
    done < <(display_list)
}


eval "$(argc --argc-eval "$0" "$@")"
