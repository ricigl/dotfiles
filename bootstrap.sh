#!/usr/bin/env bash
# Bootstrap an Ubuntu WSL environment managed by Home Manager.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REAL_USER="$(whoami)"
PROFILE="${DOTFILES_PROFILE:-default}"

case "$PROFILE" in
  default) HOME_SUFFIX="wsl" ;;
  legacy) HOME_SUFFIX="wsl-legacy" ;;
  *)
    echo "DOTFILES_PROFILE must be 'default' or 'legacy'." >&2
    exit 64
    ;;
esac
HOME_TARGET="${REAL_USER}@${HOME_SUFFIX}"

echo "==> Step 1: verify Determinate Nix"
if ! command -v nix >/dev/null 2>&1; then
  echo "Nix is not available."
  echo "Install Determinate Nix, open a new WSL shell, and rerun this script."
  exit 1
fi

nix --version

echo "==> Step 2: link this repository to ~/.dotfiles"
DOTFILES_LINK="$HOME/.dotfiles"

if [ "$DIR" != "$DOTFILES_LINK" ]; then
  if [ -L "$DOTFILES_LINK" ] && [ "$(readlink -f "$DOTFILES_LINK")" = "$DIR" ]; then
    : # The expected link already exists.
  elif [ -e "$DOTFILES_LINK" ] || [ -L "$DOTFILES_LINK" ]; then
    echo "$DOTFILES_LINK already exists and does not point to this repository." >&2
    echo "Move it aside explicitly before bootstrapping from another location." >&2
    exit 1
  else
    ln -s "$DIR" "$DOTFILES_LINK"
  fi
fi

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

echo "==> Step 4: validate the locked flake"
nix flake check "$DIR" --no-update-lock-file

nix build \
  --no-link \
  --no-update-lock-file \
  "$DIR#homeConfigurations.\"${HOME_TARGET}\".activationPackage"

echo "==> Step 5: first Home Manager activation ($PROFILE profile)"
BACKUP_SUFFIX="pre-home-manager-$(date +%Y%m%d-%H%M%S)"

nix run "$DIR#home-manager" -- \
  switch \
  -b "$BACKUP_SUFFIX" \
  --flake "$DIR#${HOME_TARGET}"

echo "==> Done. Use ./rebuild.sh after future changes."
