#!/usr/bin/env bash
# Focused deterministic contract tests for WSLg display and audio environment hook.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
BASE_MODULE="$ROOT/modules/home-base.nix"
README="$ROOT/README.md"

test -f "$BASE_MODULE"
test -f "$README"

# 1. Static contract verification on modules/home-base.nix and README.md
python3 - "$BASE_MODULE" "$README" <<'PY'
import sys
from pathlib import Path

base_path = Path(sys.argv[1])
readme_path = Path(sys.argv[2])

base_content = base_path.read_text(encoding="utf-8")
readme_content = readme_path.read_text(encoding="utf-8")

# 1.1 wslgHook defined
assert "wslgHook = ''" in base_content, "Missing wslgHook definition in home-base.nix"

# 1.2 wslgHook contains conditional socket and variable checks
wslg_hook_code = base_content.split("wslgHook = ''")[1].split("'';")[0]

assert 'if [ -z "\'\'${DISPLAY:-}" ] && [ -e /tmp/.X11-unix/X0 ]; then' in wslg_hook_code, "Missing DISPLAY conditional export in wslgHook"
assert 'export DISPLAY=:0' in wslg_hook_code, "Missing export DISPLAY=:0 in wslgHook"

assert '/mnt/wslg/runtime-dir/wayland-0' in wslg_hook_code, "Missing wayland-0 socket check in wslgHook"
assert 'export WAYLAND_DISPLAY=wayland-0' in wslg_hook_code, "Missing export WAYLAND_DISPLAY in wslgHook"
assert 'export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir' in wslg_hook_code, "Missing export XDG_RUNTIME_DIR in wslgHook"

assert '/mnt/wslg/PulseServer' in wslg_hook_code, "Missing PulseServer socket check in wslgHook"
assert 'export PULSE_SERVER=unix:/mnt/wslg/PulseServer' in wslg_hook_code, "Missing export PULSE_SERVER in wslgHook"

# 1.3 programs.bash wiring: bashrcExtra = wslgHook, profileExtra = bashHandoff, initExtra = bashHandoff
bash_block = base_content.split("programs.bash = {")[1].split("};")[0]
assert "bashrcExtra = wslgHook;" in bash_block, "programs.bash.bashrcExtra must be set to wslgHook"
assert "profileExtra = bashHandoff;" in bash_block, "programs.bash.profileExtra must remain bashHandoff"
assert "initExtra = bashHandoff;" in bash_block, "programs.bash.initExtra must remain bashHandoff"

# 1.4 programs.zsh wiring: envExtra = wslgHook
zsh_block = base_content.split("programs.zsh = {")[1].split("programs.starship = {")[0]
assert "envExtra = wslgHook;" in zsh_block, "programs.zsh.envExtra must be set to wslgHook"

# 1.5 home.sessionVariables must not contain unconditional GUI/audio variables
session_vars_block = base_content.split("home.sessionVariables = {")[1].split("};")[0]
for unconditional_var in ["DISPLAY", "WAYLAND_DISPLAY", "XDG_RUNTIME_DIR", "PULSE_SERVER"]:
    assert f"{unconditional_var} =" not in session_vars_block, f"home.sessionVariables must not contain unconditional {unconditional_var}"

# 1.6 README contract checks
assert 'printf \'%s\\n\' "$DISPLAY" "$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR"' in readme_content, "README must document DISPLAY/WAYLAND/XDG verification command"
assert 'test -S /tmp/.X11-unix/X0' in readme_content, "README must document test -S /tmp/.X11-unix/X0 verification command"
assert 'export DISPLAY=:0' in readme_content, "README must document export DISPLAY=:0 manual fallback"
assert 'rebuilding' in readme_content or 'rebuild' in readme_content, "README must note fallback is only needed before rebuilding"

print("Static contract checks for WSLg display hook passed.")
PY

# 2. Behavioral simulation tests in disposable environment
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-wslg-test.XXXXXXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

# Template the hook script allowing redirected socket test roots for deterministic simulation
cat > "$tmp_dir/eval_hook.sh" <<'EOF_EVAL'
#!/bin/sh
set -e
ROOT_PREFIX="${TEST_ROOT_PREFIX:-}"

# WSLg GUI and audio socket discovery for SSH and noninteractive sessions.
if [ -z "${DISPLAY:-}" ] && [ -e "$ROOT_PREFIX/tmp/.X11-unix/X0" ]; then
  export DISPLAY=:0
fi

if [ -e "$ROOT_PREFIX/mnt/wslg/runtime-dir/wayland-0" ]; then
  if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    export WAYLAND_DISPLAY=wayland-0
  fi
  if [ -z "${XDG_RUNTIME_DIR:-}" ]; then
    export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
  fi
fi

if [ -z "${PULSE_SERVER:-}" ] && [ -e "$ROOT_PREFIX/mnt/wslg/PulseServer" ]; then
  export PULSE_SERVER=unix:/mnt/wslg/PulseServer
fi

printf "DISPLAY=%s\n" "${DISPLAY:-<UNSET>}"
printf "WAYLAND_DISPLAY=%s\n" "${WAYLAND_DISPLAY:-<UNSET>}"
printf "XDG_RUNTIME_DIR=%s\n" "${XDG_RUNTIME_DIR:-<UNSET>}"
printf "PULSE_SERVER=%s\n" "${PULSE_SERVER:-<UNSET>}"
EOF_EVAL
chmod +x "$tmp_dir/eval_hook.sh"

fake_root="$tmp_dir/fake_root"
mkdir -p "$fake_root/tmp/.X11-unix" "$fake_root/mnt/wslg/runtime-dir"

# Test 2.1: No sockets present -> all variables remain unset
out=$(env -i TEST_ROOT_PREFIX="$fake_root" /bin/sh "$tmp_dir/eval_hook.sh")
echo "$out" | grep -qx "DISPLAY=<UNSET>"
echo "$out" | grep -qx "WAYLAND_DISPLAY=<UNSET>"
echo "$out" | grep -qx "XDG_RUNTIME_DIR=<UNSET>"
echo "$out" | grep -qx "PULSE_SERVER=<UNSET>"

# Test 2.2: All sockets present, variables unset -> all variables exported
touch "$fake_root/tmp/.X11-unix/X0"
touch "$fake_root/mnt/wslg/runtime-dir/wayland-0"
touch "$fake_root/mnt/wslg/PulseServer"

out=$(env -i TEST_ROOT_PREFIX="$fake_root" /bin/sh "$tmp_dir/eval_hook.sh")
echo "$out" | grep -qx "DISPLAY=:0"
echo "$out" | grep -qx "WAYLAND_DISPLAY=wayland-0"
echo "$out" | grep -qx "XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir"
echo "$out" | grep -qx "PULSE_SERVER=unix:/mnt/wslg/PulseServer"

# Test 2.3: Existing DISPLAY (e.g. SSH X11 forwarding) must NOT be overwritten
out=$(env -i TEST_ROOT_PREFIX="$fake_root" DISPLAY="localhost:10.0" /bin/sh "$tmp_dir/eval_hook.sh")
echo "$out" | grep -qx "DISPLAY=localhost:10.0"
echo "$out" | grep -qx "WAYLAND_DISPLAY=wayland-0"
echo "$out" | grep -qx "XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir"
echo "$out" | grep -qx "PULSE_SERVER=unix:/mnt/wslg/PulseServer"

# Test 2.4: Existing WAYLAND_DISPLAY, XDG_RUNTIME_DIR, PULSE_SERVER preserved
out=$(env -i TEST_ROOT_PREFIX="$fake_root" \
  WAYLAND_DISPLAY="wayland-1" \
  XDG_RUNTIME_DIR="/run/user/1000" \
  PULSE_SERVER="tcp:127.0.0.1:4713" \
  /bin/sh "$tmp_dir/eval_hook.sh")
echo "$out" | grep -qx "DISPLAY=:0"
echo "$out" | grep -qx "WAYLAND_DISPLAY=wayland-1"
echo "$out" | grep -qx "XDG_RUNTIME_DIR=/run/user/1000"
echo "$out" | grep -qx "PULSE_SERVER=tcp:127.0.0.1:4713"

# Test 2.5: Only X11 socket present -> only DISPLAY set
rm -f "$fake_root/mnt/wslg/runtime-dir/wayland-0" "$fake_root/mnt/wslg/PulseServer"
out=$(env -i TEST_ROOT_PREFIX="$fake_root" /bin/sh "$tmp_dir/eval_hook.sh")
echo "$out" | grep -qx "DISPLAY=:0"
echo "$out" | grep -qx "WAYLAND_DISPLAY=<UNSET>"
echo "$out" | grep -qx "XDG_RUNTIME_DIR=<UNSET>"
echo "$out" | grep -qx "PULSE_SERVER=<UNSET>"

# Test 2.6: Compatibility check with bash
out=$(env -i TEST_ROOT_PREFIX="$fake_root" /bin/bash "$tmp_dir/eval_hook.sh")
echo "$out" | grep -qx "DISPLAY=:0"

printf "%s\n" "All WSLg display contract and simulation tests passed."
