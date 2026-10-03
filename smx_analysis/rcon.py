"""Simple Source RCON client for srcds debugging.

Connection details come from the environment, never from this file:
    RCON_HOST      (default 127.0.0.1)
    RCON_PORT      (default 27015)
    RCON_PASSWORD  (required)
"""
import os
import socket
import struct
import sys
import time


def _recv_pkt(s):
    hdr = s.recv(4)
    if len(hdr) < 4:
        return None
    size = struct.unpack("<i", hdr)[0]
    data = b""
    while len(data) < size:
        chunk = s.recv(size - len(data))
        if not chunk:
            break
        data += chunk
    if len(data) < 8:
        return None
    pid, ptype = struct.unpack("<ii", data[:8])
    body = data[8:]
    if body.endswith(b"\x00\x00"):
        body = body[:-2]
    return pid, ptype, body


def rcon(host, port, password, command, timeout=25.0):
    s = socket.create_connection((host, port), timeout=timeout)
    s.settimeout(timeout)

    def send(t, i, body):
        payload = body.encode("utf-8") + b"\x00\x00"
        pkt = struct.pack("<ii", i, t) + payload
        s.sendall(struct.pack("<i", len(pkt)) + pkt)

    send(3, 1, password)
    auth_ok = False
    auth_deadline = time.time() + timeout
    while time.time() < auth_deadline:
        s.settimeout(max(0.2, auth_deadline - time.time()))
        try:
            p = _recv_pkt(s)
        except socket.timeout:
            continue
        if p is None:
            break
        pid, ptype, body = p
        if pid == -1:
            raise RuntimeError("RCON auth failed: %r" % body)
        if pid == 1 and ptype == 2:
            auth_ok = True
        if pid == 1 and ptype == 0 and auth_ok:
            break  # trailing empty auth value
    if not auth_ok:
        raise RuntimeError("RCON auth timeout")

    send(2, 2, command)
    out = b""
    deadline = time.time() + timeout
    while time.time() < deadline:
        s.settimeout(max(0.2, deadline - time.time()))
        try:
            p = _recv_pkt(s)
        except socket.timeout:
            if out:
                break
            continue
        if p is None:
            break
        pid, ptype, body = p
        if pid == 2 and ptype == 0:
            if not body:
                break
            out += body + b"\n"
        elif pid != 2:
            continue
    s.close()
    return out.decode("utf-8", "replace")


if __name__ == "__main__":
    password = os.environ.get("RCON_PASSWORD")
    if not password:
        sys.exit("RCON_PASSWORD is not set (also honours RCON_HOST / RCON_PORT)")

    host = os.environ.get("RCON_HOST", "127.0.0.1")
    port = int(os.environ.get("RCON_PORT", "27015"))
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

    print(rcon(host, port, password, cmd))
