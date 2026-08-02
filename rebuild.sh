#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

ln -sfn "$DIR" "$HOME/.dotfiles"

exec home-manager switch \
  --flake "$HOME/.dotfiles#$(whoami)@wsl"
