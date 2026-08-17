#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROFILE="${DOTFILES_PROFILE:-default}"

case "$PROFILE" in
  default) HOME_SUFFIX="wsl" ;;
  legacy) HOME_SUFFIX="wsl-legacy" ;;
  *)
    echo "DOTFILES_PROFILE must be 'default' or 'legacy'." >&2
    exit 64
    ;;
esac

ln -sfn "$DIR" "$HOME/.dotfiles"

exec home-manager switch \
  --flake "$HOME/.dotfiles#$(whoami)@${HOME_SUFFIX}"
