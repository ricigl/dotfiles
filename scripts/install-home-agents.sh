#!/usr/bin/env bash
# Install the reviewed AGY and Pi bootstrap scripts for the regular Home Manager shell.
# The bootstrap scripts verify their own release payloads, but their releases are
# intentionally dynamic. This wrapper pins the reviewed bootstrapper scripts.
set -euo pipefail

AGY_INSTALLER_URL="https://antigravity.google/cli/install.sh"
AGY_INSTALLER_SHA256="ee1ea43ce4e9e56356c4ab6dad907ef357ae4bdfcaadb682735909fb57c9c640"
PI_INSTALLER_URL="https://pi.dev/install.sh"
PI_INSTALLER_SHA256="a3a3604ee550bf72c5da7da3c3014cc361c14ab3b91b1b24f097d9022bd8de5b"

if [ -n "${IN_NIX_SHELL:-}" ]; then
  printf '%s\n' "Run this from the regular Home Manager shell, not nix develop .#orca-prime." >&2
  exit 1
fi

for command_name in curl sha256sum bash sh node npm mktemp; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$command_name" >&2
    exit 1
  }
done

if ! node -e 'const [major, minor, patch] = process.versions.node.split(".").map(Number); process.exit(major > 22 || (major === 22 && (minor > 19 || (minor === 19 && patch >= 0))) ? 0 : 1)'; then
  printf '%s\n' "Pi requires Node.js 22.19.0 or newer; refusing to bootstrap Node with a system package installer." >&2
  exit 1
fi

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/home-agents-install.XXXXXXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

download_verified() {
  url="$1"
  expected_sha256="$2"
  destination="$3"
  curl -fsSLo "$destination" "$url"
  printf '%s  %s\n' "$expected_sha256" "$destination" | sha256sum -c -
}

agy_installer="$tmp_dir/agy-install.sh"
pi_installer="$tmp_dir/pi-install.sh"
download_verified "$AGY_INSTALLER_URL" "$AGY_INSTALLER_SHA256" "$agy_installer"
download_verified "$PI_INSTALLER_URL" "$PI_INSTALLER_SHA256" "$pi_installer"

printf '%s\n' "Running the reviewed Antigravity CLI installer..."
bash "$agy_installer" --dir "$HOME/.local/bin"

printf '%s\n' "Running the reviewed Pi installer..."
sh "$pi_installer"

command -v agy >/dev/null 2>&1 || {
  printf '%s\n' "AGY was not found on PATH after installation." >&2
  exit 1
}
command -v pi >/dev/null 2>&1 || {
  printf '%s\n' "Pi was not found on PATH after installation." >&2
  exit 1
}

printf '%s\n' "AGY:"
agy --version
printf '%s\n' "Pi:"
pi --version
