#!/usr/bin/bash
set -e

# Figure out where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATE="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$SCRIPT_DIR/backup/$DATE"

mkdir -p "$BACKUP_DIR"

echo "[*] Backing up package list..."
dpkg --get-selections >"$BACKUP_DIR/dpkg-selections.txt"
apt-mark showmanual >"$BACKUP_DIR/manual-packages.txt"

echo "[*] Backing up apt sources..."
cp -r /etc/apt/sources.list* "$BACKUP_DIR/" || true
cp -r /etc/apt/trusted.gpg* "$BACKUP_DIR/" || true

echo "[*] Backing up kernel modules list..."
lsmod >"$BACKUP_DIR/lsmod.txt"

echo "[*] Backing up loaded firmware info..."
dmesg | grep -i firmware >"$BACKUP_DIR/firmware-loaded.txt" || true

echo "[*] Copying firmware directory (this may be large)..."
mkdir -p "$BACKUP_DIR/firmware"
cp -r /lib/firmware/amdgpu "$BACKUP_DIR/firmware/" 2>/dev/null || true
cp -r /lib/firmware/radeon "$BACKUP_DIR/firmware/" 2>/dev/null || true

echo "[*] Backing up GRUB config..."
cp /etc/default/grub "$BACKUP_DIR/grub.default.conf"
cp -r /etc/modprobe.d "$BACKUP_DIR/modprobe.d/"

echo "[*] Saving system info..."
uname -a >"$BACKUP_DIR/uname.txt"
lsb_release -a >"$BACKUP_DIR/lsb_release.txt" 2>/dev/null || true
sudo dmidecode -t system | sudo tee "$BACKUP_DIR/system-dmi.txt" >/dev/null

echo "[+] Backup complete!"
echo "Saved in: $BACKUP_DIR"
