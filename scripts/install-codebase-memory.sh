#!/usr/bin/env bash
# Install the pinned Linux x86_64 Codebase Memory MCP portable release.
set -euo pipefail

CBM_VERSION="0.10.8"
CBM_URL="https://github.com/DeusData/codebase-memory-mcp/releases/download/v0.10.8/codebase-memory-mcp-linux-amd64-portable.tar.gz"
CBM_SHA256="6eef49652bc0c7820f43114125044d40bf7f4d97c11b2592f6b0f6a307702325"
INSTALL_DIR="$HOME/.local/bin"
INSTALL_PATH="$INSTALL_DIR/codebase-memory-mcp"

if [ -z "${IN_NIX_SHELL:-}" ]; then
  printf '%s\n' "Run this script inside: nix develop .#orca-prime" >&2
  exit 1
fi

if [ "$(uname -s)" != "Linux" ] || [ "$(uname -m)" != "x86_64" ]; then
  printf '%s\n' "This installer supports Linux x86_64 only." >&2
  exit 1
fi

for command_name in curl sha256sum tar find install mktemp; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$command_name" >&2
    exit 1
  }
done

umask 077
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/codebase-memory-mcp.XXXXXXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
  rm -f "${tmp_install:-}"
}
trap cleanup EXIT HUP INT TERM

archive="$tmp_dir/codebase-memory-mcp.tar.gz"
extract_dir="$tmp_dir/extract"
mkdir -p "$extract_dir"

curl -fsSLo "$archive" "$CBM_URL"
printf '%s  %s\n' "$CBM_SHA256" "$archive" | sha256sum -c -

while IFS= read -r entry; do
  case "$entry" in
    /*|../*|*/../*|*"/.."|"")
      printf 'Unsafe archive path: %s\n' "$entry" >&2
      exit 1
      ;;
  esac
done < <(tar -tzf "$archive")

tar -xzf "$archive" -C "$extract_dir"

binary="$(find "$extract_dir" -type f -name codebase-memory-mcp -perm /111 -print -quit)"
if [ -z "$binary" ]; then
  printf '%s\n' "Archive did not contain executable codebase-memory-mcp." >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"
tmp_install="$(mktemp "$INSTALL_DIR/.codebase-memory-mcp.XXXXXXXXXX")"
install -m 0755 "$binary" "$tmp_install"
mv -f "$tmp_install" "$INSTALL_PATH"

version_output="$("$INSTALL_PATH" --version)"
case "$version_output" in
  *"$CBM_VERSION"*) ;;
  *)
    printf 'Unexpected codebase-memory-mcp version output: %s\n' "$version_output" >&2
    exit 1
    ;;
esac

printf '%s\n' "$version_output"
