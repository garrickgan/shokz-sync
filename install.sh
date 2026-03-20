#!/bin/bash
# shokz-sync installer
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/shokz-sync"
SYSTEMD_DIR="$HOME/.config/systemd/user"

echo "=== shokz-sync installer ==="
echo ""

# --- Check dependencies ---
missing=()
for cmd in yt-dlp ffmpeg python3 curl; do
    if ! command -v "$cmd" &>/dev/null; then
        missing+=("$cmd")
    fi
done

# notify-send is optional but recommended
has_notify=true
if ! command -v notify-send &>/dev/null; then
    has_notify=false
fi

if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing required dependencies: ${missing[*]}"
    echo ""

    # Detect package manager
    if command -v dnf &>/dev/null; then
        pkg_cmd="sudo dnf install"
        pkg_map_ffmpeg="ffmpeg-free"
        pkg_map_python3="python3"
        pkg_map_curl="curl"
    elif command -v apt &>/dev/null; then
        pkg_cmd="sudo apt install"
        pkg_map_ffmpeg="ffmpeg"
        pkg_map_python3="python3"
        pkg_map_curl="curl"
    elif command -v pacman &>/dev/null; then
        pkg_cmd="sudo pacman -S"
        pkg_map_ffmpeg="ffmpeg"
        pkg_map_python3="python"
        pkg_map_curl="curl"
    else
        pkg_cmd=""
    fi

    for dep in "${missing[@]}"; do
        if [ "$dep" = "yt-dlp" ]; then
            read -rp "Install yt-dlp via pip? [Y/n] " yn
            if [[ "${yn:-Y}" =~ ^[Yy] ]]; then
                pip install --user yt-dlp
            else
                echo "Please install yt-dlp manually: https://github.com/yt-dlp/yt-dlp"
                exit 1
            fi
        elif [ -n "$pkg_cmd" ]; then
            pkg_name="$dep"
            [ "$dep" = "ffmpeg" ] && pkg_name="$pkg_map_ffmpeg"
            [ "$dep" = "python3" ] && pkg_name="$pkg_map_python3"
            [ "$dep" = "curl" ] && pkg_name="$pkg_map_curl"
            read -rp "Install $dep via package manager ($pkg_cmd $pkg_name)? [Y/n] " yn
            if [[ "${yn:-Y}" =~ ^[Yy] ]]; then
                $pkg_cmd "$pkg_name"
            else
                echo "Please install $dep manually."
                exit 1
            fi
        else
            echo "Please install $dep manually."
            exit 1
        fi
    done
    echo ""
fi

if [ "$has_notify" = false ]; then
    echo "Note: notify-send not found. Desktop notifications will be skipped."
    echo "      Install libnotify for notifications."
    echo ""
fi

# --- Device detection ---
echo "--- Device Setup ---"

detected_label=""
# Try to find a connected Shokz device
for mount in /run/media/"$USER"/*/; do
    label=$(basename "$mount")
    if [[ "$label" == *SWIM* ]] || [[ "$label" == *SHOKZ* ]] || [[ "$label" == *swim* ]]; then
        detected_label="$label"
        break
    fi
done

if [ -n "$detected_label" ]; then
    echo "Detected device: $detected_label"
    read -rp "Use this device label? [Y/n] " yn
    if [[ "${yn:-Y}" =~ ^[Yy] ]]; then
        DEVICE_LABEL="$detected_label"
    else
        read -rp "Enter device label: " DEVICE_LABEL
    fi
else
    echo "No Shokz device detected."
    echo "Plug in your OpenSwim Pro and check: ls /run/media/$USER/"
    read -rp "Enter device label [SWIM PRO]: " DEVICE_LABEL
    DEVICE_LABEL="${DEVICE_LABEL:-SWIM PRO}"
fi

# Convert spaces to underscores for udev matching
UDEV_LABEL="${DEVICE_LABEL// /_}"
echo ""

# --- Browser for cookie extraction ---
echo "--- Browser Setup ---"
echo "yt-dlp extracts cookies from your browser for authenticated sources."
echo "Options: chrome, firefox, chromium, brave, edge, opera, vivaldi"
read -rp "Which browser? [chrome]: " BROWSER
BROWSER="${BROWSER:-chrome}"
echo ""

# --- Generate config ---
echo "--- Installing ---"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/config" << EOF
# shokz-sync configuration
DEVICE_LABEL="$DEVICE_LABEL"
BROWSER="$BROWSER"
MAX_DEVICE_TRACKS=20
MAX_DOWNLOADS_PER_SOURCE=10
RESERVE_MB=200
EOF
echo "Created config: $CONFIG_DIR/config"

# Create sources.conf if it doesn't exist
if [ ! -f "$CONFIG_DIR/sources.conf" ]; then
    cp "$SCRIPT_DIR/examples/sources.conf" "$CONFIG_DIR/sources.conf"
    echo "Created sources: $CONFIG_DIR/sources.conf"
else
    echo "Keeping existing sources: $CONFIG_DIR/sources.conf"
fi

# --- Install script ---
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/shokz-sync" "$INSTALL_DIR/shokz-sync"
chmod +x "$INSTALL_DIR/shokz-sync"
echo "Installed script: $INSTALL_DIR/shokz-sync"

# Check PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "WARNING: $INSTALL_DIR is not in your PATH."
    echo "Add this to your ~/.bashrc or ~/.zshrc:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

# --- Install systemd services ---
mkdir -p "$SYSTEMD_DIR"
for unit in shokz-sync.service shokz-sync-download.service shokz-sync-download.timer; do
    cp "$SCRIPT_DIR/systemd/$unit" "$SYSTEMD_DIR/$unit"
done
echo "Installed systemd units"

systemctl --user daemon-reload

# Enable the download timer
systemctl --user enable --now shokz-sync-download.timer
echo "Enabled download timer (every 6 hours)"

# --- Install udev rule + trigger ---
echo ""
echo "--- udev Rule ---"
echo "A udev rule auto-syncs when your Shokz device is plugged in."
echo "This requires sudo to install to /etc/udev/rules.d/."
read -rp "Install udev rule? [Y/n] " yn

if [[ "${yn:-Y}" =~ ^[Yy] ]]; then
    TRIGGER_SCRIPT="$INSTALL_DIR/shokz-trigger"

    # Generate trigger script with correct UID/username
    cat > "$TRIGGER_SCRIPT" << EOF
#!/bin/bash
# Triggered by udev when Shokz device is plugged in.
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" \\
XDG_RUNTIME_DIR="/run/user/$(id -u)" \\
runuser -u $USER -- systemctl --user start shokz-sync.service
EOF
    chmod +x "$TRIGGER_SCRIPT"
    echo "Installed trigger: $TRIGGER_SCRIPT"

    # Install udev rule
    UDEV_RULE="ACTION==\"add\", SUBSYSTEM==\"block\", ENV{ID_FS_LABEL}==\"$UDEV_LABEL\", RUN+=\"$TRIGGER_SCRIPT\""
    echo "$UDEV_RULE" | sudo tee /etc/udev/rules.d/99-shokz-sync.rules > /dev/null
    sudo udevadm control --reload-rules
    echo "Installed udev rule: /etc/udev/rules.d/99-shokz-sync.rules"
else
    echo "Skipped udev rule. You can sync manually with: shokz-sync auto"
fi

# --- Done ---
echo ""
echo "=== Installation complete ==="
echo ""
echo "Next steps:"
echo "  1. Add music sources:"
echo "     shokz-sync add soundcloud 'https://soundcloud.com/user/likes' 'My Likes'"
echo "     shokz-sync add podcast 'https://feed.url/rss' 'Podcast Name'"
echo "  2. Run a download:  shokz-sync download"
echo "  3. Plug in headphones to auto-sync, or run: shokz-sync sync"
echo "  4. Check status:    shokz-sync status"
echo ""

# Show status
"$INSTALL_DIR/shokz-sync" status
