#!/usr/bin/env bash
# Focused deterministic contract and behavior tests for Firstmate clone safety
# and Google Chrome system installation in scripts/install-home-agents.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
INSTALLER="$ROOT/scripts/install-home-agents.sh"
BASE_MODULE="$ROOT/modules/home-base.nix"
FIRSTMATE_MODULE="$ROOT/modules/home-firstmate.nix"
PACKAGES_DEFAULT="$ROOT/packages/default.nix"
README="$ROOT/README.md"
SMOKE_TEST="$ROOT/tests/smoke-herdr-agents.sh"

test -f "$INSTALLER"
test -f "$BASE_MODULE"
test -f "$FIRSTMATE_MODULE"
test -f "$PACKAGES_DEFAULT"
test -f "$README"
test -f "$SMOKE_TEST"

# ------------------------------------------------------------------------------
# 1. Static Contract Checks
# ------------------------------------------------------------------------------
python3 - "$INSTALLER" "$BASE_MODULE" "$FIRSTMATE_MODULE" "$PACKAGES_DEFAULT" "$README" "$SMOKE_TEST" <<'PY'
import sys
from pathlib import Path

installer = Path(sys.argv[1]).read_text(encoding="utf-8")
base_module = Path(sys.argv[2]).read_text(encoding="utf-8")
firstmate_module = Path(sys.argv[3]).read_text(encoding="utf-8")
packages_default = Path(sys.argv[4]).read_text(encoding="utf-8")
readme = Path(sys.argv[5]).read_text(encoding="utf-8")
smoke_test = Path(sys.argv[6]).read_text(encoding="utf-8")

# 1.1 scripts/install-home-agents.sh contracts
assert 'FIRSTMATE_REPO_URL="https://github.com/kunchenguid/firstmate.git"' in installer, "Missing FIRSTMATE_REPO_URL"
assert 'FIRSTMATE_DIR="$HOME/firstmate"' in installer, "Missing exact FIRSTMATE_DIR"
assert 'CHROME_DEB_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"' in installer, "Missing CHROME_DEB_URL"
assert 'find_system_chrome' in installer, "Missing find_system_chrome helper"
assert 'install_or_verify_firstmate' in installer, "Missing install_or_verify_firstmate helper"
assert 'install_or_verify_chrome' in installer, "Missing install_or_verify_chrome helper"
assert 'apt install -y' in installer, "Missing noninteractive apt install"
assert 'apt-get' not in installer, "Installer must use apt, not apt-get"
assert 'apt update' not in installer and 'apt-get update' not in installer, "Installer must not run apt update"
assert 'wget --https-only' in installer, "Missing wget --https-only download"
assert 'sudo' in installer and 'apt' in installer and 'wget' in installer, "Missing sudo/apt/wget check"
assert 'git pull' not in installer, "Installer must not auto-pull or update existing checkout"
assert 'AGENTS.md' in installer.split('install_or_verify_firstmate')[1].split('find_system_chrome')[0], "Firstmate verification must require AGENTS.md"
assert 'command -v' not in installer.split('find_system_chrome()')[1].split('}')[0], "find_system_chrome must not fall back to PATH"
assert 'sha256' not in installer.lower().split("download_verified")[-1].split("install_or_verify_chrome")[0] or 'chrome_deb' not in installer.lower().split("download_verified")[-1].split("install_or_verify_chrome")[0], "Installer must not invent a Chrome checksum"

# 1.2 modules/home-base.nix contracts
assert 'google-chrome' not in base_module.split("home.packages = (with pkgs; [")[1].split("]) ++ [")[0], "google-chrome must be removed from home.packages in home-base.nix"
assert 'CHROME_DEVTOOLS_AXI_USER_DATA_DIR' in base_module, "home-base.nix must retain CHROME_DEVTOOLS_AXI_USER_DATA_DIR"
assert 'CHROME_DEVTOOLS_AXI_HEADED' in base_module, "home-base.nix must retain CHROME_DEVTOOLS_AXI_HEADED"
assert 'createChromeDevtoolsProfileDir' in base_module, "home-base.nix must retain createChromeDevtoolsProfileDir"

# 1.3 modules/home-firstmate.nix contracts
assert 'agentPackages.treehouse' in firstmate_module, "home-firstmate.nix must retain agentPackages.treehouse"
assert 'pkgs.tmux' in firstmate_module, "home-firstmate.nix must retain pkgs.tmux"
assert 'writeShellScriptBin "firstmate"' not in firstmate_module, "Nix firstmate launcher must be removed"
assert 'agentPackages.firstmate' not in firstmate_module, "agentPackages.firstmate must be removed"

# 1.4 packages/default.nix contracts
assert 'pname = "firstmate"' not in packages_default, "packages/default.nix must not contain firstmate derivation"
assert 'firstmateCommit' not in packages_default, "packages/default.nix must not contain firstmateCommit"
assert 'firstmateSource' not in packages_default, "packages/default.nix must not contain firstmateSource"
assert 'pname = "treehouse"' in packages_default, "packages/default.nix must retain treehouse package"

# 1.5 tests/smoke-herdr-agents.sh contracts
assert 'firstmate ' not in smoke_test.split("for command_name in ")[1].split("; do")[0], "smoke test must not require firstmate command on PATH"
assert 'fm-session-start.sh' not in smoke_test.split("for command_name in ")[1].split("; do")[0], "smoke test must not require fm-session-start.sh on PATH"
assert 'firstmate_root="$HOME/firstmate"' in smoke_test, "smoke test must use exact $HOME/firstmate"
assert '/usr/bin/google-chrome-stable' in smoke_test and '/usr/bin/google-chrome' in smoke_test, "smoke test must check absolute system paths"

# 1.6 README.md documentation contracts
assert 'https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb' in readme, "README must document official Google Chrome deb URL"
assert 'pkgs.google-chrome' not in readme, "README must not claim Chrome is pkgs.google-chrome"
assert 'install-home-agents.sh' in readme, "README must document install-home-agents.sh"
assert '~/firstmate' in readme, "README must document Firstmate checkout in ~/firstmate"
assert 'apt-get' not in readme, "README must not reference apt-get"

print("Static contract checks for installer and ownership boundaries passed.")
PY

# ------------------------------------------------------------------------------
# 2. Behavioral Simulation Tests in Disposable Environment
# ------------------------------------------------------------------------------
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-installer-test.XXXXXXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

# Source install_or_verify_firstmate, find_system_chrome, and install_or_verify_chrome into test context
eval "$(sed -n '/^install_or_verify_firstmate()/,/^}/p' "$INSTALLER")"
eval "$(sed -n '/^find_system_chrome()/,/^}/p' "$INSTALLER")"
eval "$(sed -n '/^install_or_verify_chrome()/,/^}/p' "$INSTALLER")"

# 2.1 Firstmate Safe Clone Helper Tests
fm_test_repo="$tmp_dir/upstream-firstmate.git"
mkdir -p "$fm_test_repo"
git -C "$fm_test_repo" init --bare -q

valid_repo_url="https://github.com/kunchenguid/firstmate.git"
wrong_repo_url="https://github.com/other-user/firstmate.git"

# Test 2.1.1: Clone when absent
fm_target_1="$tmp_dir/firstmate-1"
(
  git_wrapper() {
    if [ "$1" = "clone" ]; then
      command git clone -q "$fm_test_repo" "$3"
      command git -C "$3" remote set-url origin "$2"
      mkdir -p "$3/projects"
      touch "$3/AGENTS.md"
    else
      command git "$@"
    fi
  }
  git() { git_wrapper "$@"; }
  install_or_verify_firstmate "$fm_target_1" "$valid_repo_url"
)
test -d "$fm_target_1"
test -d "$fm_target_1/.git"
test -d "$fm_target_1/projects"
test -f "$fm_target_1/AGENTS.md"

# Test 2.1.2: Reuse existing checkout with matching origin
(
  git() {
    if [ "$1" = "clone" ] || [ "$1" = "pull" ]; then
      printf 'FORBIDDEN_CALL: %s\n' "$1" >&2
      exit 1
    fi
    command git "$@"
  }
  install_or_verify_firstmate "$fm_target_1" "$valid_repo_url"
)

# Test 2.1.3: Refuse existing directory that is not a git repository
fm_target_nongit="$tmp_dir/firstmate-nongit"
mkdir -p "$fm_target_nongit"
touch "$fm_target_nongit/some-user-file.txt"
set +e
nongit_err="$(install_or_verify_firstmate "$fm_target_nongit" "$valid_repo_url" 2>&1)"
nongit_code=$?
set -e
test "$nongit_code" -ne 0
case "$nongit_err" in
  *"is not a git repository"*) ;;
  *) printf 'Unexpected error message on non-git dir: %s\n' "$nongit_err" >&2; exit 1 ;;
esac
test -f "$fm_target_nongit/some-user-file.txt"

# Test 2.1.4: Refuse existing git repo with wrong origin
fm_target_wrong_origin="$tmp_dir/firstmate-wrong-origin"
git clone -q "$fm_test_repo" "$fm_target_wrong_origin"
git -C "$fm_target_wrong_origin" remote set-url origin "$wrong_repo_url"
set +e
wrong_origin_err="$(install_or_verify_firstmate "$fm_target_wrong_origin" "$valid_repo_url" 2>&1)"
wrong_origin_code=$?
set -e
test "$wrong_origin_code" -ne 0
case "$wrong_origin_err" in
  *"unexpected remote origin"*) ;;
  *) printf 'Unexpected error message on wrong origin: %s\n' "$wrong_origin_err" >&2; exit 1 ;;
esac

# Test 2.1.5: Refuse existing git repo missing AGENTS.md
fm_target_no_agents="$tmp_dir/firstmate-no-agents"
git clone -q "$fm_test_repo" "$fm_target_no_agents"
git -C "$fm_target_no_agents" remote set-url origin "$valid_repo_url"
set +e
no_agents_err="$(install_or_verify_firstmate "$fm_target_no_agents" "$valid_repo_url" 2>&1)"
no_agents_code=$?
set -e
test "$no_agents_code" -ne 0
case "$no_agents_err" in
  *"does not contain required AGENTS.md"*) ;;
  *) printf 'Unexpected error message when AGENTS.md missing: %s\n' "$no_agents_err" >&2; exit 1 ;;
esac

# 2.2 Google Chrome Helper Tests
CHROME_DEB_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"

# Test 2.2.1: find_system_chrome only accepts /usr/bin absolute system paths, ignoring PATH fallbacks
(
  fake_bin_dir="$tmp_dir/fake-bin"
  mkdir -p "$fake_bin_dir"
  cat > "$fake_bin_dir/google-chrome" <<'EOF_BIN'
#!/usr/bin/env bash
exit 0
EOF_BIN
  chmod +x "$fake_bin_dir/google-chrome"
  export PATH="$fake_bin_dir:$PATH"

  # If /usr/bin binaries are absent, find_system_chrome must return 1 and ignore PATH
  if [ ! -x /usr/bin/google-chrome-stable ] && [ ! -x /usr/bin/google-chrome ]; then
    set +e
    find_res="$(find_system_chrome)"
    find_code=$?
    set -e
    test "$find_code" -ne 0
    test -z "$find_res"
  fi
)

# Test 2.2.2: Reuses existing Chrome binary without downloading or running apt
(
  find_system_chrome() {
    printf '%s\n' "$tmp_dir/fake-chrome"
  }
  cat > "$tmp_dir/fake-chrome" <<'EOF_BIN'
#!/usr/bin/env bash
printf '%s\n' "Google Chrome 134.0.6998.88"
EOF_BIN
  chmod +x "$tmp_dir/fake-chrome"

  wget() { printf 'FORBIDDEN_WGET\n' >&2; exit 1; }
  apt() { printf 'FORBIDDEN_APT\n' >&2; exit 1; }
  sudo() { printf 'FORBIDDEN_SUDO\n' >&2; exit 1; }
  curl() { printf 'FORBIDDEN_CURL\n' >&2; exit 1; }

  install_or_verify_chrome >/dev/null
)

# Test 2.2.3: Refuses when sudo is missing
(
  find_system_chrome() { return 1; }
  command() {
    if [ "$1" = "-v" ] && [ "$2" = "sudo" ]; then
      return 1
    fi
    builtin command "$@"
  }
  set +e
  err_sudo="$(install_or_verify_chrome 2>&1)"
  code_sudo=$?
  set -e
  test "$code_sudo" -ne 0
  case "$err_sudo" in
    *"sudo is required"*) ;;
    *) printf 'Unexpected error when sudo missing: %s\n' "$err_sudo" >&2; exit 1 ;;
  esac
)

# Test 2.2.4: Refuses when apt is missing
(
  find_system_chrome() { return 1; }
  command() {
    if [ "$1" = "-v" ] && [ "$2" = "apt" ]; then
      return 1
    fi
    builtin command "$@"
  }
  set +e
  err_apt="$(install_or_verify_chrome 2>&1)"
  code_apt=$?
  set -e
  test "$code_apt" -ne 0
  case "$err_apt" in
    *"apt is required"*) ;;
    *) printf 'Unexpected error when apt missing: %s\n' "$err_apt" >&2; exit 1 ;;
  esac
)

# Test 2.2.5: Refuses when wget is missing
(
  find_system_chrome() { return 1; }
  command() {
    if [ "$1" = "-v" ] && [ "$2" = "wget" ]; then
      return 1
    fi
    builtin command "$@"
  }
  set +e
  err_wget="$(install_or_verify_chrome 2>&1)"
  code_wget=$?
  set -e
  test "$code_wget" -ne 0
  case "$err_wget" in
    *"wget is required"*) ;;
    *) printf 'Unexpected error when wget missing: %s\n' "$err_wget" >&2; exit 1 ;;
  esac
)

printf '%s\n' "All home agents installer behavioral tests passed."
