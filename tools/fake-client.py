#!/usr/bin/env python3
"""Speaks the client side of the protocol, to check a running tuxmote without an iPhone.

    fake-client.py HOST [--pin 1234]          pair (enter the PIN in the dialog or via `tuxmote pin`)
    fake-client.py HOST --key <key> --demo    move the mouse, scroll and type a few characters
"""

import argparse
import hashlib
import socket
import time

DEVICE_HASH = 'fakeiphone0123456789'


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('host')
    parser.add_argument('--port', type=int, default=5842)
    parser.add_argument('--pin', default='1234')
    parser.add_argument('--key')
    parser.add_argument('--demo', action='store_true')
    args = parser.parse_args()

    sock = socket.create_connection((args.host, args.port), timeout=120)
    lines = sock.makefile('r', encoding='utf-8', newline='\r\n')

    def send(line: str) -> None:
        print('->', line)
        sock.sendall(line.encode() + b'\r\n')

    def expect(prefix: str) -> str:
        while True:
            line = lines.readline().rstrip('\r\n')
            print('<-', line)
            if line.startswith(prefix):
                return line

    send('VERSION v4')
    expect('VERSION')
    send('SERVERNAME')
    expect('SERVERNAME')

    key = args.key or hashlib.md5((DEVICE_HASH + args.pin + DEVICE_HASH).encode()).hexdigest()
    send(f'KEY {key}')
    if expect('KEY ') != 'KEY OK':
        send(f'KEYREQUEST {DEVICE_HASH} Fake client')
        print(f'   Enter PIN {args.pin} on the Linux machine ...')
        expect('KEY READY')
        send(f'KEY {key}')
        expect('KEY OK')
    print('   key:', key)

    send('PING-APP')
    expect('PONG')
    send('GET_SETTINGS')
    expect('3_FINGER_DRAG')
    send('GETVOL')
    send('MACADDRESS')
    expect('MACADDRESS')

    if args.demo:
        for _ in range(20):
            send('{8, 4}')
            time.sleep(0.02)
        udp = socket.socket(socket.AF_INET6 if ':' in sock.getpeername()[0] else socket.AF_INET, socket.SOCK_DGRAM)
        udp.sendto(b'UDP_TEST', (args.host, args.port))
        expect('UDP_OKAY')
        for _ in range(20):
            udp.sendto(b'{-8, -4}', (args.host, args.port))
            time.sleep(0.02)
        for _ in range(5):
            send('s2 {0, 6};2;{0, 0}')
        send('s2-e 2;{0, 0}')
        send('k Hallo Welt äöü ß € @ ^ ~ 😀')
        send('kf 13')
        send('km cmd')
        send('k a')
        send('km !cmd')
        send('kf 63234')
        send('km shift')
        send('k b')
        send('kf 63235')
        send('km !shift')
        send('LEFT TAPPED')
        send('PP TAPPED')
        send('kf 63243')
        send('sf 4 4')
        send('CLICK')
        send('RTCLICK')
        send('BEGINDRAG')
        send('{3, 3}')
        send('ENDDRAG')
        send('PING')
        expect('PONG')
    sock.close()


if __name__ == '__main__':
    main()
