#!/usr/bin/env bash
# Bootstrap an Ubuntu WSL environment managed by Home Manager.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REAL_USER="$(whoami)"

echo "==> Step 1: verify Determinate Nix"
if ! command -v nix >/dev/null 2>&1; then
  echo "Nix is not available."
  echo "Install Determinate Nix, open a new WSL shell, and rerun this script."
  exit 1
fi

nix --version

echo "==> Step 2: link this repository to ~/.dotfiles"
ln -sfn "$DIR" "$HOME/.dotfiles"

echo "==> Step 3: personalize the configured WSL username"
FLAKE_USER="$(
  sed -nE \
    's/^[[:space:]]*user = "([^"]+)";.*/\1/p' \
    "$DIR/flake.nix" |
    head -n1
)"

if [ -z "$FLAKE_USER" ]; then
  echo "Could not find the user setting in flake.nix."
  exit 1
fi

if [ "$FLAKE_USER" != "$REAL_USER" ]; then
  sed -i -E \
    "s/^([[:space:]]*user = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" \
    "$DIR/flake.nix"

  echo "Updated flake.nix user from $FLAKE_USER to $REAL_USER."
fi

echo "==> Step 4: refresh flake.lock"
nix flake lock "$DIR"

echo "==> Step 5: validate the Home Manager configuration"
nix flake check "$DIR"

nix build \
  "$DIR#homeConfigurations.\"${REAL_USER}@wsl\".activationPackage"

echo "==> Step 6: first Home Manager activation"
BACKUP_SUFFIX="pre-home-manager-$(date +%Y%m%d-%H%M%S)"

nix run github:nix-community/home-manager/release-26.05 -- \
  switch \
  -b "$BACKUP_SUFFIX" \
  --flake "$DIR#${REAL_USER}@wsl"

echo "==> Done. Use ./rebuild.sh after future changes."
