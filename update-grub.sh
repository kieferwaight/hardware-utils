#!/usr/bin/bash
set -e

echo "[*] Updating grub..."
sudo update-grub
echo "[+] Done. GRUB updated."

echo "[*] Would you like to reboot now? (y/n)"
read -r REBOOT

if [[ $REBOOT == [yY] ]]; then
    echo "[*] Rebooting now..."
    sudo reboot
else
    echo "[+] Reboot canceled."
fi