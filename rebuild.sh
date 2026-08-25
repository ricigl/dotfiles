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
BACKUP_SUFFIX="${HOME_MANAGER_BACKUP_SUFFIX:-home-manager-$(date +%Y%m%d-%H%M%S)}"

relocate_stale_skill_backups() {
  local state_root="${XDG_STATE_HOME:-$HOME/.local/state}/orca-prime/skill-backups"
  local run_root="$state_root/home-manager-$(date +%Y%m%d-%H%M%S)"
  local root_spec root_label skill_root backup destination managed_skill existing
  local skill_roots=(
    "shared:$HOME/.agents/skills"
    "agy:$HOME/.gemini/antigravity-cli/skills"
    "prime:$HOME/.prime/agent/skills"
  )
  local managed_skills=(caveman gh-axi i-have-adhd lavish no-mistakes)

  shopt -s nullglob
  for root_spec in "${skill_roots[@]}"; do
    root_label="${root_spec%%:*}"
    skill_root="${root_spec#*:}"
    [ -d "$skill_root" ] || continue

    for managed_skill in "${managed_skills[@]}"; do
      existing="$skill_root/$managed_skill"
      if [ -d "$existing" ] && [ ! -L "$existing" ]; then
        destination="$run_root/$root_label"
        mkdir -p "$destination"
        mv -- "$existing" "$destination/"
        printf 'Relocated mutable managed skill: %s -> %s\n' "$existing" "$destination/"
      fi
    done

    for backup in \
      "$skill_root"/*.home-manager-* \
      "$skill_root"/*.pre-home-manager-* \
      "$skill_root"/*.pre-orca-prime-*; do
      [ -d "$backup" ] || continue
      destination="$run_root/$root_label"
      mkdir -p "$destination"
      mv -- "$backup" "$destination/"
      printf 'Relocated stale skill backup: %s -> %s\n' "$backup" "$destination/"
    done
  done
  shopt -u nullglob
}

relocate_stale_skill_backups

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
  -b "$BACKUP_SUFFIX" \
  --flake "$HOME/.dotfiles#$(whoami)@${HOME_SUFFIX}"
