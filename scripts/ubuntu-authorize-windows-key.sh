#!/usr/bin/env bash
# Authorize the Windows client SSH public key in Ubuntu WSL.
set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "${1:-}" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  printf 'Usage: %s <path-to-orca-wsl-manual.pub>\n' "$0" >&2
  printf 'Example: %s /mnt/c/Users/Ricardo/AppData/Local/Temp/orca-wsl-manual.pub\n' "$0" >&2
  exit 64
fi

if [ "$(id -u)" -eq 0 ]; then
  printf '%s\n' "This script must not be run as root. Run as the normal Ubuntu WSL user." >&2
  exit 1
fi

if ! grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
  printf '%s\n' "This script must run inside Ubuntu WSL." >&2
  exit 1
fi

for cmd in ssh-keygen getent; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$cmd" >&2
    exit 1
  fi
done

PUBKEY_PATH="$1"
if [ ! -f "$PUBKEY_PATH" ]; then
  printf 'Public key file not found: %s\n' "$PUBKEY_PATH" >&2
  exit 1
fi

KEY_LINES="$(tr -d '\r' < "$PUBKEY_PATH" | awk 'NF')"
if [ -z "$KEY_LINES" ]; then
  printf 'Public key file is empty: %s\n' "$PUBKEY_PATH" >&2
  exit 1
fi

LINE_COUNT="$(printf '%s\n' "$KEY_LINES" | awk 'NF { count += 1 } END { print count + 0 }')"
if [ "$LINE_COUNT" -ne 1 ]; then
  printf 'Public key file must contain exactly one key line, found %d lines in: %s\n' "$LINE_COUNT" "$PUBKEY_PATH" >&2
  exit 1
fi

KEY_LINE="$KEY_LINES"

if ! FINGERPRINT="$(printf '%s\n' "$KEY_LINE" | ssh-keygen -lf - 2>/dev/null)"; then
  printf 'Invalid SSH public key in: %s\n' "$PUBKEY_PATH" >&2
  exit 1
fi

WSL_USER="$(id -un)"
WSL_GROUP="$(id -gn)"
USER_HOME="$(getent passwd "$WSL_USER" | cut -d: -f6)"
if [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ]; then
  printf 'Could not resolve home directory for user: %s\n' "$WSL_USER" >&2
  exit 1
fi

SSH_DIR="$USER_HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

if [ ! -d "$SSH_DIR" ]; then
  mkdir -m 700 -p "$SSH_DIR" 2>/dev/null || {
    sudo mkdir -m 700 -p "$SSH_DIR"
    sudo chown "$WSL_USER:$WSL_GROUP" "$SSH_DIR"
  }
fi

if ! [ -O "$SSH_DIR" ]; then
  sudo chown "$WSL_USER:$WSL_GROUP" "$SSH_DIR"
fi
chmod 700 "$SSH_DIR" 2>/dev/null || sudo chmod 700 "$SSH_DIR"

if [ ! -f "$AUTH_KEYS" ]; then
  touch "$AUTH_KEYS" 2>/dev/null || {
    sudo touch "$AUTH_KEYS"
    sudo chown "$WSL_USER:$WSL_GROUP" "$AUTH_KEYS"
  }
fi

if ! [ -O "$AUTH_KEYS" ]; then
  sudo chown "$WSL_USER:$WSL_GROUP" "$AUTH_KEYS"
fi
chmod 600 "$AUTH_KEYS" 2>/dev/null || sudo chmod 600 "$AUTH_KEYS"

if grep -qxF "$KEY_LINE" "$AUTH_KEYS" 2>/dev/null; then
  printf 'Key is already authorized in %s\n' "$AUTH_KEYS"
  printf 'Fingerprint: %s\n' "$FINGERPRINT"
else
  if [ -s "$AUTH_KEYS" ] && [ -n "$(tail -c 1 "$AUTH_KEYS" 2>/dev/null)" ]; then
    printf '\n' >> "$AUTH_KEYS"
  fi
  printf '%s\n' "$KEY_LINE" >> "$AUTH_KEYS"
  printf 'Key successfully authorized in %s\n' "$AUTH_KEYS"
  printf 'Fingerprint: %s\n' "$FINGERPRINT"
fi

chmod 600 "$AUTH_KEYS" 2>/dev/null || sudo chmod 600 "$AUTH_KEYS"
chmod 700 "$SSH_DIR" 2>/dev/null || sudo chmod 700 "$SSH_DIR"
