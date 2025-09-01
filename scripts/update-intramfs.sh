#!/usr/bin/bash
set -e

echo "[*] Updating Initramfs..."
sudo update-initramfs -u
echo "[+] Done. Initramfs updated."
