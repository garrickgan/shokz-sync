#!/bin/bash
# shokz-sync uninstaller
set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/shokz-sync"
SYSTEMD_DIR="$HOME/.config/systemd/user"
DATA_DIR="$HOME/.local/share/shokz-sync"
LIBRARY_DIR="$HOME/Music/ShokzLibrary"

echo "=== shokz-sync uninstaller ==="
echo ""

# --- Disable systemd units ---
echo "Disabling systemd services..."
systemctl --user disable --now shokz-sync-download.timer 2>/dev/null || true
systemctl --user stop shokz-sync.service 2>/dev/null || true
systemctl --user stop shokz-sync-download.service 2>/dev/null || true

for unit in shokz-sync.service shokz-sync-download.service shokz-sync-download.timer; do
    rm -f "$SYSTEMD_DIR/$unit"
done
systemctl --user daemon-reload
echo "Removed systemd units"

# --- Remove udev rule ---
if [ -f /etc/udev/rules.d/99-shokz-sync.rules ]; then
    echo ""
    echo "Removing udev rule (requires sudo)..."
    sudo rm -f /etc/udev/rules.d/99-shokz-sync.rules
    sudo udevadm control --reload-rules
    echo "Removed udev rule"
fi

# --- Remove scripts ---
rm -f "$INSTALL_DIR/shokz-sync"
rm -f "$INSTALL_DIR/shokz-trigger"
echo "Removed scripts from $INSTALL_DIR"

# --- Optional: remove config ---
echo ""
read -rp "Remove configuration ($CONFIG_DIR)? [y/N] " yn
if [[ "${yn:-N}" =~ ^[Yy] ]]; then
    rm -rf "$CONFIG_DIR"
    echo "Removed config"
else
    echo "Kept config at $CONFIG_DIR"
fi

# --- Optional: remove data/logs ---
if [ -d "$DATA_DIR" ]; then
    read -rp "Remove logs ($DATA_DIR)? [y/N] " yn
    if [[ "${yn:-N}" =~ ^[Yy] ]]; then
        rm -rf "$DATA_DIR"
        echo "Removed logs"
    else
        echo "Kept logs at $DATA_DIR"
    fi
fi

# --- Optional: remove music library ---
if [ -d "$LIBRARY_DIR" ]; then
    read -rp "Remove music library ($LIBRARY_DIR)? [y/N] " yn
    if [[ "${yn:-N}" =~ ^[Yy] ]]; then
        rm -rf "$LIBRARY_DIR"
        echo "Removed music library"
    else
        echo "Kept music library at $LIBRARY_DIR"
    fi
fi

echo ""
echo "=== Uninstall complete ==="
