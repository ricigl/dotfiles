#!/usr/bin/env bash
# Prepare Ubuntu WSL for Herdr's loopback-only SSH relay.
set -euo pipefail

VERIFY_ONLY=0
if [ "${1:-}" = "--verify-only" ]; then
  VERIFY_ONLY=1
elif [ "$#" -ne 0 ]; then
  printf 'Usage: %s [--verify-only]\n' "$0" >&2
  exit 64
fi

if ! grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
  printf '%s\n' "This script must run inside Ubuntu WSL." >&2
  exit 1
fi

WSL_USER="$(id -un)"
case "$WSL_USER" in
  ''|*[!A-Za-z0-9_.-]*)
    printf 'Unsafe WSL username: %s\n' "$WSL_USER" >&2
    exit 1
    ;;
esac

required_packages=(
  ca-certificates
  curl
  git
  openssh-client
  openssh-server
  iproute2
  build-essential
  python3
  xz-utils
  unzip
  jq
)

if [ "$VERIFY_ONLY" -eq 0 ]; then
  sudo env DEBIAN_FRONTEND=noninteractive apt-get update
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${required_packages[@]}"

  wsl_conf_tmp="$(mktemp)"
  sshd_conf_tmp="$(mktemp)"
  cleanup() {
    rm -f "$wsl_conf_tmp" "$sshd_conf_tmp"
  }
  trap cleanup EXIT HUP INT TERM

  if sudo test -f /etc/wsl.conf; then
    sudo cat /etc/wsl.conf | tee "$wsl_conf_tmp" >/dev/null
  fi

  # Preserve every existing section while setting [boot] systemd=true.
  python3 - "$wsl_conf_tmp" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
lines = path.read_text().splitlines() if path.exists() else []
section_start = None
section_end = len(lines)
for index, line in enumerate(lines):
    match = re.match(r"\s*\[([^]]+)\]\s*$", line)
    if not match:
        continue
    if section_start is not None:
        section_end = index
        break
    if match.group(1).strip().lower() == "boot":
        section_start = index

if section_start is None:
    if lines and lines[-1].strip():
        lines.append("")
    lines.extend(["[boot]", "systemd=true"])
else:
    replaced = False
    for index in range(section_start + 1, section_end):
        if re.match(r"\s*systemd\s*=", lines[index], re.IGNORECASE):
            lines[index] = "systemd=true"
            replaced = True
            break
    if not replaced:
        lines.insert(section_start + 1, "systemd=true")

path.write_text("\n".join(lines).rstrip() + "\n")
PY

  sudo install -o root -g root -m 0644 "$wsl_conf_tmp" /etc/wsl.conf

  cat >"$sshd_conf_tmp" <<EOF
# Managed by ricigl/dotfiles scripts/ubuntu-bootstrap.sh
Port 2222
AddressFamily inet
ListenAddress 127.0.0.1
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
AuthorizedKeysFile .ssh/authorized_keys
AllowUsers $WSL_USER
EOF

  sudo install -d -o root -g root -m 0755 /etc/ssh/sshd_config.d
  sudo install -o root -g root -m 0644 \
    "$sshd_conf_tmp" /etc/ssh/sshd_config.d/99-orca-wsl.conf
  sudo install -d -o root -g root -m 0755 /run/sshd
  sudo sshd -t

  if [ "$(ps -p 1 -o comm=)" = "systemd" ]; then
    sudo systemctl enable --now ssh
    sudo systemctl restart ssh
  else
    printf '%s\n' \
      "systemd=true was written to /etc/wsl.conf." \
      "Run 'wsl --shutdown' in Windows PowerShell, restart Ubuntu, then rerun:" \
      "  ./scripts/ubuntu-bootstrap.sh --verify-only"
    exit 2
  fi
fi

for command_name in git make g++ python3 sshd; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$command_name" >&2
    exit 1
  }
done

sudo sshd -t

effective="$(sudo sshd -T -C "user=$WSL_USER,host=localhost,addr=127.0.0.1")"
for expected in \
  'port 2222' \
  'listenaddress 127.0.0.1:2222' \
  'passwordauthentication no' \
  'kbdinteractiveauthentication no' \
  'pubkeyauthentication yes' \
  'permitrootlogin no'; do
  if ! grep -Fqx "$expected" <<<"$effective"; then
    printf 'Effective sshd setting missing: %s\n' "$expected" >&2
    exit 1
  fi
done

if [ "$(ps -p 1 -o comm=)" != "systemd" ]; then
  printf '%s\n' "systemd is not PID 1. Run 'wsl --shutdown' from Windows and restart Ubuntu." >&2
  exit 2
fi

sudo systemctl is-enabled ssh >/dev/null
sudo systemctl is-active ssh >/dev/null

if ! ss -ltn | grep -Eq '127\.0\.0\.1:2222([[:space:]]|$)'; then
  printf '%s\n' "sshd is not listening on 127.0.0.1:2222." >&2
  exit 1
fi

printf '%s\n' \
  "Ubuntu WSL Herdr SSH prerequisites verified." \
  "User: $WSL_USER" \
  "SSH: 127.0.0.1:2222, key-only" \
  "Relay tools: $(command -v make), $(command -v g++), $(command -v python3)"
