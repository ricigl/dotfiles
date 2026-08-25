#!/usr/bin/env bash
# Transitional installer for the pinned Prime Agent only.
# All other support tools are provided by Nix/Home Manager.
set -euo pipefail

PRIME_VERSION="0.8.0"
PRIME_INSTALLER_URL="https://app.primeintellect.ai/prime-agent/install.sh"
PRIME_INSTALLER_SHA256="38d14a1be73b325652c7ce8342e3bf19335721837192855a7907732caf8e6d04"

for command_name in curl sha256sum node npm python3; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$command_name" >&2
    exit 1
  }
done

if ! node -e 'const [major, minor, patch] = process.versions.node.split(".").map(Number); process.exit(major > 22 || (major === 22 && (minor > 19 || (minor === 19 && patch >= 0))) ? 0 : 1)'; then
  printf '%s\n' "Node.js 22.19.0 or newer is required; refusing to bootstrap Node with a system package installer." >&2
  exit 1
fi

# The Home Manager session variable covers fresh shells, but this installer may
# run from an existing shell whose npm prefix still points into the immutable
# Nix store. Keep Prime's npm installation user-owned and writable.
export NPM_CONFIG_PREFIX="$HOME/.local/share/npm"
export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
mkdir -p "$NPM_CONFIG_PREFIX/bin"

installer="$(mktemp)"
cleanup() {
  rm -f "$installer"
}
trap cleanup EXIT HUP INT TERM

curl -fsSLo "$installer" "$PRIME_INSTALLER_URL"
printf '%s  %s\n' "$PRIME_INSTALLER_SHA256" "$installer" | sha256sum -c -

# The reviewed installer downloads Prime's versioned tarball and verifies the
# release checksum before installing it.
sh "$installer" "$PRIME_VERSION"

prime-agent --version
