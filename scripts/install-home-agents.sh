#!/usr/bin/env bash
# Install the reviewed AGY and Pi bootstrap scripts, clone Firstmate into $HOME/firstmate,
# and install Google Chrome via apt for the regular Home Manager shell and WSL host environment.
#
# NOTE: This script is an explicit host-changing installer. It installs user binaries into
# $HOME/.local/bin, clones the upstream Firstmate repository to $HOME/firstmate, and installs
# Google Chrome system packages via apt when absent.
set -euo pipefail

AGY_INSTALLER_URL="https://antigravity.google/cli/install.sh"
AGY_INSTALLER_SHA256="ee1ea43ce4e9e56356c4ab6dad907ef357ae4bdfcaadb682735909fb57c9c640"
PI_INSTALLER_URL="https://pi.dev/install.sh"
PI_INSTALLER_SHA256="a3a3604ee550bf72c5da7da3c3014cc361c14ab3b91b1b24f097d9022bd8de5b"
PI_MCP_ADAPTER_PACKAGE="npm:pi-mcp-adapter@2.27.0"
FIRSTMATE_REPO_URL="https://github.com/kunchenguid/firstmate.git"
FIRSTMATE_DIR="$HOME/firstmate"
CHROME_DEB_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"

if [ -n "${IN_NIX_SHELL:-}" ]; then
  printf '%s\n' "Run this from the regular Home Manager shell, not nix develop .#orca-prime." >&2
  exit 1
fi

for command_name in curl wget sha256sum bash sh node npm mktemp git; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$command_name" >&2
    exit 1
  }
done

if ! node -e 'const [major, minor, patch] = process.versions.node.split(".").map(Number); process.exit(major > 22 || (major === 22 && (minor > 19 || (minor === 19 && patch >= 0))) ? 0 : 1)'; then
  printf '%s\n' "Pi requires Node.js 22.19.0 or newer; refusing to bootstrap Node with a system package installer." >&2
  exit 1
fi

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/home-agents-install.XXXXXXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

download_verified() {
  local url="$1"
  local expected_sha256="$2"
  local destination="$3"
  curl -fsSLo "$destination" "$url"
  printf '%s  %s\n' "$expected_sha256" "$destination" | sha256sum -c -
}

install_or_verify_firstmate() {
  local target_dir="$1"
  local repo_url="$2"

  if [ ! -e "$target_dir" ]; then
    printf '%s\n' "Cloning Firstmate upstream repository into $target_dir..."
    git clone "$repo_url" "$target_dir"
    mkdir -p "$target_dir/projects"
  elif [ -d "$target_dir" ]; then
    if ! git -C "$target_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      printf 'Error: %s exists but is not a git repository; refusing to overwrite.\n' "$target_dir" >&2
      exit 1
    fi

    local origin_url
    origin_url="$(git -C "$target_dir" remote get-url origin 2>/dev/null || true)"
    if [ "$origin_url" != "$repo_url" ] && [ "$origin_url" != "${repo_url%.git}" ]; then
      printf 'Error: %s has unexpected remote origin "%s" (expected "%s"); refusing to overwrite.\n' \
        "$target_dir" "$origin_url" "$repo_url" >&2
      exit 1
    fi

    printf '%s\n' "Reusing existing Firstmate checkout at $target_dir (origin: $origin_url, not auto-pulling)."
    mkdir -p "$target_dir/projects"
  else
    printf 'Error: %s exists and is not a directory; refusing to overwrite.\n' "$target_dir" >&2
    exit 1
  fi

  if [ ! -f "$target_dir/AGENTS.md" ]; then
    printf 'Error: %s does not contain required AGENTS.md.\n' "$target_dir" >&2
    exit 1
  fi

  local fm_commit
  fm_commit="$(git -C "$target_dir" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
  printf 'Firstmate checkout verified at %s (commit %s).\n' "$target_dir" "$fm_commit"
}

find_system_chrome() {
  local candidate
  for candidate in /usr/bin/google-chrome-stable /usr/bin/google-chrome; do
    if [ -x "$candidate" ] 2>/dev/null; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

install_or_verify_chrome() {
  local existing_chrome
  existing_chrome="$(find_system_chrome || true)"
  if [ -n "$existing_chrome" ]; then
    local existing_version
    existing_version="$("$existing_chrome" --version 2>&1 | head -n1)"
    printf 'Google Chrome is already installed: %s (%s)\n' "$existing_version" "$existing_chrome"
    return 0
  fi

  printf '%s\n' "Google Chrome system binary not found; installing via apt from official Debian package..."

  if ! command -v sudo >/dev/null 2>&1; then
    printf 'Error: sudo is required to install Google Chrome via apt but is not available.\n' >&2
    exit 1
  fi
  if ! command -v apt >/dev/null 2>&1; then
    printf 'Error: apt is required to install Google Chrome Debian package but is not available.\n' >&2
    exit 1
  fi
  if ! command -v wget >/dev/null 2>&1; then
    printf 'Error: wget is required to download Google Chrome Debian package but is not available.\n' >&2
    exit 1
  fi

  local deb_path="$tmp_dir/google-chrome-stable_current_amd64.deb"
  printf 'Downloading Google Chrome deb from %s...\n' "$CHROME_DEB_URL"
  wget --https-only -O "$deb_path" "$CHROME_DEB_URL"

  printf '%s\n' "Installing Google Chrome Debian package via apt..."
  sudo env DEBIAN_FRONTEND=noninteractive apt install -y "$deb_path"

  local installed_chrome
  installed_chrome="$(find_system_chrome || true)"
  if [ -z "$installed_chrome" ]; then
    printf 'Error: Google Chrome binary was not found in system path after apt installation.\n' >&2
    exit 1
  fi

  local installed_version
  installed_version="$("$installed_chrome" --version 2>&1 | head -n1)"
  printf 'Google Chrome installed successfully: %s (%s)\n' "$installed_version" "$installed_chrome"
}

agy_installer="$tmp_dir/agy-install.sh"
pi_installer="$tmp_dir/pi-install.sh"
download_verified "$AGY_INSTALLER_URL" "$AGY_INSTALLER_SHA256" "$agy_installer"
download_verified "$PI_INSTALLER_URL" "$PI_INSTALLER_SHA256" "$pi_installer"

printf '%s\n' "Running the reviewed Antigravity CLI installer..."
bash "$agy_installer" --dir "$HOME/.local/bin"

printf '%s\n' "Running the reviewed Pi installer..."
sh "$pi_installer"

command -v agy >/dev/null 2>&1 || {
  printf '%s\n' "AGY was not found on PATH after installation." >&2
  exit 1
}
command -v pi >/dev/null 2>&1 || {
  printf '%s\n' "Pi was not found on PATH after installation." >&2
  exit 1
}

printf '%s\n' "Installing the pinned Pi MCP adapter..."
pi install "$PI_MCP_ADAPTER_PACKAGE"
pi list | grep -F 'pi-mcp-adapter' >/dev/null || {
  printf '%s\n' "Pinned Pi MCP adapter was not listed after installation." >&2
  exit 1
}

install_or_verify_firstmate "$FIRSTMATE_DIR" "$FIRSTMATE_REPO_URL"

install_or_verify_chrome

printf '\n=== Installation and Verification Summary ===\n'
printf 'AGY: %s (%s)\n' "$(agy --version 2>&1 | head -n1)" "$(command -v agy)"
printf 'Pi: %s (%s)\n' "$(pi --version 2>&1 | head -n1)" "$(command -v pi)"
printf 'Pi MCP Adapter: %s\n' "$(pi list 2>/dev/null | grep 'pi-mcp-adapter' | head -n1 || printf 'installed')"
printf 'Firstmate checkout: %s (commit %s)\n' "$FIRSTMATE_DIR" "$(git -C "$FIRSTMATE_DIR" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
chrome_bin="$(find_system_chrome || true)"
if [ -n "$chrome_bin" ]; then
  printf 'Google Chrome: %s (%s)\n' "$("$chrome_bin" --version 2>&1 | head -n1)" "$chrome_bin"
else
  printf 'Google Chrome: not installed\n'
fi
