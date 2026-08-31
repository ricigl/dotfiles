#!/usr/bin/env bash
# Aggregate validation entrypoint for ricigl/dotfiles repository.
# Executes static checks, deterministic subtests, environment version checks,
# read-only SSH checks, WSLg discovery, browser config, and Pi server compaction.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

FLAKE_USER="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' flake.nix | head -n1)"
if [ -z "$FLAKE_USER" ]; then
  printf '%s\n' "Could not determine the configured user from flake.nix." >&2
  exit 1
fi

IS_WSL=0
if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
  IS_WSL=1
fi

FAILURES=0
SKIPS=0
PASSES=0

# Formatting helpers
section() {
  printf '\n=== %s ===\n' "$1"
}

pass_item() {
  printf '  [PASS] %s\n' "$1"
  PASSES=$((PASSES + 1))
}

fail_item() {
  printf '  [FAIL] %s\n' "$1" >&2
  FAILURES=$((FAILURES + 1))
}

skip_item() {
  printf '  [SKIP] %s\n' "$1"
  SKIPS=$((SKIPS + 1))
}

info_item() {
  printf '  [INFO] %s: %s\n' "$1" "$2"
}

# ==============================================================================
# SECTION 1: REPOSITORY STATIC & CONTRACT CHECKS
# ==============================================================================
section "1. STATIC SYNTAX & CONTRACT CHECKS"

syntax_scripts=(
  bootstrap.sh
  rebuild.sh
  scripts/google-ai-search.sh
  scripts/install-home-agents.sh
  scripts/install-prime-tools.sh
  scripts/ubuntu-bootstrap.sh
  scripts/ubuntu-authorize-windows-key.sh
  scripts/validate.sh
  tests/lib.sh
  tests/pi-calm.test.sh
  tests/smoke-herdr-agents.sh
  tests/test-google-ai-search.sh
  tests/test-home-agents-installer.sh
  tests/test-prime-maintenance.sh
  tests/test-windows-herdr-shim.sh
  tests/test-shell-handoff.sh
  tests/test-wslg-display.sh
  tests/test-compaction-proof.sh
)

syntax_ok=1
for script in "${syntax_scripts[@]}"; do
  if [ -f "$script" ]; then
    if ! bash -n "$script" 2>/dev/null; then
      fail_item "Syntax error in $script"
      syntax_ok=0
    fi
  fi
done
if [ "$syntax_ok" -eq 1 ]; then
  pass_item "All shell scripts passed bash -n syntax validation"
fi

if python3 -c 'import ast, pathlib; path = pathlib.Path("scripts/prime-maintenance.py"); ast.parse(path.read_text(encoding="utf-8"), filename=str(path))' 2>/dev/null; then
  pass_item "scripts/prime-maintenance.py passed Python AST syntax parse"
else
  fail_item "scripts/prime-maintenance.py failed Python AST syntax parse"
fi

json_files=(
  home/.prime/agent/settings.json
  home/.pi/agent/settings.json
  home/.config/mcp/mcp.json
  home/.gemini/config/mcp_config.json
)
json_ok=1
if command -v jq >/dev/null 2>&1; then
  for json_file in "${json_files[@]}"; do
    if ! jq empty "$json_file" 2>/dev/null; then
      fail_item "JSON parse error in $json_file"
      json_ok=0
    fi
  done
elif command -v node >/dev/null 2>&1; then
  for json_file in "${json_files[@]}"; do
    if ! node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$json_file" 2>/dev/null; then
      fail_item "JSON parse error in $json_file"
      json_ok=0
    fi
  done
else
  fail_item "Neither jq nor node is available to validate JSON files"
  json_ok=0
fi
if [ "$json_ok" -eq 1 ]; then
  pass_item "All agent and MCP configuration JSON files parsed successfully"
fi

tracked_agent_files="$(git ls-files -- '*AGENTS.md' | while IFS= read -r agent_file; do
  if test -e "$agent_file"; then
    printf '%s\n' "$agent_file"
  fi
done | sort)"
if [ "${tracked_agent_files}" = 'AGENTS.md' ]; then
  pass_item "Single tracked AGENTS.md policy contract verified"
else
  fail_item "Tracked AGENTS.md policy violation: found extra tracked AGENTS.md files: ${tracked_agent_files}"
fi

# Package and module declarations
grep -F './modules/home-firstmate.nix' flake.nix >/dev/null && \
grep -F 'agentPackages = import ./packages' flake.nix >/dev/null && \
grep -F 'version = "2.0.1"' packages/default.nix >/dev/null && \
grep -F 'version = "0.10.8"' packages/default.nix >/dev/null && \
grep -F 'version = "1.57.0"' packages/default.nix >/dev/null && \
grep -F 'pname = "quota-axi";' packages/default.nix >/dev/null && \
grep -F 'version = "0.1.32";' packages/default.nix >/dev/null && \
grep -F 'pname = "tasks-axi";' packages/default.nix >/dev/null && \
grep -F 'version = "0.2.5";' packages/default.nix >/dev/null && \
grep -F 'pname = "chrome-devtools-axi";' packages/default.nix >/dev/null && \
grep -F 'version = "0.1.31";' packages/default.nix >/dev/null && \
grep -F 'pname = "pi-openai-server-compaction";' packages/default.nix >/dev/null && \
grep -F 'piCompactionCommit = "8a3de2f3b0c178fdd6f73f2f94172dfc3943e466"' packages/default.nix >/dev/null && \
grep -F 'sha256-iNwxX81HRuAcUyB7ssI45azzN7PJYXLZ2BYqFh6MwV0=' packages/default.nix >/dev/null && \
pass_item "Package versions and commit hashes in packages/default.nix verified" || \
fail_item "Package version pins in packages/default.nix failed verification"

! grep -F 'google-chrome' modules/home-base.nix >/dev/null && \
grep -F 'CHROME_DEVTOOLS_AXI_USER_DATA_DIR' modules/home-base.nix >/dev/null && \
grep -F 'CHROME_DEVTOOLS_AXI_HEADED' modules/home-base.nix >/dev/null && \
grep -F '.local/share/chrome-devtools-axi/dev-profile' modules/home-base.nix >/dev/null && \
grep -F 'agentPackages.quota-axi' modules/home-base.nix >/dev/null && \
grep -F 'agentPackages.tasks-axi' modules/home-base.nix >/dev/null && \
grep -F 'agentPackages.chrome-devtools-axi' modules/home-base.nix >/dev/null && \
grep -F '    glow' modules/home-base.nix >/dev/null && \
pass_item "Glow, Chrome DevTools profile, and AXI support declarations in modules/home-base.nix verified" || \
fail_item "Chrome DevTools or AXI declarations in modules/home-base.nix failed verification"

grep -F '"?" = "${dotfiles}/scripts/google-ai-search.sh";' modules/home-base.nix >/dev/null && \
test -x scripts/google-ai-search.sh && \
pass_item "Google AI search script and Zsh ? alias in modules/home-base.nix verified" || \
fail_item "Google AI search script or Zsh ? alias declaration failed verification"

grep -F 'agentPackages.no-mistakes-skill' modules/home-common-agents.nix >/dev/null && \
grep -F 'home.file.".agents/skills/quota-axi"' modules/home-common-agents.nix >/dev/null && \
grep -F 'home.file.".agents/skills/tasks-axi"' modules/home-common-agents.nix >/dev/null && \
grep -F 'home.file.".agents/skills/chrome-devtools-axi"' modules/home-common-agents.nix >/dev/null && \
grep -F 'home.file.".pi/agent/extensions/calm"' modules/home-common-agents.nix >/dev/null && \
grep -F 'home.file.".pi/agent/extensions/terminal-status-title.js"' modules/home-common-agents.nix >/dev/null && \
grep -F 'home.file.".pi/agent/extensions/pi-openai-server-compaction"' modules/home-common-agents.nix >/dev/null && \
pass_item "Agent skill and extension declarations in modules/home-common-agents.nix verified" || \
fail_item "Skill or extension links in modules/home-common-agents.nix failed verification"

for pkg_runtime in lavish-axi-runtime gh-axi-runtime quota-axi-runtime tasks-axi-runtime chrome-devtools-axi-runtime; do
  grep -F "$pkg_runtime" packages/default.nix >/dev/null && \
  grep -F "$pkg_runtime" modules/home-common-agents.nix >/dev/null || {
    fail_item "Missing runtime package wiring for $pkg_runtime"
  }
done

if grep -qF 'mkdir -p "$out/lib/node_modules" "$out/bin"' packages/default.nix; then
  fail_item "CLI derivations must not install directly into shared \$out/lib/node_modules"
fi

if grep -qF 'home.file.".pi/agent/extensions"' modules/home-legacy-agents.nix; then
  fail_item "Legacy module must not link .pi/agent/extensions as a whole directory"
fi

if grep -qF 'algal/pi-openai-server-compaction' home/.pi/agent/settings.json; then
  fail_item "Tracked Pi settings must not contain algal git extension"
fi

grep -F 'https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb' README.md >/dev/null && \
pass_item "README documents official Google Chrome Debian package URL and host installation" || \
fail_item "README missing Google Chrome deb URL documentation"

grep -F 'pkgs.tmux' modules/home-firstmate.nix >/dev/null && \
grep -F 'agentPackages.treehouse' modules/home-firstmate.nix >/dev/null && \
! grep -F 'firstmate =' modules/home-firstmate.nix >/dev/null && \
! grep -F 'agentPackages.firstmate' modules/home-firstmate.nix >/dev/null && \
pass_item "Firstmate dependencies (tmux and Treehouse) in modules/home-firstmate.nix verified" || \
fail_item "Firstmate dependencies in modules/home-firstmate.nix failed verification"

grep -F 'FIRSTMATE_REPO_URL="https://github.com/kunchenguid/firstmate.git"' scripts/install-home-agents.sh >/dev/null && \
grep -F 'https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb' scripts/install-home-agents.sh >/dev/null && \
grep -F 'apt install -y' scripts/install-home-agents.sh >/dev/null && \
grep -F 'herdr integration install pi' scripts/install-home-agents.sh >/dev/null && \
grep -F 'herdr integration install antigravity-cli' scripts/install-home-agents.sh >/dev/null && \
grep -F 'npx --yes skills add herdrdev/herdr --skill herdr -g' scripts/install-home-agents.sh >/dev/null && \
grep -F 'npm install --global hunkdiff' scripts/install-home-agents.sh >/dev/null && \
grep -F 'herdr plugin install "$HUNK_PLUGIN_SOURCE" --yes' scripts/install-home-agents.sh >/dev/null && \
grep -F 'herdr plugin action invoke setup-keys --plugin "$HUNK_PLUGIN_ID"' scripts/install-home-agents.sh >/dev/null && \
grep -F 'herdr server reload-config' scripts/install-home-agents.sh >/dev/null && \
grep -F 'herdr plugin install smarzban/herdr-file-viewer' scripts/install-home-agents.sh >/dev/null && \
grep -F 'HERDR_FILE_VIEWER_PLUGIN_ID="herdr-file-viewer"' scripts/install-home-agents.sh >/dev/null && \
grep -F 'HERDR_CONFIG_FILE="$HOME/.config/herdr/config.toml"' scripts/install-home-agents.sh >/dev/null && \
grep -F 'home.file.".gemini/antigravity-cli/skills/herdr"' modules/home-common-agents.nix >/dev/null && \
grep -F 'home.file.".prime/agent/skills/herdr"' modules/home-common-agents.nix >/dev/null && \
grep -F 'key = "prefix+f"' home/.config/herdr/config.toml >/dev/null && \
grep -F 'type = "plugin_action"' home/.config/herdr/config.toml >/dev/null && \
grep -F 'command = "herdr-file-viewer.open-file-viewer"' home/.config/herdr/config.toml >/dev/null && \
grep -F 'description = "open file viewer in split"' home/.config/herdr/config.toml >/dev/null && \
grep -F 'key = "prefix+shift+f"' home/.config/herdr/config.toml >/dev/null && \
grep -F 'command = "herdr-file-viewer.open-file-viewer-tab"' home/.config/herdr/config.toml >/dev/null && \
grep -F 'description = "open file viewer in tab"' home/.config/herdr/config.toml >/dev/null && \
pass_item "Glow, Herdr, file-viewer, global skill, Hunk, Firstmate, and Chrome contracts verified" || \
fail_item "Glow, Herdr integration, file-viewer, skill, Hunk, Firstmate, or Chrome contracts failed verification"

grep -F 'herdr.url = "github:herdrdev/herdr/v0.8.2"' flake.nix >/dev/null && \
grep -F 'herdr.inputs.nixpkgs.follows = "nixpkgs";' flake.nix >/dev/null && \
python3 -c 'import json; from pathlib import Path; lock=json.loads(Path("flake.lock").read_text()); assert lock["nodes"]["herdr"]["inputs"]["nixpkgs"] == ["nixpkgs"]; assert "nixpkgs" not in lock["nodes"]' 2>/dev/null && \
grep -F 'herdr.packages.${pkgs.system}.default' modules/home-base.nix >/dev/null && \
grep -F 'home.file.".config/herdr"' modules/home-base.nix >/dev/null && \
pass_item "Herdr v0.8.2 flake and profile declarations verified" || \
fail_item "Herdr v0.8.2 flake input or profile declarations failed verification"

grep -F 'programs.bash = {' modules/home-base.nix >/dev/null && \
grep -F 'bashrcExtra = wslgHook;' modules/home-base.nix >/dev/null && \
grep -F 'profileExtra = bashHandoff;' modules/home-base.nix >/dev/null && \
grep -F 'initExtra = bashHandoff;' modules/home-base.nix >/dev/null && \
grep -F 'programs.zsh = {' modules/home-base.nix >/dev/null && \
grep -F 'envExtra = wslgHook;' modules/home-base.nix >/dev/null && \
grep -F 'exec zsh -l' modules/home-base.nix >/dev/null && \
grep -F 'hm-session-vars.sh' modules/home-base.nix >/dev/null && \
pass_item "Shell hooks and guarded handoff wiring verified" || \
fail_item "Shell handoff wiring in modules/home-base.nix failed verification"

if grep -qi 'herdr' modules/home-legacy-agents.nix; then
  fail_item "Legacy module must not declare Herdr directly"
fi

test -f scripts/windows-herdr-bootstrap.ps1 && \
test -f scripts/windows-herdr-key-bootstrap.ps1 && \
test -f scripts/ubuntu-authorize-windows-key.sh && \
test ! -e scripts/windows-orca-bootstrap.ps1 && \
pass_item "Windows and Ubuntu bootstrap script presence verified" || \
fail_item "Bootstrap script presence check failed"

if grep -nE 'InstallOrca|OrcaVersion|OrcaUrl|OrcaSha256|orca-windows-setup|windows-orca-bootstrap' scripts/windows-herdr-bootstrap.ps1 >/dev/null 2>&1; then
  fail_item "Windows Herdr bootstrap still contains an Orca installation path"
fi

if grep -nE 'orca-wsl-authorize-|orca-wsl-public-|WslAuthorizeScriptFile|WslPublicKeyFile|AuthorizeKeyScript|__ORCA_WSL_PUBLIC_KEY_FILE__' scripts/windows-herdr-bootstrap.ps1 >/dev/null 2>&1; then
  fail_item "Windows Herdr bootstrap still contains stale cross-boundary key authorization logic"
fi

grep -F 'Install-Herdr' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'Install-WezTerm' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'ConfigureHerdrAlias' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'Programs\Herdr\remote-bin' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'herdr.cmd' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F -- '--remote wsl-herdr --remote-keybindings server %*' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F '[Environment]::GetEnvironmentVariable("Path", "User")' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F '[Environment]::SetEnvironmentVariable("Path",' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F '# >>> herdr WSL remote alias >>>' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F '# <<< herdr WSL remote alias <<<' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F '# >>> herdr WSL SSH config >>>' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F '# <<< herdr WSL SSH config <<<' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'Host wsl-herdr' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'IdentityFile $keyPath' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'UserKnownHostsFile $knownHostsPath' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'Get-Command herdr.exe -CommandType Application' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F -- '--remote wsl-herdr --remote-keybindings server @args' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
pass_item "Windows Herdr bootstrap and alias shim logic verified" || \
fail_item "Windows Herdr bootstrap content failed verification"

grep -F 'https://herdr.dev/install.ps1' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'wez.wezterm' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'Ensure-WinGet' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'AllowRegister' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'Ensure-WinGet -AllowRegister' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F '$WinGetCommand = Ensure-WinGet' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'Get-WezTermCommand' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'ConfigureWezTerm' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'Install-WezTermConfig' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'WezTermConfigTarget' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'InstallHackNerdFont' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'Install-HackNerdFont' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'HackNerdFontSha256' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'Microsoft\Windows\Fonts' scripts/windows-herdr-bootstrap.ps1 >/dev/null && \
grep -F 'window_decorations = "TITLE | RESIZE"' home/.config/wezterm/wezterm.lua >/dev/null && \
pass_item "WezTerm and Hack Nerd Font Windows bootstrap logic verified" || \
fail_item "WezTerm/WinGet/Font logic failed verification"

if grep -q 'weztermCheck' scripts/windows-herdr-bootstrap.ps1; then
  fail_item "Install-WezTerm must not mask failed winget exit codes"
fi

grep -F 'orca-wsl-manual.pub' scripts/windows-herdr-key-bootstrap.ps1 >/dev/null && \
grep -F 'ssh-keygen.exe -y -f' scripts/windows-herdr-key-bootstrap.ps1 >/dev/null && \
grep -F 'Public key fingerprint' scripts/windows-herdr-key-bootstrap.ps1 >/dev/null && \
grep -F 'ssh-keygen -lf -' scripts/ubuntu-authorize-windows-key.sh >/dev/null && \
grep -F 'getent passwd' scripts/ubuntu-authorize-windows-key.sh >/dev/null && \
pass_item "Key export and Ubuntu key authorization helper scripts verified" || \
fail_item "Key bootstrap helper scripts failed verification"

grep -F 'herdr.exe --remote wsl-herdr' README.md >/dev/null && \
grep -F 'Programs\Herdr\remote-bin' README.md >/dev/null && \
grep -F 'herdr.cmd' README.md >/dev/null && \
grep -F 'powershell.exe -NoProfile -ExecutionPolicy Bypass' README.md >/dev/null && \
grep -F 'windows-herdr-key-bootstrap.ps1' README.md >/dev/null && \
grep -F 'ubuntu-authorize-windows-key.sh' README.md >/dev/null && \
grep -F '%TEMP%\orca-wsl-manual.pub' README.md >/dev/null && \
grep -F '/mnt/c/Users/Ricardo/AppData/Local/Temp/orca-wsl-manual.pub' README.md >/dev/null && \
grep -F 'windows-herdr-bootstrap.ps1' README.md >/dev/null && \
grep -F -- '-Apply -InstallHerdr -InstallWezTerm' README.md >/dev/null && \
grep -F -- '-ConfigureHerdrAlias' README.md >/dev/null && \
grep -F -- '-ConfigureWezTerm' README.md >/dev/null && \
grep -F -- '-InstallHackNerdFont' README.md >/dev/null && \
grep -F 'wsl-herdr' README.md >/dev/null && \
grep -F 'TITLE | RESIZE' README.md >/dev/null && \
grep -F 'herdr --session agents' README.md >/dev/null && \
grep -F -- '-VerifyOnly' README.md >/dev/null && \
grep -F 'wez.wezterm' README.md >/dev/null && \
grep -F 'https://wezterm.org/install/windows.html#installing-on-windows' README.md >/dev/null && \
grep -F 'https://learn.microsoft.com/windows/package-manager/winget/' README.md >/dev/null && \
grep -F 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' README.md >/dev/null && \
pass_item "README installation and bootstrap documentation contracts verified" || \
fail_item "README installation contracts failed verification"

for ssh_policy in \
  'port 2222' \
  'listenaddress 127.0.0.1:2222' \
  'passwordauthentication no' \
  'kbdinteractiveauthentication no' \
  'pubkeyauthentication yes' \
  'permitrootlogin no'; do
  grep -F "$ssh_policy" scripts/ubuntu-bootstrap.sh >/dev/null || {
    fail_item "Missing $ssh_policy in scripts/ubuntu-bootstrap.sh"
  }
done
pass_item "Loopback SSH policies in scripts/ubuntu-bootstrap.sh verified"

grep -F 'pi-mcp-adapter@2.27.0' home/.pi/agent/settings.json >/dev/null && \
grep -F 'PRIME_INSTALLER_SHA256="f29d5fed686509c1b18017d631856544d44e6df5896ddd007cd150e53696f677"' scripts/install-prime-tools.sh >/dev/null && \
pass_item "Prime installer SHA-256 and Pi MCP adapter version verified" || \
fail_item "Prime installer hash or Pi MCP adapter version failed verification"

if command -v jq >/dev/null 2>&1; then
  jq -e '
    .mcpServers.codebase_memory.command == "codebase-memory-mcp" and
    .mcpServers.codebase_memory.cwd == "/home/ricardo/src" and
    .mcpServers.codebase_memory.env.CBM_ALLOWED_ROOT == "/home/ricardo" and
    (.mcpServers.codebase_memory.excludeTools | index("delete_project")) != null and
    (.mcpServers.codebase_memory.excludeTools | index("manage_adr")) != null and
    (.mcpServers.codebase_memory.excludeTools | index("ingest_traces")) != null
  ' home/.config/mcp/mcp.json >/dev/null && \
  jq -e '
    .mcpServers.codebase_memory.command == "codebase-memory-mcp" and
    .mcpServers.codebase_memory.cwd == "/home/ricardo/src" and
    .mcpServers.codebase_memory.env.CBM_ALLOWED_ROOT == "/home/ricardo" and
    (.mcpServers.codebase_memory.disabledTools | index("delete_project")) != null and
    (.mcpServers.codebase_memory.disabledTools | index("manage_adr")) != null and
    (.mcpServers.codebase_memory.disabledTools | index("ingest_traces")) != null
  ' home/.gemini/config/mcp_config.json >/dev/null && \
  pass_item "Codebase Memory MCP configuration and tool restrictions verified" || \
  fail_item "Codebase Memory MCP configuration failed verification"
fi

if git diff --check >/dev/null 2>&1; then
  pass_item "git diff --check passed without whitespace or patch errors"
else
  fail_item "git diff --check reported whitespace or conflict marker errors"
fi

secret_pattern='BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY|OPENAI_API_KEY|ANTHROPIC_API_KEY|GITHUB_TOKEN|ghp_[A-Za-z0-9_]+|sk-[A-Za-z0-9_-]+'
if git grep -nE "$secret_pattern" -- . \
  ':!PLAN.md' \
  ':!SPRINT_PLAN.md' \
  ':!scripts/validate.sh' \
  ':!tests/test-compaction-proof.sh' >/dev/null 2>&1; then
  fail_item "Potential secret material found in tracked files"
else
  pass_item "Secret scan passed: no private keys or API tokens found in tracked files"
fi

forbidden_found=0
for forbidden_pattern in \
  '.no-mistakes/**' \
  'home/.prime/agent/auth*' \
  'home/.prime/agent/sessions/**' \
  'home/.prime/agent/cache/**' \
  'home/.prime/agent/downloads/**' \
  'home/.prime/agent/telemetry.json' \
  '.codebase-memory/**' \
  'home/.cache/codebase-memory-mcp/**' \
  '**/authorized_keys' \
  '*.private-key' \
  'orca-windows-setup*.exe'; do
  if [ -n "$(git ls-files -- "$forbidden_pattern")" ]; then
    fail_item "Forbidden runtime/secret artifact is tracked: $forbidden_pattern"
    forbidden_found=1
  fi
done
if [ "$forbidden_found" -eq 0 ]; then
  pass_item "Forbidden runtime artifact scan passed: no local state/credentials tracked"
fi

# ==============================================================================
# SECTION 2: DETERMINISTIC REPOSITORY SUBTESTS
# ==============================================================================
section "2. DETERMINISTIC REPOSITORY TESTS"

run_subtest() {
  local test_script=$1
  local desc=$2
  if [ -f "$test_script" ]; then
    if _VALIDATE_SUBTEST_RUNNING=1 "$test_script" >/dev/null 2>&1; then
      pass_item "$desc ($test_script)"
    else
      fail_item "$desc failed ($test_script)"
    fi
  else
    skip_item "$desc ($test_script not found)"
  fi
}

run_subtest "./tests/test-windows-herdr-shim.sh" "Windows Herdr shim contract"
run_subtest "./tests/test-shell-handoff.sh" "Guarded Bash-to-Zsh handoff"
run_subtest "./tests/test-wslg-display.sh" "WSLg display and audio discovery hook"
run_subtest "./tests/test-home-agents-installer.sh" "Home agents, Glow, and Herdr plugin contracts"
run_subtest "./tests/test-prime-maintenance.sh" "Prime maintenance session safety"
run_subtest "./tests/test-compaction-proof.sh" "Pi OpenAI compaction proof parsing"
run_subtest "./tests/pi-calm.test.sh" "Pi Calm extension isolation and rendering"
run_subtest "./tests/test-google-ai-search.sh" "Google AI Search CLI and headless session isolation"

# ==============================================================================
# SECTION 3: ENVIRONMENT & TOOL VERSIONS
# ==============================================================================
section "3. ENVIRONMENT & TOOL VERSIONS"

report_cmd_version() {
  local name=$1
  local cmd=$2
  local version_args=${3:---version}
  local is_required=${4:-0}

  local cmd_path
  cmd_path="$(command -v "$cmd" 2>/dev/null || true)"
  if [ -n "$cmd_path" ]; then
    local ver
    ver="$( ("$cmd" $version_args 2>&1 || true) | head -n1 )"
    [ -n "$ver" ] || ver="present"
    info_item "$name" "$ver ($cmd_path)"
  else
    if [ "$IS_WSL" -eq 1 ] && [ "$is_required" -eq 1 ]; then
      fail_item "$name ($cmd) is not installed on target WSL PATH"
    elif [ "$IS_WSL" -eq 1 ]; then
      info_item "$name" "NOT INSTALLED on target WSL PATH"
    else
      info_item "$name" "not found in PATH on dev host"
    fi
  fi
}

report_cmd_presence() {
  local name=$1
  local cmd=$2
  local is_required=${3:-0}
  local fallback_path=${4:-}

  local cmd_path
  cmd_path="$(command -v "$cmd" 2>/dev/null || true)"
  if [ -z "$cmd_path" ] && [ -n "$fallback_path" ] && [ -x "$fallback_path" ]; then
    cmd_path="$fallback_path"
  fi

  if [ -n "$cmd_path" ]; then
    info_item "$name" "present ($cmd_path)"
  else
    if [ "$IS_WSL" -eq 1 ] && [ "$is_required" -eq 1 ]; then
      fail_item "$name ($cmd) is not installed on target WSL PATH"
    elif [ "$IS_WSL" -eq 1 ]; then
      info_item "$name" "NOT INSTALLED on target WSL PATH"
    else
      info_item "$name" "not found in PATH on dev host"
    fi
  fi
}

report_cmd_version "Nix" "nix" "--version" 0
report_cmd_version "Home Manager" "home-manager" "--version" 0
report_cmd_version "Git" "git" "--version" 1
report_cmd_version "Make" "make" "--version" 1
report_cmd_version "G++" "g++" "--version" 1
report_cmd_version "Python 3" "python3" "--version" 1
report_cmd_version "Node.js" "node" "--version" 1
report_cmd_version "npm" "npm" "--version" 1
report_cmd_version "Neovim" "nvim" "--version" 1
report_cmd_version "Zsh" "zsh" "--version" 1
report_cmd_version "Starship" "starship" "--version" 1
report_cmd_version "jq" "jq" "--version" 1

if command -v rg >/dev/null 2>&1; then
  report_cmd_version "ripgrep" "rg" "--version" 1
elif command -v ripgrep >/dev/null 2>&1; then
  report_cmd_version "ripgrep" "ripgrep" "--version" 1
else
  if [ "$IS_WSL" -eq 1 ]; then
    fail_item "ripgrep (rg) is not installed on target WSL PATH"
  else
    info_item "ripgrep" "not found in PATH on dev host"
  fi
fi

if command -v fd >/dev/null 2>&1; then
  report_cmd_version "fd" "fd" "--version" 1
elif command -v fdfind >/dev/null 2>&1; then
  report_cmd_version "fd (fdfind)" "fdfind" "--version" 1
else
  if [ "$IS_WSL" -eq 1 ]; then
    fail_item "fd is not installed on target WSL PATH"
  else
    info_item "fd" "not found in PATH on dev host"
  fi
fi

report_cmd_version "fzf" "fzf" "--version" 1
report_cmd_version "curl" "curl" "--version" 1
report_cmd_version "Glow" "glow" "--version" 1
report_cmd_version "GitHub CLI (gh)" "gh" "--version" 1
report_cmd_version "lazygit" "lazygit" "--version" 1
report_cmd_version "tmux" "tmux" "-V" 1
report_cmd_version "OpenSSH client (ssh)" "ssh" "-V" 1
report_cmd_presence "ssh-keygen" "ssh-keygen" 1
report_cmd_presence "OpenSSH server (sshd)" "sshd" 1 "/usr/sbin/sshd"
report_cmd_version "uv" "uv" "--version" 1
report_cmd_version "setxkbmap" "setxkbmap" "-version" 1

report_cmd_version "Herdr" "herdr" "--version" 1
report_cmd_version "Hunk" "hunk" "--version" 1
report_cmd_version "Antigravity CLI (agy)" "agy" "--version" 1
report_cmd_version "Pi" "pi" "--version" 1
report_cmd_presence "Prime (wrapper)" "prime" 1
report_cmd_version "Prime Agent (binary)" "prime-agent" "--version" 1
report_cmd_presence "Prime maintenance" "prime-maintenance" 1
report_cmd_version "Codebase Memory MCP" "codebase-memory-mcp" "--version" 1
report_cmd_version "no-mistakes" "no-mistakes" "--version" 1
report_cmd_version "lavish-axi" "lavish-axi" "--version" 1
report_cmd_version "gh-axi" "gh-axi" "--version" 1
report_cmd_version "quota-axi" "quota-axi" "--version" 1
report_cmd_version "tasks-axi" "tasks-axi" "--version" 1
report_cmd_version "chrome-devtools-axi" "chrome-devtools-axi" "--help" 1
report_cmd_presence "Google AI Search (? alias)" "google-ai-search.sh" 0 "$ROOT/scripts/google-ai-search.sh"

if [ -x /usr/bin/google-chrome-stable ]; then
  report_cmd_version "Google Chrome Stable" "/usr/bin/google-chrome-stable" "--version" 1
elif [ -x /usr/bin/google-chrome ]; then
  report_cmd_version "Google Chrome" "/usr/bin/google-chrome" "--version" 1
else
  if [ "$IS_WSL" -eq 1 ]; then
    fail_item "Google Chrome (/usr/bin/google-chrome-stable or /usr/bin/google-chrome) is not installed on target WSL"
  else
    info_item "Google Chrome" "not found in /usr/bin on dev host (installed via scripts/install-home-agents.sh on target WSL)"
  fi
fi

report_cmd_version "Treehouse" "treehouse" "--version" 1
firstmate_dir="$HOME/firstmate"
if [ -d "$firstmate_dir/.git" ]; then
  info_item "Firstmate (checkout)" "present ($firstmate_dir)"
else
  if [ "$IS_WSL" -eq 1 ]; then
    info_item "Firstmate (checkout)" "NOT CLONED on target WSL (run ./scripts/install-home-agents.sh)"
  else
    info_item "Firstmate (checkout)" "not cloned on dev host (installed via scripts/install-home-agents.sh on target WSL)"
  fi
fi

# ==============================================================================
# SECTION 4: SSH SERVER & RELAY STATUS (READ-ONLY)
# ==============================================================================
section "4. SSH SERVER & RELAY STATUS (READ-ONLY)"

if [ "$IS_WSL" -eq 1 ]; then
  sshd_bin="$(command -v sshd 2>/dev/null || true)"
  if [ -z "$sshd_bin" ] && [ -x /usr/sbin/sshd ]; then
    sshd_bin="/usr/sbin/sshd"
  fi

  if [ -n "$sshd_bin" ]; then
    pass_item "OpenSSH server binary located: $sshd_bin"
  else
    fail_item "sshd binary not found in PATH or /usr/sbin/sshd"
  fi

  # Non-interactive sudo check only (never prompt for credentials)
  if sudo -n true 2>/dev/null; then
    if sudo -n "$sshd_bin" -t 2>/dev/null; then
      pass_item "sshd configuration syntax validated (sudo -n sshd -t)"
    else
      fail_item "sshd configuration syntax error detected by sshd -t"
    fi

    effective_ssh="$(sudo -n "$sshd_bin" -T -C "user=$FLAKE_USER,host=localhost,addr=127.0.0.1" 2>/dev/null || true)"
    if [ -n "$effective_ssh" ]; then
      ssh_policy_ok=1
      for expected_ssh in \
        'port 2222' \
        'listenaddress 127.0.0.1:2222' \
        'passwordauthentication no' \
        'kbdinteractiveauthentication no' \
        'pubkeyauthentication yes' \
        'permitrootlogin no'; do
        if ! grep -Fqx "$expected_ssh" <<<"$effective_ssh"; then
          fail_item "Effective sshd policy missing setting: $expected_ssh"
          ssh_policy_ok=0
        fi
      done
      if [ "$ssh_policy_ok" -eq 1 ]; then
        pass_item "sshd effective managed policy strictly matches loopback key-only specification"
      fi
    else
      skip_item "sshd effective policy query returned empty"
    fi
  else
    skip_item "sshd privileged policy check (passwordless sudo unavailable; credential prompting avoided)"
  fi

  # Check loopback listener
  if ss -ltn 2>/dev/null | grep -Eq '127\.0\.0\.1:2222([[:space:]]|$)'; then
    pass_item "sshd daemon listener verified bound to 127.0.0.1:2222"
  else
    fail_item "sshd daemon is not listening on 127.0.0.1:2222"
  fi
else
  skip_item "SSH server daemon checks (target-only: requires Ubuntu WSL host)"
fi

# ==============================================================================
# SECTION 5: WSLG DISPLAY & AUDIO ENVIRONMENT
# ==============================================================================
section "5. WSLG DISPLAY & AUDIO ENVIRONMENT"

info_item "DISPLAY environment variable" "${DISPLAY:-<UNSET>}"
info_item "WAYLAND_DISPLAY environment variable" "${WAYLAND_DISPLAY:-<UNSET>}"
info_item "XDG_RUNTIME_DIR environment variable" "${XDG_RUNTIME_DIR:-<UNSET>}"
info_item "PULSE_SERVER environment variable" "${PULSE_SERVER:-<UNSET>}"

if [ "$IS_WSL" -eq 1 ]; then
  x11_socket_found=""
  for sock in /tmp/.X11-unix/X0 /mnt/wslg/.X11-unix/X0 /mnt/wslg/tmp/.X11-unix/X0; do
    if [ -S "$sock" ]; then
      x11_socket_found="$sock"
      break
    fi
  done

  if [ -n "$x11_socket_found" ]; then
    pass_item "WSLg X11 socket discovered: $x11_socket_found"
  else
    fail_item "No WSLg X11 socket found (/tmp/.X11-unix/X0, /mnt/wslg/.X11-unix/X0, /mnt/wslg/tmp/.X11-unix/X0)"
  fi

  wayland_socket_found=""
  user_uid="$(id -u 2>/dev/null || true)"
  for wsock in /mnt/wslg/runtime-dir/wayland-0 "/run/user/${user_uid}/wayland-0"; do
    if [ -S "$wsock" ] || [ -e "$wsock" ]; then
      wayland_socket_found="$wsock"
      break
    fi
  done
  if [ -n "$wayland_socket_found" ]; then
    info_item "WSLg Wayland socket discovered" "$wayland_socket_found"
  else
    info_item "WSLg Wayland socket" "none present"
  fi

  if [ -S /mnt/wslg/PulseServer ] || [ -e /mnt/wslg/PulseServer ]; then
    info_item "WSLg PulseServer socket discovered" "/mnt/wslg/PulseServer"
  fi

  if [ -n "${DISPLAY:-}" ]; then
    pass_item "Active DISPLAY value exported: $DISPLAY"
  else
    fail_item "DISPLAY is unset in WSL environment (manual fallback: export DISPLAY=:0 before rebuild)"
  fi
else
  skip_item "WSLg socket discovery (target-only: requires WSL environment)"
fi

# ==============================================================================
# SECTION 6: BROWSER & CHROME DEVTOOLS AXI CONFIGURATION
# ==============================================================================
section "6. BROWSER & CHROME DEVTOOLS AXI CONFIGURATION"

chrome_cmd=""
if [ -x /usr/bin/google-chrome-stable ]; then
  chrome_cmd="/usr/bin/google-chrome-stable"
elif [ -x /usr/bin/google-chrome ]; then
  chrome_cmd="/usr/bin/google-chrome"
fi

if [ -n "$chrome_cmd" ]; then
  chrome_ver="$("$chrome_cmd" --version 2>&1 | head -n1)"
  pass_item "Google Chrome binary verified: $chrome_ver ($chrome_cmd)"
else
  if [ "$IS_WSL" -eq 1 ]; then
    fail_item "Google Chrome (/usr/bin/google-chrome-stable or /usr/bin/google-chrome) is not present on target"
  else
    info_item "Google Chrome binary" "not in /usr/bin on dev host (installed via scripts/install-home-agents.sh on target WSL)"
  fi
fi

# Static check for CHROME_DEVTOOLS_AXI_HEADED == 1
if grep -F 'CHROME_DEVTOOLS_AXI_HEADED = "1";' modules/home-base.nix >/dev/null 2>&1; then
  pass_item "CHROME_DEVTOOLS_AXI_HEADED = 1 declared in modules/home-base.nix"
else
  fail_item "CHROME_DEVTOOLS_AXI_HEADED = 1 declaration missing from modules/home-base.nix"
fi

# Runtime check if environment variable is set
if [ -n "${CHROME_DEVTOOLS_AXI_HEADED:-}" ]; then
  if [ "$CHROME_DEVTOOLS_AXI_HEADED" = "1" ]; then
    pass_item "Runtime CHROME_DEVTOOLS_AXI_HEADED = 1 confirmed"
  else
    fail_item "Runtime CHROME_DEVTOOLS_AXI_HEADED has unexpected value: $CHROME_DEVTOOLS_AXI_HEADED"
  fi
else
  if [ "$IS_WSL" -eq 1 ]; then
    fail_item "Runtime CHROME_DEVTOOLS_AXI_HEADED is unset (expected 1)"
  else
    info_item "Runtime CHROME_DEVTOOLS_AXI_HEADED" "unset on dev host (exported as 1 in Home Manager session)"
  fi
fi

# Static check for CHROME_DEVTOOLS_AXI_USER_DATA_DIR
expected_profile_rel=".local/share/chrome-devtools-axi/dev-profile"
if grep -F "$expected_profile_rel" modules/home-base.nix >/dev/null 2>&1; then
  pass_item "CHROME_DEVTOOLS_AXI_USER_DATA_DIR target path declared in modules/home-base.nix"
else
  fail_item "CHROME_DEVTOOLS_AXI_USER_DATA_DIR target path missing from modules/home-base.nix"
fi

# Profile directory permission and existence check
profile_dir="$HOME/$expected_profile_rel"
if [ -d "$profile_dir" ]; then
  profile_mode="$(python3 -c "import os, stat; print(oct(stat.S_IMODE(os.stat('$profile_dir').st_mode)))" 2>/dev/null || true)"
  if [ "$profile_mode" = "0o700" ] || [ "$profile_mode" = "0700" ]; then
    pass_item "Chrome DevTools profile directory exists with mode 0700 (drwx------)"
  else
    fail_item "Chrome DevTools profile directory permissions mode is $profile_mode (expected 0700)"
  fi
else
  if [ "$IS_WSL" -eq 1 ]; then
    fail_item "Chrome DevTools profile directory is missing: $profile_dir (created during Home Manager activation)"
  else
    info_item "Chrome DevTools profile directory" "not yet created on dev host (created on Home Manager activation with mode 0700)"
  fi
fi

# ==============================================================================
# SECTION 7: PI OPENAI SERVER-SIDE COMPACTION STATUS
# ==============================================================================
section "7. PI OPENAI SERVER-SIDE COMPACTION STATUS"

grep -F 'piCompactionCommit = "8a3de2f3b0c178fdd6f73f2f94172dfc3943e466"' packages/default.nix >/dev/null && \
grep -F 'sha256-iNwxX81HRuAcUyB7ssI45azzN7PJYXLZ2BYqFh6MwV0=' packages/default.nix >/dev/null && \
grep -F 'home.file.".pi/agent/extensions/pi-openai-server-compaction"' modules/home-common-agents.nix >/dev/null && \
grep -F 'pi-openai-server-compaction-runtime' packages/npm/pi-openai-server-compaction/package.json >/dev/null && \
pass_item "Pinned pi-openai-server-compaction package, commit 8a3de2f, and extension wiring verified" || \
fail_item "Pi compaction package or extension wiring failed verification"

validate_compaction_session() {
  local session_file=$1
  python3 - "$session_file" <<'PY'
import json
import pathlib
import sys

def validate_compaction_session(path_str):
    path = pathlib.Path(path_str)
    if not path.is_file():
        return False, f"File not found or not a regular file: {path_str}"

    entries = []
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line_no, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue
                try:
                    entries.append(json.loads(line))
                except json.JSONDecodeError as e:
                    return False, f"Malformed JSON on line {line_no}"
    except Exception as e:
        return False, f"Failed to read file: {type(e).__name__}"

    if not entries:
        return False, "Session file is empty"

    has_remote_compaction = False
    has_replacement_history = False
    compaction_item_count = 0
    replacement_count = 0

    for entry in entries:
        if not isinstance(entry, dict):
            continue
        entry_type = entry.get("type")
        if entry_type in ("compaction", "compaction_summary"):
            compaction_item_count += 1

        details = entry.get("details")
        if isinstance(details, dict):
            remote = details.get("remoteCompaction")
            if isinstance(remote, dict):
                impl = remote.get("implementation")
                if impl == "responses_compaction_v2":
                    has_remote_compaction = True
                    history = remote.get("replacementHistory")
                    if isinstance(history, list) and len(history) > 0:
                        has_replacement_history = True
                        replacement_count = len(history)
            if details.get("type") in ("compaction", "compaction_summary"):
                compaction_item_count += 1

        remote = entry.get("remoteCompaction")
        if isinstance(remote, dict):
            impl = remote.get("implementation")
            if impl == "responses_compaction_v2":
                has_remote_compaction = True
                history = remote.get("replacementHistory")
                if isinstance(history, list) and len(history) > 0:
                    has_replacement_history = True
                    replacement_count = len(history)

    last_entry = entries[-1] if entries else {}
    last_is_compaction = (
        last_entry.get("type") in ("compaction", "compaction_summary") or
        (isinstance(last_entry.get("details"), dict) and last_entry["details"].get("type") in ("compaction", "compaction_summary"))
    )

    if not has_remote_compaction:
        return False, "Missing details.remoteCompaction.implementation == 'responses_compaction_v2'"
    if not has_replacement_history:
        return False, "Missing or empty replacementHistory in remoteCompaction"
    if compaction_item_count == 0 or not last_is_compaction:
        return False, "Missing final compaction item in session"

    return True, f"Valid responses_compaction_v2 session ({len(entries)} entries, {replacement_count} replacement history items, {compaction_item_count} compaction items)"

ok, msg = validate_compaction_session(sys.argv[1])
print(msg)
sys.exit(0 if ok else 1)
PY
}

if [ -n "${PI_COMPACTION_SESSION_FILE:-}" ]; then
  if compaction_result="$(validate_compaction_session "$PI_COMPACTION_SESSION_FILE" 2>&1)"; then
    pass_item "Live compaction proof verified: $compaction_result"
  else
    fail_item "Live compaction proof failed: $compaction_result"
  fi
else
  skip_item "Live server compaction proof (no explicit session file provided via PI_COMPACTION_SESSION_FILE)"
  info_item "To verify live server compaction" "PI_COMPACTION_SESSION_FILE=/path/to/session.jsonl ./scripts/validate.sh"
fi

# ==============================================================================
# SECTION 8: NIX BUILD & RUNTIME SMOKE CHECKS
# ==============================================================================
section "8. NIX BUILD & RUNTIME SMOKE CHECKS"

run_nix_checks() {
  nix --extra-experimental-features 'nix-command flakes' flake check \
    --no-build --no-update-lock-file
  nix --extra-experimental-features 'nix-command flakes' build \
    --no-link --no-update-lock-file \
    ".#homeConfigurations.\"${FLAKE_USER}@wsl\".activationPackage"
  nix --extra-experimental-features 'nix-command flakes' build \
    --no-link --no-update-lock-file \
    ".#homeConfigurations.\"${FLAKE_USER}@wsl-legacy\".activationPackage"
  # shellcheck disable=SC2016
  nix --extra-experimental-features 'nix-command flakes' develop \
    --no-update-lock-file .#orca-prime \
    --command sh -c '
      node --version | grep -Eq "^v22\."
      python3 --version
      uv --version
      gh --version
      test "$PRIME_AGENT_TELEMETRY" = 0
      test "$LAVISH_AXI_HOST" = 127.0.0.1
      test "$NPM_CONFIG_PREFIX" = "$HOME/.local/share/npm"
      case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) exit 1 ;; esac
      test "$CBM_ALLOWED_ROOT" = /home/ricardo
      test "$CBM_CACHE_DIR" = /home/ricardo/.cache/codebase-memory-mcp
      test "$CBM_DIAGNOSTICS" = 0
    '
}

NIX_BLOCKED=0
if command -v nix >/dev/null 2>&1; then
  if run_nix_checks >/dev/null 2>&1; then
    pass_item "Nix flake check, WSL activation builds, and orca-prime dev shell verified"
  else
    fail_item "Nix flake check or activation package build failed"
  fi

  if [ "$IS_WSL" -eq 1 ]; then
    if ./tests/smoke-herdr-agents.sh >/dev/null 2>&1; then
      pass_item "Runtime smoke tests passed (tests/smoke-herdr-agents.sh)"
    else
      fail_item "Runtime smoke tests failed (tests/smoke-herdr-agents.sh)"
    fi
  else
    skip_item "smoke-herdr-agents.sh (target-only: requires Ubuntu WSL host)"
  fi
else
  skip_item "Nix build and activation checks (Nix is unavailable on this host)"
  info_item "Nix activation" "Target-only requirement. Run ./scripts/validate.sh in Ubuntu WSL after Nix install."
  NIX_BLOCKED=1
fi

# ==============================================================================
# SECTION 9: VALIDATION SUMMARY
# ==============================================================================
section "VALIDATION SUMMARY"

printf '  Total checks passed: %d\n' "$PASSES"
printf '  Total checks skipped: %d\n' "$SKIPS"
printf '  Total checks failed: %d\n' "$FAILURES"

if [ "$FAILURES" -gt 0 ]; then
  printf '\nValidation FAILED with %d error(s).\n' "$FAILURES" >&2
  exit 1
fi

if [ "$NIX_BLOCKED" -eq 1 ]; then
  printf '\nRepository static contracts and deterministic subtests PASSED.\n'
  printf 'Target-only blocker: Nix is unavailable on this host.\n'
  printf 'Run ./scripts/validate.sh inside Ubuntu WSL after Determinate Nix installation to verify activation.\n'
  exit 2
fi

printf '\nRepository validation PASSED successfully.\n'
exit 0
