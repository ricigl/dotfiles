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

DOTFILES_LINK="$HOME/.dotfiles"

if [ "$DIR" != "$DOTFILES_LINK" ]; then
  if [ -L "$DOTFILES_LINK" ] && [ "$(readlink -f "$DOTFILES_LINK")" = "$DIR" ]; then
    : # The expected link already exists.
  elif [ -e "$DOTFILES_LINK" ] || [ -L "$DOTFILES_LINK" ]; then
    echo "$DOTFILES_LINK already exists and does not point to this repository." >&2
    exit 1
  else
    ln -s "$DIR" "$DOTFILES_LINK"
  fi
fi

exec home-manager switch \
  --flake "$HOME/.dotfiles#$(whoami)@${HOME_SUFFIX}"
