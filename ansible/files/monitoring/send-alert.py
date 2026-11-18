#!/usr/bin/env python3
"""Send operational alert emails directly via OCI Email Delivery SMTP (with local sendmail fallback)."""

from email.message import EmailMessage
from email.utils import formatdate, make_msgid
import os
import re
import smtplib
import ssl
import subprocess
import sys

SASL_FILE = "/opt/mailserver/config/postfix-sasl-password.cf"
DEFAULT_SENDER = "Mail-Server Alert <info@marcelwalder.eu>"
DEFAULT_RECIPIENT = os.environ.get("ALERT_RECIPIENT", "marcelwalder12@gmail.com")


def _parse_sasl_credentials():
    """Return (host, port, username, password) from Postfix SASL password file, or None."""
    if not os.path.exists(SASL_FILE):
        return None
    with open(SASL_FILE, "r", encoding="utf-8") as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split(None, 1)
            if len(parts) != 2 or ":" not in parts[1]:
                continue
            target, creds = parts
            username, password = creds.split(":", 1)
            m = re.match(r"^\[?([^\]]+)\]?:(\d+)$", target)
            if m:
                host, port = m.group(1), int(m.group(2))
            else:
                host, port = target.strip("[]"), 587
            return host, port, username, password
    return None


def _build_email(subject: str, body: str, recipient: str) -> EmailMessage:
    """Build an RFC-compliant EmailMessage (rejects CR/LF header injection)."""
    msg = EmailMessage()
    msg["From"] = DEFAULT_SENDER
    msg["To"] = recipient
    msg["Subject"] = subject
    msg["Date"] = formatdate(localtime=True)
    msg["Message-ID"] = make_msgid(domain="marcelwalder.eu")
    msg.set_content(body)
    return msg


def send_direct_smtp(subject: str, body: str, recipient: str) -> bool:
    """Deliver alert mail directly via OCI Email Delivery STARTTLS relay."""
    parsed = _parse_sasl_credentials()
    if not parsed:
        return False
    host, port, username, password = parsed
    msg = _build_email(subject, body, recipient)

    context = ssl.create_default_context()
    with smtplib.SMTP(host, port, timeout=20) as server:
        server.ehlo()
        server.starttls(context=context)
        server.ehlo()
        server.login(username, password)
        server.send_message(msg)
    return True


def send_fallback_container(subject: str, body: str, recipient: str) -> bool:
    """Fall back to local mailserver sendmail if direct SMTP is unavailable."""
    msg = _build_email(subject, body, recipient)
    res = subprocess.run(
        ["docker", "exec", "-i", "mailserver", "sendmail", "-f", "info@marcelwalder.eu", "--", recipient],
        input=msg.as_string(),
        text=True,
        capture_output=True,
        timeout=20,
    )
    return res.returncode == 0


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: marcelwalder-send-alert <subject> [body] (or pass body on stdin)", file=sys.stderr)
        return 1

    subject = sys.argv[1]
    body = sys.argv[2] if len(sys.argv) >= 3 else sys.stdin.read()
    recipient = os.environ.get("ALERT_RECIPIENT", DEFAULT_RECIPIENT)

    try:
        if send_direct_smtp(subject, body, recipient):
            return 0
    except Exception as exc:
        print(f"WARN: Direct OCI SMTP failed ({exc}); trying container fallback...", file=sys.stderr)

    try:
        if send_fallback_container(subject, body, recipient):
            return 0
    except Exception as exc:
        print(f"ERROR: Fallback container sendmail failed: {exc}", file=sys.stderr)

    return 1


if __name__ == "__main__":
    sys.exit(main())
