#!/usr/bin/env bash
# Install the reviewed Firstmate agent distro at a pinned upstream commit.
# Usage: install-firstmate.sh [--check] [--help]
# The checkout and its private data/state/projects remain outside this repo.
set -euo pipefail

FIRSTMATE_REPOSITORY="https://github.com/kunchenguid/firstmate.git"
FIRSTMATE_COMMIT="038d0f7ec6ba7238a151722931434dcf06ff37c4"
FIRSTMATE_ROOT="${FIRSTMATE_ROOT:-$HOME/firstmate}"

usage() {
  cat <<'USAGE'
Usage: install-firstmate.sh [--check] [--help]

Install Firstmate into $HOME/firstmate at the reviewed commit pinned by this
repository. The install is user-owned and does not use sudo, copy Firstmate
policy into this repository, or create project clones here.

Options:
  --check  Verify an existing checkout without fetching or changing it.
  --help   Show this help.
USAGE
}

case "${1:-}" in
  "") ;;
  --check)
    CHECK_ONLY=1
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
CHECK_ONLY="${CHECK_ONLY:-0}"

if [ "$(id -u)" -eq 0 ]; then
  printf '%s\n' "Refusing to install Firstmate as root." >&2
  exit 1
fi

for command_name in git printf; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$command_name" >&2
    exit 1
  }
done

case "$FIRSTMATE_ROOT" in
  /*) ;;
  *)
    printf '%s\n' "FIRSTMATE_ROOT must be an absolute path." >&2
    exit 1
    ;;
esac

verify_checkout() {
  local actual remote required

  [ -d "$FIRSTMATE_ROOT" ] || {
    printf 'Firstmate checkout is missing: %s\n' "$FIRSTMATE_ROOT" >&2
    return 2
  }
  [ ! -L "$FIRSTMATE_ROOT" ] || {
    printf 'Refusing a symlinked Firstmate root: %s\n' "$FIRSTMATE_ROOT" >&2
    return 1
  }
  [ -d "$FIRSTMATE_ROOT/.git" ] || {
    printf 'Firstmate root is not a Git checkout: %s\n' "$FIRSTMATE_ROOT" >&2
    return 1
  }

  remote="$(git -C "$FIRSTMATE_ROOT" remote get-url origin 2>/dev/null || true)"
  case "$remote" in
    https://github.com/kunchenguid/firstmate.git|git@github.com:kunchenguid/firstmate.git) ;;
    *)
      printf 'Unexpected Firstmate origin: %s\n' "${remote:-<missing>}" >&2
      return 1
      ;;
  esac

  actual="$(git -C "$FIRSTMATE_ROOT" rev-parse HEAD 2>/dev/null || true)"
  [ -n "$actual" ] || {
    printf '%s\n' "Could not resolve the Firstmate checkout commit." >&2
    return 1
  }

  for required in AGENTS.md bin/fm-bootstrap.sh bin/fm-session-start.sh bin/fm-install-treehouse.sh docs/configuration.md; do
    [ -e "$FIRSTMATE_ROOT/$required" ] || {
      printf 'Firstmate checkout is missing required path: %s\n' "$required" >&2
      return 1
    }
  done

  printf 'Firstmate root: %s\n' "$FIRSTMATE_ROOT"
  printf 'Firstmate commit: %s\n' "$actual"
  if [ "$actual" = "$FIRSTMATE_COMMIT" ]; then
    printf 'Pinned install commit: yes\n'
  else
    printf 'Pinned install commit: no (the checkout may have been intentionally updated)\n'
  fi
}

if [ "$CHECK_ONLY" -eq 1 ]; then
  verify_checkout
  exit 0
fi

if [ -e "$FIRSTMATE_ROOT" ]; then
  verify_checkout
  if [ "$(git -C "$FIRSTMATE_ROOT" status --porcelain --untracked-files=all)" ]; then
    printf '%s\n' "Refusing to update a dirty Firstmate checkout. Preserve or review its local state first." >&2
    exit 1
  fi
  current="$(git -C "$FIRSTMATE_ROOT" rev-parse HEAD)"
  if [ "$current" != "$FIRSTMATE_COMMIT" ]; then
    printf '%s\n' \
      "Existing Firstmate checkout is not at the repository pin." \
      "Use its reviewed /updatefirstmate flow or choose a fresh FIRSTMATE_ROOT; this installer will not reset it." >&2
    exit 1
  fi
  mkdir -p "$FIRSTMATE_ROOT/projects"
  printf '%s\n' "Firstmate is already installed at the pinned commit."
  exit 0
fi

mkdir -p "$(dirname "$FIRSTMATE_ROOT")"
printf 'Cloning Firstmate at reviewed commit %s...\n' "$FIRSTMATE_COMMIT"
git clone --filter=blob:none --no-checkout "$FIRSTMATE_REPOSITORY" "$FIRSTMATE_ROOT"
git -C "$FIRSTMATE_ROOT" fetch --depth=1 origin "$FIRSTMATE_COMMIT"
git -C "$FIRSTMATE_ROOT" checkout -B main "$FIRSTMATE_COMMIT"
verify_checkout
mkdir -p "$FIRSTMATE_ROOT/projects"
printf '%s\n' "Firstmate installation passed."
