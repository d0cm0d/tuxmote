#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

if [[ $EUID -eq 0 ]]; then
    echo "Run install.sh as your normal user; it asks for sudo where needed." >&2
    exit 1
fi

echo "==> Packages (avahi, zenity, libxkbcommon, PipeWire tools, PyGObject)"
sudo apt-get install -y --no-install-recommends \
    python3 python3-gi avahi-daemon libxkbcommon0 zenity libnotify-bin wireplumber pulseaudio-utils

echo "==> /dev/uinput access for the logged-in user"
echo uinput | sudo tee /etc/modules-load.d/tuxmote-uinput.conf >/dev/null
sudo install -m 0644 "$HERE/packaging/60-tuxmote-uinput.rules" /etc/udev/rules.d/60-tuxmote-uinput.rules
sudo modprobe uinput
sudo udevadm control --reload-rules
sudo udevadm trigger --action=add --sysname-match=uinput

echo "==> Bonjour announcement (_rowmote._tcp on port 5842)"
sudo install -m 0644 "$HERE/packaging/tuxmote.avahi.service" /etc/avahi/services/tuxmote.service
sudo systemctl enable --now avahi-daemon >/dev/null 2>&1 || true
sudo systemctl reload avahi-daemon 2>/dev/null || sudo systemctl restart avahi-daemon

if command -v ufw >/dev/null && sudo ufw status | grep -q '^Status: active'; then
    echo "==> Opening port 5842 (TCP+UDP) in ufw"
    sudo ufw allow 5842 comment 'tuxmote' >/dev/null
fi

RELOGIN=""
VIRT="$(systemd-detect-virt --vm 2>/dev/null || true)"
if [[ -n "$VIRT" && "$VIRT" != "none" ]]; then
    # Hypervisors with mouse integration draw the host cursor, so a guest-driven pointer looks frozen.
    echo "==> Virtual machine ($VIRT): letting GNOME draw the mouse pointer itself"
    ENV_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/environment.d"
    mkdir -p "$ENV_DIR"
    echo "MUTTER_DEBUG_DISABLE_HW_CURSORS=1" > "$ENV_DIR/90-tuxmote-software-cursor.conf"
    if [[ "$(systemctl --user show-environment)" != *MUTTER_DEBUG_DISABLE_HW_CURSORS=1* ]]; then
        systemctl --user set-environment MUTTER_DEBUG_DISABLE_HW_CURSORS=1
        RELOGIN="yes"
    fi
fi

echo "==> tuxmote and its user service"
install -Dm 0755 "$HERE/tuxmote" "$BIN_DIR/tuxmote"
install -Dm 0644 "$HERE/packaging/tuxmote.service" "$UNIT_DIR/tuxmote.service"
systemctl --user daemon-reload
systemctl --user enable tuxmote.service >/dev/null
systemctl --user restart tuxmote.service

sleep 1
if [[ ! -w /dev/uinput ]]; then
    echo
    echo "NOTE: /dev/uinput is not writable for $USER yet. Log out and back in (or reboot) once," >&2
    echo "      then tuxmote can inject input: systemctl --user restart tuxmote" >&2
elif [[ -n "$RELOGIN" ]]; then
    echo
    echo "NOTE: Log out and back in once so the mouse pointer is drawn by GNOME inside this VM." >&2
fi
echo
echo "Done. Status: systemctl --user status tuxmote   Logs: journalctl --user -fu tuxmote"
