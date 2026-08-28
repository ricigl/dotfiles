#!/usr/bin/env bash
# Static and Nix validation for this repository. Does not modify host services.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT"

FLAKE_USER="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' flake.nix | head -n1)"
if [ -z "$FLAKE_USER" ]; then
  printf '%s\n' "Could not determine the configured user from flake.nix." >&2
  exit 1
fi

for script in \
  bootstrap.sh \
  rebuild.sh \
  scripts/install-home-agents.sh \
  scripts/install-prime-tools.sh \
  scripts/ubuntu-bootstrap.sh \
  scripts/ubuntu-authorize-windows-key.sh \
  scripts/validate.sh \
  tests/smoke-herdr-agents.sh \
  tests/test-prime-maintenance.sh; do
  bash -n "$script"
done
python3 -c 'import ast, pathlib; path = pathlib.Path("scripts/prime-maintenance.py"); ast.parse(path.read_text(encoding="utf-8"), filename=str(path))'

json_files=(
  home/.prime/agent/settings.json
  home/.pi/agent/settings.json
  home/.config/mcp/mcp.json
  home/.gemini/config/mcp_config.json
)
if command -v jq >/dev/null 2>&1; then
  for json_file in "${json_files[@]}"; do
    jq empty "$json_file"
  done
elif command -v node >/dev/null 2>&1; then
  node -e 'for (const path of process.argv.slice(1)) JSON.parse(require("fs").readFileSync(path, "utf8"))' "${json_files[@]}"
else
  printf '%s\n' "Neither jq nor node is available to validate settings.json." >&2
  exit 1
fi

tracked_agent_files="$(git ls-files -- '*AGENTS.md' | while IFS= read -r agent_file; do
  if test -e "$agent_file"; then
    printf '%s\n' "$agent_file"
  fi
done | sort)"
test "${tracked_agent_files}" = 'AGENTS.md'
grep -F './modules/home-firstmate.nix' flake.nix >/dev/null
grep -F 'agentPackages = import ./packages' flake.nix >/dev/null
grep -F 'version = "2.0.1"' packages/default.nix >/dev/null
grep -F 'version = "0.10.8"' packages/default.nix >/dev/null
grep -F 'version = "1.57.0"' packages/default.nix >/dev/null
grep -F 'pname = "quota-axi";' packages/default.nix >/dev/null
grep -F 'version = "0.1.32";' packages/default.nix >/dev/null
grep -F 'pname = "tasks-axi";' packages/default.nix >/dev/null
grep -F 'version = "0.2.5";' packages/default.nix >/dev/null
grep -F 'pname = "chrome-devtools-axi";' packages/default.nix >/dev/null
grep -F 'version = "0.1.31";' packages/default.nix >/dev/null
grep -F 'pname = "pi-openai-server-compaction";' packages/default.nix >/dev/null
grep -F 'piCompactionCommit = "8a3de2f3b0c178fdd6f73f2f94172dfc3943e466"' packages/default.nix >/dev/null
grep -F 'sha256-iNwxX81HRuAcUyB7ssI45azzN7PJYXLZ2BYqFh6MwV0=' packages/default.nix >/dev/null
grep -F 'google-chrome' modules/home-base.nix >/dev/null
grep -F 'CHROME_DEVTOOLS_AXI_USER_DATA_DIR' modules/home-base.nix >/dev/null
grep -F 'CHROME_DEVTOOLS_AXI_HEADED' modules/home-base.nix >/dev/null
grep -F '.local/share/chrome-devtools-axi/dev-profile' modules/home-base.nix >/dev/null
grep -F 'agentPackages.quota-axi' modules/home-base.nix >/dev/null
grep -F 'agentPackages.tasks-axi' modules/home-base.nix >/dev/null
grep -F 'agentPackages.chrome-devtools-axi' modules/home-base.nix >/dev/null
grep -F 'agentPackages.no-mistakes-skill' modules/home-common-agents.nix >/dev/null
grep -F 'home.file.".agents/skills/quota-axi"' modules/home-common-agents.nix >/dev/null
grep -F 'home.file.".agents/skills/tasks-axi"' modules/home-common-agents.nix >/dev/null
grep -F 'home.file.".agents/skills/chrome-devtools-axi"' modules/home-common-agents.nix >/dev/null
for pkg_runtime in lavish-axi-runtime gh-axi-runtime quota-axi-runtime tasks-axi-runtime chrome-devtools-axi-runtime; do
  grep -F "$pkg_runtime" packages/default.nix >/dev/null
  grep -F "$pkg_runtime" modules/home-common-agents.nix >/dev/null
done
if grep -qF 'mkdir -p "$out/lib/node_modules" "$out/bin"' packages/default.nix; then
  printf '%s\n' "CLI derivations must not install directly into shared \$out/lib/node_modules." >&2
  exit 1
fi
grep -F 'home.file.".pi/agent/extensions/calm"' modules/home-common-agents.nix >/dev/null
grep -F 'home.file.".pi/agent/extensions/terminal-status-title.js"' modules/home-common-agents.nix >/dev/null
grep -F 'home.file.".pi/agent/extensions/pi-openai-server-compaction"' modules/home-common-agents.nix >/dev/null
if grep -qF 'home.file.".pi/agent/extensions"' modules/home-legacy-agents.nix; then
  printf '%s\n' "Legacy module must not link .pi/agent/extensions as a whole directory." >&2
  exit 1
fi
if grep -qF 'algal/pi-openai-server-compaction' home/.pi/agent/settings.json; then
  printf '%s\n' "Tracked Pi settings must not contain algal git extension." >&2
  exit 1
fi
if grep -nE 'google-chrome.*\.deb|apt.*google-chrome|wget.*chrome' README.md; then
  printf '%s\n' "README must not instruct apt/.deb/wget installation of Chrome." >&2
  exit 1
fi
grep -F 'pkgs.tmux' modules/home-firstmate.nix >/dev/null
grep -F 'export FM_BACKEND=' modules/home-firstmate.nix >/dev/null
grep -F 'FM_BACKEND:-tmux' modules/home-firstmate.nix >/dev/null
grep -F 'exec pi "$@"' modules/home-firstmate.nix >/dev/null
grep -F 'herdr.url = "github:herdrdev/herdr/v0.8.2"' flake.nix >/dev/null
grep -F 'herdr.inputs.nixpkgs.follows = "nixpkgs";' flake.nix >/dev/null
python3 -c 'import json; from pathlib import Path; lock=json.loads(Path("flake.lock").read_text()); assert lock["nodes"]["herdr"]["inputs"]["nixpkgs"] == ["nixpkgs"]; assert "nixpkgs" not in lock["nodes"]'
grep -F 'herdr.packages.${pkgs.system}.default' modules/home-base.nix >/dev/null
grep -F 'home.file.".config/herdr"' modules/home-base.nix >/dev/null
if grep -qi 'herdr' modules/home-legacy-agents.nix; then
  printf '%s\n' "Legacy module must not declare Herdr directly." >&2
  exit 1
fi
test -f scripts/windows-herdr-bootstrap.ps1
test -f scripts/windows-herdr-key-bootstrap.ps1
test -f scripts/ubuntu-authorize-windows-key.sh
test ! -e scripts/windows-orca-bootstrap.ps1
if grep -nE 'InstallOrca|OrcaVersion|OrcaUrl|OrcaSha256|orca-windows-setup|windows-orca-bootstrap' scripts/windows-herdr-bootstrap.ps1; then
  printf '%s\n' "Windows Herdr bootstrap still contains an Orca installation path." >&2
  exit 1
fi
if grep -nE 'orca-wsl-authorize-|orca-wsl-public-|WslAuthorizeScriptFile|WslPublicKeyFile|AuthorizeKeyScript|__ORCA_WSL_PUBLIC_KEY_FILE__' scripts/windows-herdr-bootstrap.ps1; then
  printf '%s\n' "Windows Herdr bootstrap still contains stale cross-boundary key authorization logic." >&2
  exit 1
fi
grep -F 'Install-Herdr' scripts/windows-herdr-bootstrap.ps1 >/dev/null
grep -F 'Install-WezTerm' scripts/windows-herdr-bootstrap.ps1 >/dev/null
grep -F 'ConfigureHerdrAlias' scripts/windows-herdr-bootstrap.ps1 >/dev/null
grep -F '# >>> herdr WSL remote alias >>>' scripts/windows-herdr-bootstrap.ps1 >/dev/null
grep -F '# <<< herdr WSL remote alias <<<' scripts/windows-herdr-bootstrap.ps1 >/dev/null
grep -F 'Get-Command herdr.exe -CommandType Application' scripts/windows-herdr-bootstrap.ps1 >/dev/null
grep -F 'ssh://$WslUser@127.0.0.1:2222 @args' scripts/windows-herdr-bootstrap.ps1 >/dev/null
grep -F 'https://herdr.dev/install.ps1' scripts/windows-herdr-bootstrap.ps1 >/dev/null
grep -F 'wez.wezterm' scripts/windows-herdr-bootstrap.ps1 >/dev/null
grep -F 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' scripts/windows-herdr-bootstrap.ps1 >/dev/null
grep -F 'Ensure-WinGet' scripts/windows-herdr-bootstrap.ps1 >/dev/null
grep -F 'AllowRegister' scripts/windows-herdr-bootstrap.ps1 >/dev/null
grep -F 'Ensure-WinGet -AllowRegister' scripts/windows-herdr-bootstrap.ps1 >/dev/null
grep -F '$WinGetCommand = Ensure-WinGet' scripts/windows-herdr-bootstrap.ps1 >/dev/null
grep -F 'Get-WezTermCommand' scripts/windows-herdr-bootstrap.ps1 >/dev/null
grep -F 'ConfigureWezTerm' scripts/windows-herdr-bootstrap.ps1 >/dev/null
grep -F 'Install-WezTermConfig' scripts/windows-herdr-bootstrap.ps1 >/dev/null
grep -F 'WezTermConfigTarget' scripts/windows-herdr-bootstrap.ps1 >/dev/null
grep -F 'window_decorations = "TITLE | RESIZE"' home/.config/wezterm/wezterm.lua >/dev/null
if grep -q 'weztermCheck' scripts/windows-herdr-bootstrap.ps1; then
  printf '%s\n' "Install-WezTerm must not mask failed winget exit codes." >&2
  exit 1
fi
grep -F 'orca-wsl-manual.pub' scripts/windows-herdr-key-bootstrap.ps1 >/dev/null
grep -F 'ssh-keygen.exe -y -f' scripts/windows-herdr-key-bootstrap.ps1 >/dev/null
grep -F 'Public key fingerprint' scripts/windows-herdr-key-bootstrap.ps1 >/dev/null
grep -F 'ssh-keygen -lf -' scripts/ubuntu-authorize-windows-key.sh >/dev/null
grep -F 'getent passwd' scripts/ubuntu-authorize-windows-key.sh >/dev/null
grep -F 'herdr --remote ssh://user@server:2222' README.md >/dev/null
grep -F 'powershell.exe -NoProfile -ExecutionPolicy Bypass' README.md >/dev/null
grep -F 'windows-herdr-key-bootstrap.ps1' README.md >/dev/null
grep -F 'ubuntu-authorize-windows-key.sh' README.md >/dev/null
grep -F '%TEMP%\orca-wsl-manual.pub' README.md >/dev/null
grep -F '/mnt/c/Users/Ricardo/AppData/Local/Temp/orca-wsl-manual.pub' README.md >/dev/null
grep -F 'windows-herdr-bootstrap.ps1' README.md >/dev/null
grep -F -- '-Apply -InstallHerdr -InstallWezTerm' README.md >/dev/null
grep -F -- '-ConfigureHerdrAlias' README.md >/dev/null
grep -F -- '-ConfigureWezTerm' README.md >/dev/null
grep -F 'TITLE | RESIZE' README.md >/dev/null
grep -F 'herdr --session agents' README.md >/dev/null
grep -F -- '-VerifyOnly' README.md >/dev/null
grep -F 'wez.wezterm' README.md >/dev/null
grep -F 'https://wezterm.org/install/windows.html#installing-on-windows' README.md >/dev/null
grep -F 'https://learn.microsoft.com/windows/package-manager/winget/' README.md >/dev/null
grep -F 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' README.md >/dev/null
for ssh_policy in \
  'port 2222' \
  'listenaddress 127.0.0.1:2222' \
  'passwordauthentication no' \
  'kbdinteractiveauthentication no' \
  'pubkeyauthentication yes' \
  'permitrootlogin no'; do
  grep -F "$ssh_policy" scripts/ubuntu-bootstrap.sh >/dev/null
done
grep -F 'pi-mcp-adapter@2.27.0' home/.pi/agent/settings.json >/dev/null
grep -F 'PRIME_INSTALLER_SHA256="f29d5fed686509c1b18017d631856544d44e6df5896ddd007cd150e53696f677"' scripts/install-prime-tools.sh >/dev/null
if command -v jq >/dev/null 2>&1; then
  jq -e '
    .mcpServers.codebase_memory.command == "codebase-memory-mcp" and
    .mcpServers.codebase_memory.cwd == "/home/ricardo/src" and
    .mcpServers.codebase_memory.env.CBM_ALLOWED_ROOT == "/home/ricardo" and
    (.mcpServers.codebase_memory.excludeTools | index("delete_project")) != null and
    (.mcpServers.codebase_memory.excludeTools | index("manage_adr")) != null and
    (.mcpServers.codebase_memory.excludeTools | index("ingest_traces")) != null
  ' home/.config/mcp/mcp.json >/dev/null
  jq -e '
    .mcpServers.codebase_memory.command == "codebase-memory-mcp" and
    .mcpServers.codebase_memory.cwd == "/home/ricardo/src" and
    .mcpServers.codebase_memory.env.CBM_ALLOWED_ROOT == "/home/ricardo" and
    (.mcpServers.codebase_memory.disabledTools | index("delete_project")) != null and
    (.mcpServers.codebase_memory.disabledTools | index("manage_adr")) != null and
    (.mcpServers.codebase_memory.disabledTools | index("ingest_traces")) != null
  ' home/.gemini/config/mcp_config.json >/dev/null
else
  node -e '
    const fs = require("fs");
    const required = ["delete_project", "manage_adr", "ingest_traces"];
    const check = (path, field) => {
      const server = JSON.parse(fs.readFileSync(path, "utf8")).mcpServers.codebase_memory;
      if (server.command !== "codebase-memory-mcp" || server.cwd !== "/home/ricardo/src" || server.env.CBM_ALLOWED_ROOT !== "/home/ricardo" || !required.every((name) => server[field].includes(name))) process.exit(1);
    };
    check("home/.config/mcp/mcp.json", "excludeTools");
    check("home/.gemini/config/mcp_config.json", "disabledTools");
  '
fi

git diff --check

secret_pattern='BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY|OPENAI_API_KEY|ANTHROPIC_API_KEY|GITHUB_TOKEN|ghp_[A-Za-z0-9_]+|sk-[A-Za-z0-9_-]+'
if git grep -nE "$secret_pattern" -- . \
  ':!PLAN.md' \
  ':!SPRINT_PLAN.md' \
  ':!scripts/validate.sh'; then
  printf '%s\n' "Potential secret material found in tracked files." >&2
  exit 1
fi

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
    printf 'Forbidden runtime/secret artifact is tracked: %s\n' "$forbidden_pattern" >&2
    exit 1
  fi
done

run_nix_checks() {
  nix --extra-experimental-features 'nix-command flakes' flake check \
    --no-build --no-update-lock-file
  nix --extra-experimental-features 'nix-command flakes' build \
    --no-link --no-update-lock-file \
    ".#homeConfigurations.\"${FLAKE_USER}@wsl\".activationPackage"
  nix --extra-experimental-features 'nix-command flakes' build \
    --no-link --no-update-lock-file \
    ".#homeConfigurations.\"${FLAKE_USER}@wsl-legacy\".activationPackage"
  # Expansion occurs in the shell launched by nix develop, not in this script.
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

if command -v nix >/dev/null 2>&1; then
  run_nix_checks
else
  printf '%s\n' \
    "Nix is unavailable on this host." \
    "Run ./scripts/validate.sh inside the target Ubuntu WSL before activation."
  exit 2
fi

printf '%s\n' "Repository validation passed."
