#!/usr/bin/env python3
"""Manage the BIMI SVG avatar served at https://mail.marcelwalder.eu/avatar.svg."""

import base64
import os
import subprocess
import sys
import tempfile

WEB_DIR = "/var/www/mail"
AVATAR_PATH = os.path.join(WEB_DIR, "avatar.svg")


def print_help():
    print("Usage: mail-avatar [status | 1 | 2 | 3 | <path-to-image>]")
    print("  status            Show current avatar status and BIMI DNS test")
    print("  1                 Activate Concept 1: Modern Tech Ribbon (MW)")
    print("  2                 Activate Concept 2: Swiss Executive Monogram (MW)")
    print("  3                 Activate Concept 3: Sovereign Shield (Sentinel)")
    print("  <path-to-image>   Convert and activate custom JPG/PNG image as avatar")


def _detect_image_mime(raw: bytes) -> str:
    """Validate image magic bytes and return MIME type for PNG or JPEG."""
    if raw.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if raw.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    raise ValueError("Unsupported image format: expected a valid PNG or JPEG file.")


def _atomic_write_avatar(content: bytes) -> None:
    """Write avatar.svg via a temporary file in WEB_DIR and replace atomically."""
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb",
            dir=WEB_DIR,
            prefix=".avatar.",
            suffix=".svg.tmp",
            delete=False,
        ) as tmp_file:
            tmp_path = tmp_file.name
            tmp_file.write(content)
            tmp_file.flush()
            os.fsync(tmp_file.fileno())
        os.chmod(tmp_path, 0o644)
        os.replace(tmp_path, AVATAR_PATH)
    except BaseException:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise


def show_status():
    print("=== Active Avatar Status ===")
    if os.path.exists(AVATAR_PATH):
        size = os.path.getsize(AVATAR_PATH)
        print(f"File: {AVATAR_PATH} ({size} bytes)")
    else:
        print("No avatar.svg found in " + WEB_DIR)

    print("\nTesting HTTP endpoint:")
    res = subprocess.run(
        ["curl", "-sI", "https://mail.marcelwalder.eu/avatar.svg"],
        capture_output=True,
        text=True,
    )
    for line in res.stdout.splitlines():
        if any(h in line.lower() for h in ["http/", "content-type", "cache-control", "access-control", "content-security-policy"]):
            print("  " + line)

    print("\nTesting BIMI DNS record:")
    res_dns = subprocess.run(
        ["dig", "+short", "TXT", "default._bimi.marcelwalder.eu"],
        capture_output=True,
        text=True,
    )
    if res_dns.stdout.strip():
        print("  " + res_dns.stdout.strip())
    else:
        print("  (dig returned empty)")


def set_concept(num):
    src = os.path.join(WEB_DIR, f"concept{num}.svg")
    if not os.path.exists(src):
        print(f"Error: {src} does not exist.")
        sys.exit(1)
    with open(src, "rb") as f:
        _atomic_write_avatar(f.read())
    print(f"Successfully activated Concept {num} as active avatar.svg!")
    print("URL: https://mail.marcelwalder.eu/avatar.svg")


def convert_custom_image(image_path):
    if not os.path.exists(image_path):
        print(f"Error: File {image_path} not found.")
        sys.exit(1)

    with open(image_path, "rb") as f:
        raw = f.read()

    try:
        mime = _detect_image_mime(raw)
    except ValueError as exc:
        print(f"Error: {exc}")
        sys.exit(1)

    b64 = base64.b64encode(raw).decode("ascii")
    svg = f"""<?xml version="1.0" encoding="utf-8"?>
<svg version="1.2" baseProfile="tiny-ps" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 512 512" width="512" height="512">
  <title>Marcel Walder</title>
  <defs>
    <clipPath id="avatarCircle">
      <circle cx="256" cy="256" r="246"/>
    </clipPath>
  </defs>
  <circle cx="256" cy="256" r="250" fill="#0F172A" stroke="#38BDF8" stroke-width="6"/>
  <image href="data:{mime};base64,{b64}" x="0" y="0" width="512" height="512" preserveAspectRatio="xMidYMid slice" clip-path="url(#avatarCircle)"/>
</svg>"""

    _atomic_write_avatar(svg.encode("utf-8"))
    print("Custom image converted and set as active avatar.svg!")
    print("URL: https://mail.marcelwalder.eu/avatar.svg")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print_help()
        sys.exit(0)

    arg = sys.argv[1].lower()
    if arg in ["status", "check", "info"]:
        show_status()
    elif arg in ["1", "2", "3"]:
        set_concept(arg)
    elif os.path.exists(sys.argv[1]):
        convert_custom_image(sys.argv[1])
    else:
        print_help()
