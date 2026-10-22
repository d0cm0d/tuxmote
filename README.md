# tuxmote

Control a Linux desktop with the **Rowmote Pro** iOS app: trackpad, clicks, scrolling, pinch-to-zoom, keyboard,
media keys, volume, audio output and app launching.

The app normally talks to its macOS helper. tuxmote speaks the same network protocol (as of helper 4.2.5), so
the app finds a Linux machine on the network and pairs with it like with a Mac. It is a single Python script
without third-party dependencies and injects input through `/dev/uinput`, which works on Wayland and X11.

> **Unofficial.** tuxmote is an independent project and is not affiliated with or endorsed by the maker of
> Rowmote. It contains no code from the original helper. "Rowmote" is a trademark of its owner and is used here
> only to describe compatibility.

**Tested on** Ubuntu 26.10 and 26.04 LTS (GNOME on Wayland) with a real iPhone: discovery, PIN pairing,
reconnecting without PIN, pointer, clicks, drag, keyboard (German, US and French layouts), modifiers and
pinch-to-zoom.

## Install

On the Linux machine, as your normal user (the script asks for sudo where needed):

```bash
git clone https://github.com/d0cm0d/tuxmote.git
cd tuxmote
./install.sh
```

The script

- installs `avahi-daemon`, `zenity`, `libxkbcommon0`, `python3-gi`, `wireplumber`, `pulseaudio-utils` and
  `libnotify-bin`,
- grants the logged-in user access to `/dev/uinput` through a udev rule,
- announces the machine via Bonjour as `_rowmote._tcp` on port 5842,
- opens port 5842 (TCP and UDP) in `ufw` if the firewall is active,
- in a virtual machine, lets GNOME draw the mouse pointer itself (see [Limitations](#limitations)),
- installs `tuxmote` to `~/.local/bin` and starts it as a systemd user service with the graphical session.

If it asks you to, log out and back in once.

The installer targets Ubuntu and Debian (apt). On other distributions install the equivalent packages and copy
the files from `packaging/` by hand.

## Pair

1. Open Rowmote Pro on the iPhone. The Linux machine shows up under its hostname.
2. The iPhone displays a PIN and a dialog opens on the desktop. Enter the PIN there.
3. Without a desktop dialog (e.g. over SSH): `tuxmote pin 1234`

`tuxmote status` lists connected and paired devices, `tuxmote unpair` forgets all of them.

## What maps to what

| iPhone | Linux |
|---|---|
| Trackpad, click, right click | pointer motion, left and right button |
| Two-finger scroll | high-resolution wheel, vertical and horizontal |
| Drag mode / three-finger drag (if enabled) | held left button |
| Pinch | GNOME screen magnifier, 1x to 4x like on the Mac; switches off when the iPhone disconnects. Other desktops: Ctrl+wheel (zooms the focused app) |
| Three-finger swipe left/right | Alt+Right / Alt+Left (forward/back) |
| Four-finger swipe left/right | Super+Page Down / Super+Page Up (switch workspace) |
| Swipe up / down | Activities overview / app grid |
| Keyboard | text in the active keyboard layout (read from GNOME); characters the layout lacks are entered via Ctrl+Shift+U |
| ⌘ / ⌥ / ctrl / ⇧ | Ctrl / Alt / Ctrl / Shift (⌘ can be Super, see below) |
| F1/F2, F7–F9, F10–F12 | brightness, previous/play/next, mute, volume down/up |
| F3 / F4 | Activities overview / app grid |
| Remote ▲▼ / ◀▶ / centre / menu / ⏯ | volume up/down, arrow keys, space, Esc, play/pause |
| Volume, mute | PipeWire (`wpctl`); changes are reported back to the iPhone |
| AirPlay menu | choose the audio output device (PipeWire sinks) |
| Apps / dock | GNOME favourites, launched with `gtk-launch`, icons from the icon theme |
| Shut down, restart, sleep | `systemctl poweroff / reboot / suspend` |
| Display sleep | GNOME screensaver (locks depending on your settings) |
| Wake-on-LAN | the MAC address is reported; enable WoL in the firmware and with `ethtool` |

## Configuration

`~/.config/tuxmote/config.json`, only the keys you want to change; then `systemctl --user restart tuxmote`.

| Key | Default | Meaning |
|---|---|---|
| `cmd_key` | `"ctrl"` | ⌘ acts as Ctrl (`"ctrl"`) or Super (`"super"`) |
| `pointer_scale` | `1.0` | pointer speed factor |
| `scroll_scale` | `4.0` | scroll speed |
| `scroll_direction` | `0` | `0`/`2` natural (macOS default), `1` traditional; the app can also set this |
| `three_finger_drag` | `false` | three-finger drag instead of three-finger swipes |
| `fkeys_as_media` | `true` | F-keys act like the Mac's special keys; `false` sends plain F1–F12 |
| `pinch_zoom` | `"screen"` | `"screen"` magnifier, `"ctrl-scroll"` Ctrl+wheel (zoom inside the focused app), `"off"` |
| `allow_power_commands` | `true` | allow shut down / restart / sleep from the iPhone |
| `keyboard_layout` | `""` | force a layout, e.g. `"de"`, `"de+nodeadkeys"`, `"us"` |
| `port` | `5842` | change only together with `packaging/tuxmote.avahi.service` |

## Limitations

- Wayland does not let programs ask which window is focused. The app therefore gets no app name, and the
  app-specific remotes of the Mac helper (iTunes, Keynote, VLC, Plex …) are not available. Media keys go to the
  active player under GNOME.
- Rotation and smart zoom (two-finger double tap) are ignored.
- GNOME applies its own pointer acceleration; adjust `pointer_scale` if needed.
- tuxmote runs inside the graphical session, not on the login screen.
- Screen zoom needs GNOME. On KDE, Xfce and others pinch falls back to Ctrl+wheel inside the focused app.
- In virtual machines with mouse integration (seen with Parallels) the hypervisor draws the host cursor on top,
  so the pointer looks frozen while it actually moves. `install.sh` detects VMs and sets
  `MUTTER_DEBUG_DISABLE_HW_CURSORS=1` in `~/.config/environment.d/90-tuxmote-software-cursor.conf`, so GNOME
  draws the pointer itself after the next login. Real hardware does not need this.

## Security

tuxmote listens on port 5842 in your LAN. Nothing happens before PIN pairing; keys are stored in
`~/.config/tuxmote/keys.json`. Unlike the Mac helper, pointer movements over UDP are only accepted from
addresses that currently hold a paired connection. The protocol is not encrypted, so use it on trusted networks
only.

## Troubleshooting

```bash
journalctl --user -fu tuxmote                 # log
systemctl --user restart tuxmote
tuxmote -v                                    # foreground, logs every protocol line (stop the service first)
avahi-browse -rt _rowmote._tcp                # check the Bonjour announcement (package avahi-utils)
tools/fake-client.py <ip> --pin 1234          # simulated client: pair
tools/fake-client.py <ip> --key <key> --demo  # move the pointer, scroll and type
```

The wire protocol is described in [PROTOCOL.md](PROTOCOL.md).

## Uninstall

```bash
./uninstall.sh
```

## License

MIT, see [LICENSE](LICENSE).
