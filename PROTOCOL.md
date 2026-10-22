# Wire protocol

What tuxmote and the Rowmote Pro app exchange on the network, as far as tuxmote needs it.

## Transport

- **Discovery:** Bonjour service `_rowmote._tcp` in `local.`, instance name = computer name, no TXT records.
- **TCP port 5842.** Line based, UTF-8, every message ends with `\r\n`. The server sends nothing until the
  client speaks.
- **UDP on the same port:** `UDP_TEST` (answered with `UDP_OKAY` over the TCP connections) and pointer
  movements `{dx, dy}`.

A line is either a remote-control command (see below, authenticated clients only) or a command whose first
word is the verb and the rest its argument. Some commands contain spaces (`QUIT APPLICATION`, `CHECK FOR
UPDATES` …) and are matched as a whole line.

## Handshake and pairing

| Client | Server | |
|---|---|---|
| `VERSION v…` | `VERSION 4.2.5 OSX.<major>.<minor>.<patch>` | clients without the `v` prefix get `3.6.11` |
| `SERVERNAME` | `SERVERNAME <computer name>` | |
| `KEY <key>` | `KEY OK` / `KEY INVALID` | |
| `KEYREQUEST <hash> <device name>` | | server asks the user for the PIN shown on the device |
| | `KEY READY` | after the PIN was entered |

The key is `md5_hex(hash + PIN + hash)` in lower case. After `KEY READY` the client sends `KEY <key>`.
Commands that need pairing are answered with `KEY UNAUTHORIZED` until then.

Allowed without pairing: `PING`, `PING-APP`, `VERSION`, `SERVERNAME`, `START REMOTE CONTROL`, `CALL CONNECTED`,
`PAUSEONCALL`, `GET_SETTINGS`, `MACADDRESS`, `MACADDRESSES`, `GETAPPS`, `GETAPPS_NAMES`, `GETICON`,
`CHECK FOR UPDATES`, `KEY`, `KEYREQUEST`.

## General commands

| Command | Reply / effect |
|---|---|
| `PING` / `PING-APP` | `PONG`, or `PONG <app name>$RR$<app id>` (tuxmote always sends `PONG`) |
| `GET_SETTINGS` | `3_FINGER_DRAG 0/1` |
| `MACADDRESS` / `MACADDRESSES` | `MACADDRESS aa:bb:…` / `MACADDRESSES a;b;…` |
| `GETAPPS` | `DOCKAPPS id,id,…`, `RUNNINGAPPS …`, `CONTROLLEDAPPS …` |
| `GETAPPS_NAMES` | `DOCKAPPS_NAMES id Name,…`, `RUNNINGAPPS_NAMES …`, `CONTROLLEDAPPS …` |
| `GETICON <id> [<px>]` | `ICON <id> <bytes>\r\n` followed by a PNG (default 80 px) |
| `SWITCHID <id>` | launch or activate an app |
| `GETVOL` / `SETVOL <0..1>` | `VOL 0.40` |
| `VOL UP` / `VOL DOWN` | one volume step |
| `GETMUTE` / `SETMUTE 0/1` | `MUTED 0/1` |
| `BRIGHT UP/DOWN`, `MIRROR_DISPLAY_TOGGLE`, `GETNUMDISPLAYS` → `NUMDISPLAYS n` | |
| `SHUTDOWN`, `RESTART`, `COMPUTER_SLEEP`, `DISPLAY_SLEEP`, `EJECT DISC` | |
| `QUIT APPLICATION`, `HIDE APPLICATION`, `CLOSE WINDOW`, `TOGGLE FULLSCREEN` | |
| `GETAIRPLAY` / `SETAIRPLAY <uid>` | `AIRPLAY name,uid,type,picked$RR$…` (type 0 screen, 1 audio, 2 built-in; `,` in names becomes `*RC*`) |
| `SCROLL_DIR n` | 0 system default, 1 traditional, 2 natural |
| `CALL CONNECTED`, `PAUSEONCALL 0/1` | pause playback when a call comes in |
| `VOLCONTROL n`, `WILLRESIGN` | accepted, no effect |
| `<BUTTON> <ACTION>` | remote buttons `UP DOWN LEFT RIGHT SELECT MENU ENTER PP` with `PRESSED RELEASED TAPPED HELD REPEATED` |

Spaces in ids are sent as `^RS^`, commas in names as `$RR$`. The server reports volume changes unasked with
`VOL …` and `MUTED …`.

## Remote-control commands (paired clients only)

| Command | Effect |
|---|---|
| `{dx, dy}` | move the pointer relatively (pixels), also over UDP |
| `CLICK` / `RTCLICK` | left / right click at the current position |
| `BEGINDRAG` / `ENDDRAG` | press the button on the next move / release it |
| `s {dx, dy}` | scroll |
| `s2 {dx, dy};<phase>;{vx, vy}` | phase 2: two-finger scroll, phase 3: three-finger drag |
| `s2-e <phase>;{vx, vy}` | end of the gesture |
| `p <delta>` | pinch, about ±0.1 per message |
| `rot <angle>`, `TAP <fingers> <taps>` | rotation, multi-finger tap |
| `sf <fingers> <direction>` | swipe; direction 1 left, 2 right, 4 up, 8 down |
| `k <text>` | type text; backspace arrives as the control character `\b` |
| `kf <code>` | key as a decimal NSEvent character code: `0xF700`–`0xF703` arrows, `0xF704`+ F-keys, 13 return, 127 delete … |
| `km <mod>` / `km !<mod>` | hold / release `cmd`, `opt`, `ctrl`, `shift` |
| `STOP REMOTE CONTROL` | release held keys and drag |

Scroll deltas are shaped like on the Mac: the weaker axis is dropped when it is below 40 % of the stronger one,
x is limited to ±1…±5 px and y to ±10 px per message, and the sign follows the scroll direction.
