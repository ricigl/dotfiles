#!/usr/bin/env bash
# Focused deterministic contract tests for the guarded Bash-to-Zsh handoff.
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

# 1.1 Home Manager Bash module enabled
assert "programs.bash = {" in base_content, "Missing programs.bash block in home-base.nix"
assert "enable = true;" in base_content.split("programs.bash = {")[1].split("};")[0], "programs.bash.enable must be true"

# 1.2 profileExtra and initExtra both wired to bashHandoff
bash_block = base_content.split("programs.bash = {")[1].split("};")[0]
assert "profileExtra = bashHandoff;" in bash_block, "profileExtra must be set to bashHandoff"
assert "initExtra = bashHandoff;" in bash_block, "initExtra must be set to bashHandoff"

# 1.3 Interactive guard checks
assert "[[ $- == *i* ]]" in base_content or "[[ -o interactive ]]" in base_content, "Missing interactive shell guard in bashHandoff"
assert "ZSH_VERSION" in base_content, "Missing ZSH_VERSION guard in bashHandoff"
assert "ZSH_NAME" in base_content, "Missing ZSH_NAME guard in bashHandoff"

# 1.4 Home Manager session variables and Nix daemon resolution
assert "hm-session-vars.sh" in base_content, "Missing hm-session-vars.sh sourcing in bashHandoff"
assert "nix-daemon.sh" in base_content, "Missing nix-daemon.sh sourcing in bashHandoff"

# 1.5 Target execution to zsh -l
assert "exec zsh -l" in base_content, "Missing exec zsh -l in bashHandoff"

# 1.6 No host mutation or root modification
for forbidden in ["chsh", "sudo", "/etc/passwd", "/etc/shells"]:
    assert forbidden not in bash_block, f"programs.bash must not contain forbidden host-mutating call: {forbidden}"

# 1.7 README contract checks
assert "guarded interactive handoff" in readme_content or "guarded Bash-to-Zsh handoff" in readme_content, "README must document guarded handoff"
assert "echo \"$SHELL $ZSH_VERSION\"" in readme_content, "README must provide fresh-shell verification command"
assert "exec zsh -l" in readme_content, "README must retain manual fallback"
assert "After activation, start a fresh login shell with `exec zsh -l`" not in readme_content, "README must not imply exec zsh -l is mandatory after every activation"

print("Static contract checks for shell handoff passed.")
PY

# 2. Behavioral simulation tests in disposable environment
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-shell-handoff-test.XXXXXXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

fake_profile="$tmp_dir/nix-profile"
mkdir -p "$fake_profile/bin" "$fake_profile/etc/profile.d"

cat > "$fake_profile/etc/profile.d/hm-session-vars.sh" <<EOF_HM
export TEST_HM_SESSION_LOADED=1
export PATH="$fake_profile/bin:\$PATH"
EOF_HM

cat > "$fake_profile/bin/zsh" <<'EOF_ZSH'
#!/usr/bin/env bash
printf "ZSH_INVOKED:%s
" "$*" >> "$HANDOFF_LOG"
printf "HM_VARS:%s
" "${TEST_HM_SESSION_LOADED:-0}" >> "$HANDOFF_LOG"
EOF_ZSH
chmod +x "$fake_profile/bin/zsh"

log_file="$tmp_dir/handoff.log"

cat > "$tmp_dir/test_handoff.sh" <<EOF_TEST
#!/usr/bin/env bash
export HOME_PROFILE_DIR="$fake_profile"
export HANDOFF_LOG="$log_file"

# Guard: interactive shell only, not already in Zsh.
if [[ \$- == *i* ]] && [ -z "\${ZSH_VERSION:-}" ] && [ -z "\${ZSH_NAME:-}" ]; then
  if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
    . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  elif [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix.sh" ]; then
    . "/nix/var/nix/profiles/default/etc/profile.d/nix.sh"
  fi

  if [ -z "\${__HM_SESS_VARS_SOURCED:-}" ]; then
    if [ -f "\$HOME_PROFILE_DIR/etc/profile.d/hm-session-vars.sh" ]; then
      . "\$HOME_PROFILE_DIR/etc/profile.d/hm-session-vars.sh"
    elif [ -f "\$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
      . "\$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    fi
  fi

  if command -v zsh >/dev/null 2>&1; then
    exec zsh -l
  elif [ -x "\$HOME_PROFILE_DIR/bin/zsh" ]; then
    exec "\$HOME_PROFILE_DIR/bin/zsh" -l
  elif [ -x "\$HOME/.nix-profile/bin/zsh" ]; then
    exec "\$HOME/.nix-profile/bin/zsh" -l
  fi
fi
EOF_TEST
chmod +x "$tmp_dir/test_handoff.sh"

# Test 2.1: Non-interactive execution must NOT trigger handoff
: > "$log_file"
bash "$tmp_dir/test_handoff.sh"
test ! -s "$log_file"

# Test 2.2: Execution with ZSH_VERSION set must NOT trigger handoff
: > "$log_file"
ZSH_VERSION="5.9" bash -i "$tmp_dir/test_handoff.sh" 2>/dev/null || true
test ! -s "$log_file"

# Test 2.3: Execution with ZSH_NAME set must NOT trigger handoff
: > "$log_file"
ZSH_NAME="zsh" bash -i "$tmp_dir/test_handoff.sh" 2>/dev/null || true
test ! -s "$log_file"

# Test 2.4: Interactive execution must load session vars and hand off to zsh -l
: > "$log_file"
bash --norc --noprofile -i -c ". '$tmp_dir/test_handoff.sh'" 2>/dev/null || true
grep -q "ZSH_INVOKED:-l" "$log_file"
grep -q "HM_VARS:1" "$log_file"

# Test 2.5: Safe fallback when zsh is not installed
rm -f "$fake_profile/bin/zsh"
: > "$log_file"
fallback_out=$(PATH="/usr/bin:/bin" bash --norc --noprofile -i -c ". '$tmp_dir/test_handoff.sh'; printf 'FALLBACK_OK\n'" 2>/dev/null || true)
echo "$fallback_out" | grep -q "FALLBACK_OK"

printf "%s\n" "All shell handoff contract tests passed."
