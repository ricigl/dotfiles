#!/usr/bin/env bash
# Focused deterministic contract tests for the Windows Herdr shim and PATH handling.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/windows-herdr-bootstrap.ps1"

test -f "$SCRIPT"

python3 - "$SCRIPT" <<'PY'
import sys
from pathlib import Path

script_path = Path(sys.argv[1])
content = script_path.read_text(encoding="utf-8")

# 1. Dedicated shim directory and file definitions
assert '$HerdrRemoteBinDir = Join-Path $env:LOCALAPPDATA "Programs\\Herdr\\remote-bin"' in content, "Missing HerdrRemoteBinDir definition"
assert '$HerdrShimFile = Join-Path $HerdrRemoteBinDir "herdr.cmd"' in content, "Missing HerdrShimFile definition"

# 2. Shim content generation: remote target, server keybindings, and forwarded %*
shim_line = '@"%~dp0..\\bin\\herdr.exe" --remote wsl-herdr --remote-keybindings server %*'
assert shim_line in content, f"Expected shim content {shim_line} in bootstrap script"

# 3. Idempotent User PATH modification without touching Machine PATH
assert '[Environment]::GetEnvironmentVariable("Path", "User")' in content, "Missing User PATH read"
assert '[Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")' in content, "Missing User PATH write"
assert '"Machine"' not in content.split("Set-HerdrPowerShellAlias")[1].split("Assert-Command")[0], "Machine PATH must not be modified in Set-HerdrPowerShellAlias"

# 4. Explicit herdr.exe resolution for version check so shim cannot intercept
version_check_section = content.split("if ($InstallHackNerdFont)")[1]
assert 'Get-Command herdr.exe -CommandType Application' in version_check_section, "Version check must query herdr.exe explicitly"
assert 'Get-Command herdr ' not in version_check_section, "Version check must not resolve bare herdr"
assert 'throw "Installed Herdr command failed verification: herdr.exe --version"' in version_check_section

# 5. Marked PowerShell profile alias function preserved
assert '# >>> herdr WSL remote alias >>>' in content
assert '# <<< herdr WSL remote alias <<<' in content
assert 'function herdr {' in content
assert '& `$herdrExe.Source --remote wsl-herdr --remote-keybindings server @args' in content

# 6. Marked SSH config block preserved
assert '# >>> herdr WSL SSH config >>>' in content
assert '# <<< herdr WSL SSH config <<<' in content
assert 'Host wsl-herdr' in content
assert 'IdentityFile $keyPath' in content
assert 'UserKnownHostsFile $knownHostsPath' in content

print("Windows Herdr shim contract tests passed.")
PY
