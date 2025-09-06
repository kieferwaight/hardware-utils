#!/usr/bin/env bash
# LOW DEPENDENCY
# TODO: Move the light weight echo
# utils to console-light.sh
# ---------------------------
# Cross-platform pkg::* utils
# ---------------------------

pkg::_detect_pm() {
    if command -v brew >/dev/null 2>&1; then
        echo "brew"
    elif command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    else
        echo ""
    fi
}

PKG_MANAGER="$(pkg::_detect_pm)"

pkg::ensure_pm() {
    if [[ -z "$PKG_MANAGER" ]]; then
        echo "❌ No supported package manager found (brew, apt, dnf, yum, pacman)." >&2
        return 1
    fi
    return 0
}

pkg::install() {
    pkg::ensure_pm || return 1
    local pkgs=("$@")
    case "$PKG_MANAGER" in
        brew)   brew install "${pkgs[@]}" ;;
        apt)    sudo apt-get update -y && sudo apt-get install -y "${pkgs[@]}" ;;
        dnf)    sudo dnf install -y "${pkgs[@]}" ;;
        yum)    sudo yum install -y "${pkgs[@]}" ;;
        pacman) sudo pacman -S --noconfirm "${pkgs[@]}" ;;
    esac
}

pkg::install_if_missing() {
    pkg::ensure_pm || return 1
    local pkgs=("$@")
    local to_install=()

    for pkg in "${pkgs[@]}"; do
        if pkg::exists "$pkg"; then
            echo "✅ $pkg already installed"
        else
            echo "⬇️ Installing $pkg..."
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        pkg::install "${to_install[@]}"
    fi
}

pkg::install_if_missing_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "❌ File not found: $file" >&2
        return 1
    fi

    local pkgs=()
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        pkgs+=("$line")
    done < "$file"

    if [[ ${#pkgs[@]} -eq 0 ]]; then
        echo "ℹ️ No packages listed in $file"
        return 0
    fi

    pkg::install_if_missing "${pkgs[@]}"
}

pkg::install_from_lockfile() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "❌ Lockfile not found: $file" >&2
        return 1
    fi

    pkg::ensure_pm || return 1

    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        local pkg version
        # Split by = or space
        if [[ "$line" =~ ^([^=[:space:]]+)[=[:space:]](.+)$ ]]; then
            pkg="${BASH_REMATCH[1]}"
            version="${BASH_REMATCH[2]}"
        else
            pkg="$line"
            version=""
        fi

        if [[ -n "$version" ]]; then
            echo "⬇️ Installing $pkg (version $version)..."
        else
            echo "⬇️ Installing $pkg (latest available)..."
        fi

        case "$PKG_MANAGER" in
            brew)
                if [[ -n "$version" ]]; then
                    # brew pinning: try formula@version first, then fallback
                    if brew install "$pkg@$version" 2>/dev/null; then
                        :
                    else
                        echo "⚠️ $pkg@$version not found, falling back to latest"
                        brew install "$pkg"
                    fi
                else
                    brew install "$pkg"
                fi
                ;;
            apt)
                if [[ -n "$version" ]]; then
                    if sudo apt-get install -y "${pkg}=${version}" 2>/dev/null; then
                        :
                    else
                        echo "⚠️ ${pkg}=${version} not available, falling back"
                        sudo apt-get install -y "$pkg"
                    fi
                else
                    sudo apt-get install -y "$pkg"
                fi
                ;;
            dnf|yum)
                if [[ -n "$version" ]]; then
                    if sudo "$PKG_MANAGER" install -y "${pkg}-${version}" 2>/dev/null; then
                        :
                    else
                        echo "⚠️ ${pkg}-${version} not available, falling back"
                        sudo "$PKG_MANAGER" install -y "$pkg"
                    fi
                else
                    sudo "$PKG_MANAGER" install -y "$pkg"
                fi
                ;;
            pacman)
                # Pacman does not support version pinning natively
                echo "⚠️ pacman does not support version pinning, installing latest for $pkg"
                sudo pacman -S --noconfirm "$pkg"
                ;;
        esac
    done < "$file"
}

pkg::export_installed() {
    pkg::ensure_pm || return 1
    local file="$1"
    local flag="${2:-}"  # optional --with-versions

    case "$PKG_MANAGER" in
        brew)
            if [[ "$flag" == "--with-versions" ]]; then
                brew list --versions > "$file"
            else
                brew list --formula > "$file"
            fi
            ;;
        apt)
            if [[ "$flag" == "--with-versions" ]]; then
                dpkg-query -W -f='${binary:Package}=${Version}\n' > "$file"
            else
                dpkg-query -W -f='${binary:Package}\n' > "$file"
            fi
            ;;
        dnf|yum)
            if [[ "$flag" == "--with-versions" ]]; then
                rpm -qa --qf '%{NAME}=%{VERSION}-%{RELEASE}\n' > "$file"
            else
                rpm -qa --qf '%{NAME}\n' > "$file"
            fi
            ;;
        pacman)
            if [[ "$flag" == "--with-versions" ]]; then
                pacman -Q > "$file"
            else
                pacman -Qq > "$file"
            fi
            ;;
    esac
    echo "📦 Exported installed packages to $file"
}

pkg::search() {
    pkg::ensure_pm || return 1
    local term="$1"
    case "$PKG_MANAGER" in
        brew)   brew search "$term" ;;
        apt)    apt-cache search "$term" ;;
        dnf)    dnf search "$term" ;;
        yum)    yum search "$term" ;;
        pacman) pacman -Ss "$term" ;;
    esac
}

pkg::remove() {
    pkg::ensure_pm || return 1
    local pkgs=("$@")
    case "$PKG_MANAGER" in
        brew)   brew uninstall "${pkgs[@]}" ;;
        apt)    sudo apt-get remove -y "${pkgs[@]}" ;;
        dnf)    sudo dnf remove -y "${pkgs[@]}" ;;
        yum)    sudo yum remove -y "${pkgs[@]}" ;;
        pacman) sudo pacman -Rns --noconfirm "${pkgs[@]}" ;;
    esac
}

pkg::update() {
    pkg::ensure_pm || return 1
    case "$PKG_MANAGER" in
        brew)   brew update ;;
        apt)    sudo apt-get update -y ;;
        dnf)    sudo dnf check-update || true ;;
        yum)    sudo yum check-update || true ;;
        pacman) sudo pacman -Sy ;;
    esac
}

pkg::upgrade() {
    pkg::ensure_pm || return 1
    case "$PKG_MANAGER" in
        brew)   brew upgrade ;;
        apt)    sudo apt-get upgrade -y ;;
        dnf)    sudo dnf upgrade -y ;;
        yum)    sudo yum update -y ;;
        pacman) sudo pacman -Syu --noconfirm ;;
    esac
}

pkg::exists() {
    pkg::ensure_pm || return 1
    local pkg="$1"
    case "$PKG_MANAGER" in
        brew)   brew list --versions "$pkg" >/dev/null 2>&1 ;;
        apt)    dpkg -s "$pkg" >/dev/null 2>&1 ;;
        dnf)    rpm -q "$pkg" >/dev/null 2>&1 ;;
        yum)    rpm -q "$pkg" >/dev/null 2>&1 ;;
        pacman) pacman -Qi "$pkg" >/dev/null 2>&1 ;;
    esac
}

pkg::which() {
    local bin="$1"
    if command -v "$bin" >/dev/null 2>&1; then
        command -v "$bin"
        return 0
    fi

    pkg::ensure_pm || return 1
    case "$PKG_MANAGER" in
        brew)   brew list --verbose 2>/dev/null | grep -E "/$bin\$" || true ;;
        apt)    apt-file search -x "bin/$bin" 2>/dev/null || true ;;
        dnf)    dnf provides "*/$bin" 2>/dev/null || true ;;
        yum)    yum provides "*/$bin" 2>/dev/null || true ;;
        pacman) pacman -F "$bin" 2>/dev/null || true ;;
    esac
}