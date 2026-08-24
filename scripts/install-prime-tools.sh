#!/usr/bin/env bash
# Transitional installer for pinned Prime/Lavish/gh-axi versions.
# This is reviewed and version-pinned, but it is not a reproducible Nix build.
set -euo pipefail

PRIME_VERSION="0.8.0"
PRIME_INSTALLER_URL="https://app.primeintellect.ai/prime-agent/install.sh"
PRIME_INSTALLER_SHA256="38d14a1be73b325652c7ce8342e3bf19335721837192855a7907732caf8e6d04"
LAVISH_SPEC="lavish-axi@0.1.50"
LAVISH_INTEGRITY="sha512-w57Pdna5MmsgHTewyhOPkuzwbCe98WqR6yrvf/r+fxs1qor2ypHzeHD10H6V5n4qJMKosBClcK9M0QzmrbaoHA=="
GH_AXI_SPEC="gh-axi@0.1.30"
GH_AXI_INTEGRITY="sha512-4qw7+INJqdH5obm6NOUQnqBRALMG/BYQwTseVr9I7DHvccEytBtltc0EvB0SxrDzIUTKPshI9uKtfp83TjlBjA=="

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

export NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX:-$HOME/.local/share/npm}"
export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
mkdir -p "$NPM_CONFIG_PREFIX" "$HOME/.agents/skills"

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

verify_integrity() {
  package_spec="$1"
  expected="$2"
  actual="$(npm view "$package_spec" dist.integrity)"
  if [ "$actual" != "$expected" ]; then
    printf 'Integrity mismatch for %s\nExpected: %s\nActual:   %s\n' \
      "$package_spec" "$expected" "$actual" >&2
    exit 1
  fi
}

verify_integrity "$LAVISH_SPEC" "$LAVISH_INTEGRITY"
verify_integrity "$GH_AXI_SPEC" "$GH_AXI_INTEGRITY"

npm install -g --ignore-scripts --no-audit --no-fund \
  "$LAVISH_SPEC" \
  "$GH_AXI_SPEC"

npm_root="$(npm root -g)"
skills_root="$HOME/.agents/skills"
backup_suffix="pre-orca-prime-$(date +%Y%m%d-%H%M%S)"
backup_root="${XDG_STATE_HOME:-$HOME/.local/state}/orca-prime/skill-backups/$backup_suffix"

# Pi reads the shared user-global skills root directly. Home Manager exposes
# these same mutable skills through AGY and Prime client-specific roots.
shopt -s nullglob
stale_skill_backups=(
  "$skills_root"/*.pre-orca-prime-*
  "$skills_root"/*.pre-home-manager-*
)
if [ "${#stale_skill_backups[@]}" -gt 0 ]; then
  mkdir -p "$backup_root"
  for stale_backup in "${stale_skill_backups[@]}"; do
    mv "$stale_backup" "$backup_root/"
  done
fi
shopt -u nullglob

for skill_name in lavish gh-axi; do
  destination="$skills_root/$skill_name"
  if [ -e "$destination" ]; then
    mkdir -p "$backup_root"
    mv "$destination" "$backup_root/$skill_name"
  fi
done
cp -a "$npm_root/lavish-axi/skills/lavish" "$skills_root/"
cp -a "$npm_root/gh-axi/skills/gh-axi" "$skills_root/"

# Skills must call the reviewed installed binaries, never mutable npx -y.
python3 - <<'PY'
from pathlib import Path

for name, command in (("lavish", "lavish-axi"), ("gh-axi", "gh-axi")):
    path = Path.home() / ".agents" / "skills" / name / "SKILL.md"
    text = path.read_text()
    updated = text.replace(f"npx -y {command}", command)
    if updated == text and f"npx {command}" in text:
        updated = updated.replace(f"npx {command}", command)
    path.write_text(updated)
PY

prime-agent --version
lavish-axi --version
gh-axi --version
