#!/usr/bin/env bash
set -euo pipefail
systemctl reload nginx || true
docker restart mailserver
