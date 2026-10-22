#!/usr/bin/env bash
set -uo pipefail

UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

systemctl --user disable --now tuxmote.service 2>/dev/null
rm -f "$UNIT_DIR/tuxmote.service" "$HOME/.local/bin/tuxmote" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/environment.d/90-tuxmote-software-cursor.conf"
systemctl --user unset-environment MUTTER_DEBUG_DISABLE_HW_CURSORS 2>/dev/null
systemctl --user daemon-reload

sudo rm -f /etc/avahi/services/tuxmote.service /etc/udev/rules.d/60-tuxmote-uinput.rules \
    /etc/modules-load.d/tuxmote-uinput.conf
sudo systemctl reload avahi-daemon 2>/dev/null
sudo udevadm control --reload-rules

echo "Removed. Pairings and settings stay in ~/.config/tuxmote (delete it to forget them)."
