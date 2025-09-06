#!/usr/bin/env bash
# assert.sh - Flexible assertion helpers
# Depends on os.sh for OS/arch detection

if ! declare -F os::id >/dev/null; then
    echo "❌ assert.sh requires os.sh to be sourced first" >&2
    return 1
fi

# Core logging
_assert::log() {
    local level="$1"; shift
    local msg="$*"
    case "$level" in
        FATAL) echo "💀 [FATAL] $msg" >&2 ;;
        ERROR) echo "❌ [ERROR] $msg" >&2 ;;
        WARN)  echo "⚠️ [WARN]  $msg" >&2 ;;
        INFO)  echo "ℹ️ [INFO]  $msg" >&2 ;;
    esac
}

# Levels
assert::fatal() { _assert::log FATAL "$*"; exit 1; }
assert::error() { _assert::log ERROR "$*"; return 1; }
assert::warn()  { _assert::log WARN  "$*"; return 0; }
assert::info()  { _assert::log INFO  "$*"; return 0; }

# Require a specific OS ID
assert::os_id() {
    local expected="$1"
    local actual
    actual="$(os::id)"
    if [[ "$actual" != "$expected" ]]; then
        assert::error "OS must be '$expected', got '$actual'"
    fi
}

# Require OS family
assert::os_family() {
    local expected="$1"
    local actual
    actual="$(os::family)"
    if [[ "$actual" != "$expected" ]]; then
        assert::fatal "OS family must be '$expected', got '$actual'"
    fi
}

# Require minimum version
assert::os_version_min() {
    local min="$1"
    local current
    current="$(os::version)"
    if [[ "$current" < "$min" ]]; then
        assert::error "OS version must be >= $min, got $current"
    fi
}

# Require architecture
assert::arch() {
    local expected="$1"
    local actual
    actual="$(os::arch)"
    if [[ "$actual" != "$expected" ]]; then
        assert::warn "Arch is '$actual', expected '$expected'"
    fi
}