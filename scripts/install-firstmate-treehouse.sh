#!/usr/bin/env bash
# Install Firstmate's pinned Linux Treehouse worktree provider.
# The Firstmate checkout and its upstream installer are pinned and verified
# before this wrapper delegates to that installer.
set -euo pipefail

FIRSTMATE_COMMIT="038d0f7ec6ba7238a151722931434dcf06ff37c4"
FIRSTMATE_ROOT="${FIRSTMATE_ROOT:-$HOME/firstmate}"
TREEHOUSE_VERSION="2.0.1"
TREEHOUSE_INSTALL_DIR="${TREEHOUSE_INSTALL_DIR:-$HOME/.local/bin}"
TREEHOUSE_PATH="$TREEHOUSE_INSTALL_DIR/treehouse"

usage() {
  cat <<'USAGE'
Usage: install-firstmate-treehouse.sh [--check] [--help]

Install the pinned Treehouse worktree provider through the pinned Firstmate
checkout. The binary is user-owned and defaults to ~/.local/bin/treehouse.

Options:
  --check  Verify the pinned Firstmate checkout and Treehouse version only.
  --help   Show this help.
USAGE
}

case "${1:-}" in
  "") ;;
  --check) CHECK_ONLY=1 ;;
  --help|-h) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
CHECK_ONLY="${CHECK_ONLY:-0}"

if [ "$(id -u)" -eq 0 ]; then
  printf '%s\n' "Refusing to install Treehouse as root." >&2
  exit 1
fi

case "$FIRSTMATE_ROOT" in
  /*) ;;
  *) printf '%s\n' "FIRSTMATE_ROOT must be an absolute path." >&2; exit 1 ;;
esac
case "$TREEHOUSE_INSTALL_DIR" in
  /*) ;;
  *) printf '%s\n' "TREEHOUSE_INSTALL_DIR must be an absolute path." >&2; exit 1 ;;
esac

[ -x "$FIRSTMATE_ROOT/bin/fm-install-treehouse.sh" ] || {
  printf 'Pinned Firstmate Treehouse installer is missing: %s\n' \
    "$FIRSTMATE_ROOT/bin/fm-install-treehouse.sh" >&2
  printf '%s\n' "Run: $HOME/.dotfiles/scripts/install-firstmate.sh" >&2
  exit 1
}

actual_commit="$(git -C "$FIRSTMATE_ROOT" rev-parse HEAD 2>/dev/null || true)"
[ "$actual_commit" = "$FIRSTMATE_COMMIT" ] || {
  printf 'Firstmate checkout must be at %s, got %s\n' \
    "$FIRSTMATE_COMMIT" "${actual_commit:-<missing>}" >&2
  exit 1
}

verify_treehouse() {
  [ -x "$TREEHOUSE_PATH" ] || {
    printf 'Treehouse is missing: %s\n' "$TREEHOUSE_PATH" >&2
    return 1
  }
  installed="$("$TREEHOUSE_PATH" --version 2>/dev/null | tr -d '[:space:]')"
  case "$installed" in
    "v${TREEHOUSE_VERSION}"|"${TREEHOUSE_VERSION}") ;;
    *)
      printf 'Unexpected Treehouse version: %s (expected v%s)\n' \
        "${installed:-<empty>}" "$TREEHOUSE_VERSION" >&2
      return 1
      ;;
  esac
  printf 'Treehouse: %s (%s)\n' "$TREEHOUSE_PATH" "$installed"
}

if [ "$CHECK_ONLY" -eq 1 ]; then
  verify_treehouse
  exit 0
fi

mkdir -p "$TREEHOUSE_INSTALL_DIR"
"$FIRSTMATE_ROOT/bin/fm-install-treehouse.sh" "$TREEHOUSE_INSTALL_DIR"
verify_treehouse
