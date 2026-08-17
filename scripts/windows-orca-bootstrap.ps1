[CmdletBinding()]
param(
    [switch]$VerifyOnly,
    [switch]$Apply,
    [switch]$InstallOrca,
    [string]$Distro = "Ubuntu"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($VerifyOnly -and $Apply) {
    throw "Choose either -VerifyOnly or -Apply."
}
if (-not $VerifyOnly -and -not $Apply) {
    $VerifyOnly = $true
}
if ($InstallOrca -and -not $Apply) {
    throw "-InstallOrca requires -Apply."
}
if ($Distro -ne "Ubuntu") {
    throw "This repository requires the WSL distro name exactly 'Ubuntu'."
}

$OrcaVersion = "1.4.184"
$OrcaUrl = "https://github.com/stablyai/orca/releases/download/v1.4.184/orca-windows-setup.exe"
$OrcaSha256 = "7765f7f085d04b7fe662ec664825fedd81427dd586023f945182a46e0a0cf5be"
$Key = Join-Path $env:USERPROFILE ".ssh\orca-wsl-ed25519"
$WslConfig = Join-Path $env:USERPROFILE ".wslconfig"
$Installer = Join-Path $env:USERPROFILE "Downloads\orca-windows-setup-$OrcaVersion.exe"

function Assert-Command {
    param([Parameter(Mandatory)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Set-IniValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Value
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    if (Test-Path $Path) {
        foreach ($line in Get-Content -LiteralPath $Path) {
            $lines.Add([string]$line)
        }
    }

    $sectionStart = -1
    $sectionEnd = $lines.Count
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^\s*\[([^]]+)\]\s*$') {
            if ($sectionStart -ge 0) {
                $sectionEnd = $index
                break
            }
            if ($Matches[1].Trim() -ieq $Section) {
                $sectionStart = $index
            }
        }
    }

    if ($sectionStart -lt 0) {
        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Trim()) {
            $lines.Add("")
        }
        $lines.Add("[$Section]")
        $lines.Add("$Key=$Value")
    }
    else {
        $updated = $false
        for ($index = $sectionStart + 1; $index -lt $sectionEnd; $index++) {
            if ($lines[$index] -match ("^\s*" + [regex]::Escape($Key) + "\s*=")) {
                $lines[$index] = "$Key=$Value"
                $updated = $true
                break
            }
        }
        if (-not $updated) {
            $lines.Insert($sectionStart + 1, "$Key=$Value")
        }
    }

    [System.IO.File]::WriteAllLines($Path, $lines)
}

Assert-Command "wsl.exe"
Assert-Command "ssh.exe"
Assert-Command "ssh-keygen.exe"

$Distros = @(
    & wsl.exe --list --quiet |
        ForEach-Object { ($_ -replace "`0", "").Trim() } |
        Where-Object { $_ }
)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to list WSL distributions."
}
if ($Distros -notcontains $Distro) {
    throw "WSL distro '$Distro' not found. Registered distros: $($Distros -join ', ')"
}

$VerboseDistros = @(
    & wsl.exe --list --verbose |
        ForEach-Object { ($_ -replace "`0", "").TrimEnd() }
)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to inspect WSL distribution versions."
}
$DistroPattern = '^\s*\*?\s*' + [regex]::Escape($Distro) + '\s+.+\s+2\s*$'
if (-not ($VerboseDistros | Where-Object { $_ -match $DistroPattern })) {
    throw "WSL distro '$Distro' must use WSL version 2."
}

& wsl.exe -d $Distro -- true
if ($LASTEXITCODE -ne 0) {
    throw "Unable to start WSL distro '$Distro'."
}

$WslUser = (& wsl.exe -d $Distro -- bash -lc 'printf %s "$USER"').Trim()
if (-not $WslUser -or $WslUser -notmatch '^[A-Za-z0-9_.-]+$') {
    throw "Could not determine a safe Ubuntu username."
}
$Target = "{0}@127.0.0.1" -f $WslUser

if ($Apply) {
    Set-IniValue -Path $WslConfig -Section "wsl2" -Key "memory" -Value "8GB"
    Set-IniValue -Path $WslConfig -Section "wsl2" -Key "processors" -Value "6"
    Set-IniValue -Path $WslConfig -Section "wsl2" -Key "swap" -Value "4GB"
    Set-IniValue -Path $WslConfig -Section "wsl2" -Key "localhostForwarding" -Value "true"

    New-Item -ItemType Directory -Force (Split-Path -Parent $Key) | Out-Null
    if (-not (Test-Path -LiteralPath $Key)) {
        & ssh-keygen.exe -t ed25519 -f $Key -C "orca-wsl" -N '""'
        if ($LASTEXITCODE -ne 0) {
            throw "ssh-keygen failed."
        }
    }

    if (-not (Test-Path -LiteralPath "$Key.pub")) {
        throw "Missing public key: $Key.pub"
    }

    Get-Content -LiteralPath "$Key.pub" -Raw |
        & wsl.exe -d $Distro -- bash -lc 'set -eu; umask 077; mkdir -p ~/.ssh; touch ~/.ssh/authorized_keys; IFS= read -r key; grep -qxF "$key" ~/.ssh/authorized_keys || printf "%s\n" "$key" >> ~/.ssh/authorized_keys; chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys'
    if ($LASTEXITCODE -ne 0) {
        throw "Could not authorize the Orca public key in Ubuntu."
    }

    if ($InstallOrca) {
        Invoke-WebRequest -Uri $OrcaUrl -OutFile $Installer
        $ActualHash = (Get-FileHash -LiteralPath $Installer -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($ActualHash -ne $OrcaSha256) {
            throw "Orca installer checksum mismatch. Expected $OrcaSha256, got $ActualHash"
        }
        Start-Process -FilePath $Installer -Wait
    }

    Write-Host "Applied Windows-side configuration. Run 'wsl --shutdown' once if .wslconfig changed, restart Ubuntu, and run this script with -VerifyOnly."
}

if (-not (Test-Path -LiteralPath $Key)) {
    throw "Dedicated Orca key is missing: $Key. Run this script with -Apply first."
}
if (-not (Test-Path -LiteralPath "$Key.pub")) {
    throw "Dedicated Orca public key is missing: $Key.pub"
}

$PortTest = Test-NetConnection -ComputerName 127.0.0.1 -Port 2222 -WarningAction SilentlyContinue
if (-not $PortTest.TcpTestSucceeded) {
    throw "Ubuntu sshd is not reachable at 127.0.0.1:2222. Run scripts/ubuntu-bootstrap.sh inside Ubuntu first."
}

$KnownHosts = Join-Path $env:TEMP "orca-wsl-known-hosts"
$SshArgs = @(
    "-o", "BatchMode=yes",
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "UserKnownHostsFile=$KnownHosts",
    "-i", $Key,
    "-p", "2222",
    $Target,
    'set -eu; test "$(uname -s)" = Linux; case "$PWD" in /home/*) ;; *) exit 1;; esac; command -v git make g++ python3 >/dev/null; git --version; make --version | sed -n "1p"; g++ --version | sed -n "1p"; python3 --version'
)
& ssh.exe @SshArgs
if ($LASTEXITCODE -ne 0) {
    throw "Loopback SSH or Orca node-pty prerequisites failed verification."
}

Write-Host "Verified WSL distro: $Distro"
Write-Host "Verified SSH target: $Target on 127.0.0.1:2222"
Write-Host "Verified dedicated key: $Key"
Write-Host "Expected Orca version: $OrcaVersion"
