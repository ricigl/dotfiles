#!/usr/bin/env bash
# Install the pinned no-mistakes Linux x86_64 release without running its gate.
set -euo pipefail

NO_MISTAKES_VERSION="1.57.0"
NO_MISTAKES_ARCHIVE="no-mistakes-v${NO_MISTAKES_VERSION}-linux-amd64.tar.gz"
NO_MISTAKES_URL="https://github.com/kunchenguid/no-mistakes/releases/download/v${NO_MISTAKES_VERSION}/${NO_MISTAKES_ARCHIVE}"
NO_MISTAKES_SHA256="1145e7bd41a013013eae4baa533d241322d20d917ffef732595460ddbf385b84"

if [ -z "${IN_NIX_SHELL:-}" ]; then
  printf '%s\n' "Run this script inside: nix develop .#orca-prime" >&2
  exit 1
fi

for command_name in curl sha256sum tar install mktemp; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$command_name" >&2
    exit 1
  }
done

install_dir="${NO_MISTAKES_INSTALL_DIR:-$HOME/.no-mistakes/bin}"
link_dir="${NO_MISTAKES_LINK_DIR:-$HOME/.local/bin}"
bin_path="$install_dir/no-mistakes"
link_path="$link_dir/no-mistakes"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/no-mistakes-install.XXXXXXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

archive_path="$tmp_dir/$NO_MISTAKES_ARCHIVE"
curl -fsSLo "$archive_path" "$NO_MISTAKES_URL"
printf '%s  %s\n' "$NO_MISTAKES_SHA256" "$archive_path" | sha256sum -c -

archive_entries="$(tar -tzf "$archive_path")"
if [ "$archive_entries" != "no-mistakes" ]; then
  printf '%s\n' "Unexpected archive layout; refusing to extract it." >&2
  exit 1
fi

tar -xzf "$archive_path" -C "$tmp_dir" --no-same-owner
if [ ! -f "$tmp_dir/no-mistakes" ]; then
  printf '%s\n' "The verified archive did not contain the no-mistakes binary." >&2
  exit 1
fi

mkdir -p "$install_dir" "$link_dir"
tmp_install="$install_dir/.no-mistakes.$$.tmp"
install -m 0755 "$tmp_dir/no-mistakes" "$tmp_install"
mv -f "$tmp_install" "$bin_path"
ln -sfn "$bin_path" "$link_path"

printf '%s\n' "no-mistakes ${NO_MISTAKES_VERSION} installed at $bin_path"
printf '%s\n' "Command link: $link_path -> $bin_path"
printf '%s\n' "The daemon was not started and this repository was not initialized."
printf '%s\n' "Run 'no-mistakes doctor' first, then use 'no-mistakes init' only after reviewing the gate configuration."

"$bin_path" --version
