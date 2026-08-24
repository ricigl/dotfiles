#!/usr/bin/env bash
# Disposable checks for the user-owned Firstmate installer.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

bash -n scripts/install-firstmate.sh
bash -n scripts/install-firstmate-treehouse.sh
scripts/install-firstmate.sh --help >/dev/null
scripts/install-firstmate-treehouse.sh --help >/dev/null

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/firstmate-test.XXXXXX")"
cleanup() {
  rm -rf "$tmp_root"
}
trap cleanup EXIT HUP INT TERM

set +e
FIRSTMATE_ROOT="$tmp_root/missing" scripts/install-firstmate.sh --check >/dev/null 2>&1
status=$?
set -e
[ "$status" -eq 2 ]

set +e
FIRSTMATE_ROOT="$tmp_root/missing" scripts/install-firstmate-treehouse.sh --check >/dev/null 2>&1
status=$?
set -e
[ "$status" -eq 1 ]

grep -F '038d0f7ec6ba7238a151722931434dcf06ff37c4' scripts/install-firstmate.sh >/dev/null
grep -F 'https://github.com/kunchenguid/firstmate.git' scripts/install-firstmate.sh >/dev/null
grep -F 'TREEHOUSE_VERSION="2.0.1"' scripts/install-firstmate-treehouse.sh >/dev/null
grep -F 'TREEHOUSE_INSTALL_DIR="${TREEHOUSE_INSTALL_DIR:-$HOME/.local/bin}"' scripts/install-firstmate-treehouse.sh >/dev/null

echo "Firstmate installer disposable tests passed."
