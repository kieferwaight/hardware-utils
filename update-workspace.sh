#!/bin/bash
# filepath: /home/server/Projects/hardware-apple-mac-pro-6-1/update-workspace.sh

set -e

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

ITEMS=(
    "/etc/default/grub:etc/default/grub"
    "/etc/grub.d:etc/grub.d"
    "/etc/X11:etc/X11"
    "/etc/modprobe.d:etc/modprobe.d"
    "/etc/modules-load.d:etc/modules-load.d"
    "/boot/grub/grub.cfg:boot/grub/grub.cfg"
    "/etc/lsb-release:etc/lsb-release"
    "/etc/apt/sources.list:etc/apt/sources.list"
    "/etc/apt/sources.list.d:etc/apt/sources.list.d"
    "/etc/apt/trusted.gpg.d:etc/apt/trusted.gpg.d"
    "/etc/fstab:etc/fstab"
    "/etc/hostname:etc/hostname"
    "/etc/hosts:etc/hosts"
    "/etc/network/interfaces:etc/network/interfaces"
    "/etc/resolv.conf:etc/resolv.conf"
    "/etc/environment:etc/environment"
    "/etc/passwd:etc/passwd"
    "/etc/group:etc/group"
    "/etc/ssh/sshd_config:etc/ssh/sshd_config"
    "/etc/sysctl.conf:etc/sysctl.conf"
    "/etc/sysctl.d:etc/sysctl.d"
    "/etc/profile:etc/profile"
    "/etc/profile.d:etc/profile.d"
    "/etc/bash.bashrc:etc/bash.bashrc"
    "/etc/inputrc:etc/inputrc"
    "/etc/security/limits.conf:etc/security/limits.conf"
    "/etc/pam.d:etc/pam.d"
    "/etc/crontab:etc/crontab"
    "/etc/cron.d:etc/cron.d"
    "/etc/cron.daily:etc/cron.daily"
    "/etc/cron.hourly:etc/cron.hourly"
    "/etc/cron.weekly:etc/cron.weekly"
    "/etc/cron.monthly:etc/cron.monthly"
    "/etc/logrotate.conf:etc/logrotate.conf"
    "/etc/logrotate.d:etc/logrotate.d"
)

for entry in "${ITEMS[@]}"; do
    IFS=":" read -r SRC REL_DEST <<< "$entry"
    DEST_PATH="$CONFIG_DIR/$REL_DEST"
    if [ ! -e "$SRC" ]; then
        echo "Notice: $SRC does not exist, skipping."
        continue
    fi
    if [ ! -e "$DEST_PATH" ]; then
        # If dest doesn't exist, just copy
        mkdir -p "$(dirname "$DEST_PATH")"
        if [ -r "$SRC" ]; then
            if [ -d "$SRC" ]; then
                cp -a "$SRC" "$DEST_PATH"
            else
                cp -a "$SRC" "$DEST_PATH"
            fi
        else
            if [ -d "$SRC" ]; then
                sudo cp -a "$SRC" "$DEST_PATH"
                sudo chown -R "$(id -u):$(id -g)" "$DEST_PATH"
            else
                sudo cp -a "$SRC" "$DEST_PATH"
                sudo chown "$(id -u):$(id -g)" "$DEST_PATH"
            fi
        fi
        echo "Copied $SRC -> $DEST_PATH"
        continue
    fi

    # If both exist and differ, prompt user
    if ! diff -qr "$SRC" "$DEST_PATH" >/dev/null 2>&1; then
        echo "Difference detected for $SRC and $DEST_PATH."
        echo "Choose action: [m]erge (default), [o]verwrite, [s]kip"
        read -p "Action [m/o/s]: " action
        action=${action:-m}
        case "$action" in
            o|O)
                if [ -r "$SRC" ]; then
                    rm -rf "$DEST_PATH"
                    if [ -d "$SRC" ]; then
                        cp -a "$SRC" "$DEST_PATH"
                    else
                        cp -a "$SRC" "$DEST_PATH"
                    fi
                else
                    rm -rf "$DEST_PATH"
                    if [ -d "$SRC" ]; then
                        sudo cp -a "$SRC" "$DEST_PATH"
                        sudo chown -R "$(id -u):$(id -g)" "$DEST_PATH"
                    else
                        sudo cp -a "$SRC" "$DEST_PATH"
                        sudo chown "$(id -u):$(id -g)" "$DEST_PATH"
                    fi
                fi
                echo "Overwritten $DEST_PATH with $SRC"
                ;;
            s|S)
                echo "Skipped $SRC"
                ;;
            *)
                # Merge: copy SRC to a .diff file in workspace, then open diff in same workspace
                DIFF_PATH="${DEST_PATH}.diff"
                mkdir -p "$(dirname "$DIFF_PATH")"
                if [ -r "$SRC" ]; then
                    if [ -d "$SRC" ]; then
                        cp -a "$SRC" "$DIFF_PATH"
                    else
                        cp -a "$SRC" "$DIFF_PATH"
                    fi
                else
                    if [ -d "$SRC" ]; then
                        sudo cp -a "$SRC" "$DIFF_PATH"
                        sudo chown -R "$(id -u):$(id -g)" "$DIFF_PATH"
                    else
                        sudo cp -a "$SRC" "$DIFF_PATH"
                        sudo chown "$(id -u):$(id -g)" "$DIFF_PATH"
                    fi
                fi
                echo "Launching VS Code diff for $DEST_PATH and $DIFF_PATH"
                code --diff "$DEST_PATH" "$DIFF_PATH"
                echo "Please manually merge changes in $DEST_PATH, then save and close VS Code."
                read -p "Press Enter to continue to the next item..."
                rm -rf "$DIFF_PATH"
                ;;
        esac
    fi
done

echo "All items processed."