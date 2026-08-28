[CmdletBinding()]
param(
    [switch]$VerifyOnly,
    [switch]$Apply,
    [switch]$InstallHerdr,
    [switch]$InstallWezTerm,
    [switch]$ConfigureHerdrAlias,
    [switch]$ConfigureWezTerm,
    [switch]$InstallHackNerdFont,
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
if ($InstallHerdr -and -not $Apply) {
    throw "-InstallHerdr requires -Apply."
}
if ($InstallWezTerm -and -not $Apply) {
    throw "-InstallWezTerm requires -Apply."
}
if ($ConfigureHerdrAlias -and -not $Apply) {
    throw "-ConfigureHerdrAlias requires -Apply."
}
if ($ConfigureWezTerm -and -not $Apply) {
    throw "-ConfigureWezTerm requires -Apply."
}
if ($InstallHackNerdFont -and -not $Apply) {
    throw "-InstallHackNerdFont requires -Apply."
}
if ($Distro -ne "Ubuntu") {
    throw "This repository requires the WSL distro name exactly 'Ubuntu'."
}

$HerdrVersion = "0.8.2"
$HerdrInstallerUrl = "https://herdr.dev/install.ps1"
$HerdrInstallerSha256 = "3415ea0bc562cad003afcc70ac9916b81cde043c4c26087f05255ae7807d1ba7"
$HerdrInstallDir = Join-Path $env:LOCALAPPDATA "Programs\Herdr\bin"
$HerdrRemoteBinDir = Join-Path $env:LOCALAPPDATA "Programs\Herdr\remote-bin"
$HerdrShimFile = Join-Path $HerdrRemoteBinDir "herdr.cmd"
$HerdrInstaller = Join-Path ([System.IO.Path]::GetTempPath()) ("herdr-install-" + [System.Guid]::NewGuid().ToString("N") + ".ps1")
$WezTermPackageId = "wez.wezterm"
$HackNerdFontVersion = "3.5.1"
$HackNerdFontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v$HackNerdFontVersion/Hack.zip"
$HackNerdFontSha256 = "fa24da7de7cefe7766614d27762570b20453c852fc1d5b657111666df9a5e449"
$HackNerdFontInstallDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
$HackNerdFontRegistryPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
$WezTermConfigSource = Join-Path $PSScriptRoot "..\home\.config\wezterm\wezterm.lua"
$WezTermConfigTarget = Join-Path $env:USERPROFILE ".config\wezterm\wezterm.lua"
$Key = Join-Path $env:USERPROFILE ".ssh\orca-wsl-ed25519"
$HerdrSshConfig = Join-Path $env:USERPROFILE ".ssh\config"
$HerdrSshKnownHosts = Join-Path $env:USERPROFILE ".ssh\orca-wsl-known-hosts"
$WslConfig = Join-Path $env:USERPROFILE ".wslconfig"

function Assert-Command {
    param([Parameter(Mandatory)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Ensure-WinGet {
    param(
        [switch]$AllowRegister
    )

    $windowsAppsDir = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
    if ((Test-Path -LiteralPath $windowsAppsDir) -and ($env:Path -notlike "*$windowsAppsDir*")) {
        $env:Path = "$windowsAppsDir;$env:Path"
    }

    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $cmd) {
        $cmd = Get-Command winget -ErrorAction SilentlyContinue
    }
    if ($cmd) {
        return $cmd
    }

    if ($AllowRegister) {
        $appInstallerPkg = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -ErrorAction SilentlyContinue
        if ($appInstallerPkg) {
            try {
                Add-AppxPackage -RegisterByFamilyName -MainPackage "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe" -ErrorAction Stop
            }
            catch {
            }

            if ((Test-Path -LiteralPath $windowsAppsDir) -and ($env:Path -notlike "*$windowsAppsDir*")) {
                $env:Path = "$windowsAppsDir;$env:Path"
            }
            $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
            if (-not $cmd) {
                $cmd = Get-Command winget -ErrorAction SilentlyContinue
            }
            if ($cmd) {
                return $cmd
            }
        }
    }

    throw @"
WinGet (winget.exe) is required but not found.
WinGet is delivered through Windows App Installer and may require first-login registration.
Official references:
- Microsoft Store App Installer: https://apps.microsoft.com/detail/9nblggh4nns1 or https://aka.ms/getwinget
- Microsoft Learn WinGet documentation: https://learn.microsoft.com/windows/package-manager/winget/
If App Installer is already installed, try running:
  Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
"@
}

function Get-WezTermCommand {
    $knownDirs = @(
        (Join-Path $env:ProgramFiles "WezTerm"),
        (Join-Path $env:LOCALAPPDATA "Programs\WezTerm")
    )
    if (Test-Path "Env:ProgramFiles(x86)") {
        $progFilesX86 = ${env:ProgramFiles(x86)}
        if ($progFilesX86) {
            $knownDirs += (Join-Path $progFilesX86 "WezTerm")
        }
    }

    foreach ($dir in $knownDirs) {
        if ($dir -and (Test-Path -LiteralPath $dir)) {
            if ($env:Path -notlike "*$dir*") {
                $env:Path = "$dir;$env:Path"
            }
        }
    }

    $cmd = Get-Command wezterm.exe -ErrorAction SilentlyContinue
    if (-not $cmd) {
        $cmd = Get-Command wezterm -ErrorAction SilentlyContinue
    }
    if (-not $cmd) {
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $combined = "$userPath;$machinePath"
        foreach ($p in ($combined -split ';')) {
            if ($p -and (Test-Path -LiteralPath $p)) {
                $candidate = Join-Path $p "wezterm.exe"
                if (Test-Path -LiteralPath $candidate) {
                    $env:Path = "$p;$env:Path"
                    $cmd = Get-Command wezterm.exe -ErrorAction SilentlyContinue
                    if ($cmd) { break }
                }
            }
        }
    }
    return $cmd
}

function Install-WezTerm {
    $winget = Ensure-WinGet -AllowRegister
    $wingetArgs = @(
        "install",
        "--exact",
        "--id", $WezTermPackageId,
        "--source", "winget",
        "--accept-source-agreements",
        "--accept-package-agreements"
    )
    & $winget.Source @wingetArgs
    if ($LASTEXITCODE -ne 0) {
        throw "WinGet failed to install WezTerm ($WezTermPackageId) with exit code $LASTEXITCODE."
    }

    $null = Get-WezTermCommand
}

function Install-WezTermConfig {
    if (-not (Test-Path -LiteralPath $WezTermConfigSource)) {
        throw "Tracked WezTerm config is missing: $WezTermConfigSource"
    }

    $targetParent = Split-Path -Parent -Path $WezTermConfigTarget
    if (-not (Test-Path -LiteralPath $targetParent)) {
        New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
    }

    if (Test-Path -LiteralPath $WezTermConfigTarget) {
        $sourceHash = (Get-FileHash -LiteralPath $WezTermConfigSource -Algorithm SHA256).Hash
        $targetHash = (Get-FileHash -LiteralPath $WezTermConfigTarget -Algorithm SHA256).Hash
        if ($sourceHash -ne $targetHash) {
            $backup = "$WezTermConfigTarget.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item -LiteralPath $WezTermConfigTarget -Destination $backup -Force
            Write-Host "Backed up existing WezTerm config to $backup"
        }
    }

    Copy-Item -LiteralPath $WezTermConfigSource -Destination $WezTermConfigTarget -Force
    Write-Host "Configured WezTerm from $WezTermConfigSource"
}

function Install-HackNerdFont {
    $archive = Join-Path ([System.IO.Path]::GetTempPath()) ("Hack-Nerd-Font-" + [System.Guid]::NewGuid().ToString("N") + ".zip")
    $extractDir = Join-Path ([System.IO.Path]::GetTempPath()) ("Hack-Nerd-Font-" + [System.Guid]::NewGuid().ToString("N"))
    try {
        Invoke-WebRequest -Uri $HackNerdFontUrl -OutFile $archive
        $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $HackNerdFontSha256) {
            throw "Hack Nerd Font checksum mismatch. Expected $HackNerdFontSha256, got $actualHash"
        }

        Expand-Archive -LiteralPath $archive -DestinationPath $extractDir -Force
        $fontFiles = @(Get-ChildItem -LiteralPath $extractDir -Recurse -File | Where-Object { $_.Extension -ieq ".ttf" })
        if ($fontFiles.Count -eq 0) {
            throw "Hack Nerd Font archive contained no TTF files."
        }

        New-Item -ItemType Directory -Path $HackNerdFontInstallDir -Force | Out-Null
        New-Item -Path $HackNerdFontRegistryPath -Force | Out-Null
        foreach ($fontFile in $fontFiles) {
            $destination = Join-Path $HackNerdFontInstallDir $fontFile.Name
            Copy-Item -LiteralPath $fontFile.FullName -Destination $destination -Force
            New-ItemProperty -Path $HackNerdFontRegistryPath -Name "$($fontFile.BaseName) (TrueType)" -PropertyType String -Value $destination -Force | Out-Null
        }
        Write-Host "Installed Hack Nerd Font $HackNerdFontVersion for the current Windows user ($($fontFiles.Count) TTF files)."
    }
    finally {
        Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-Herdr {
    try {
        Invoke-WebRequest -Uri $HerdrInstallerUrl -OutFile $HerdrInstaller
        $actualHash = (Get-FileHash -LiteralPath $HerdrInstaller -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $HerdrInstallerSha256) {
            throw "Herdr installer checksum mismatch. Expected $HerdrInstallerSha256, got $actualHash"
        }
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HerdrInstaller -Channel stable -InstallDir $HerdrInstallDir
        if ($LASTEXITCODE -ne 0) {
            throw "Herdr installer failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Remove-Item -LiteralPath $HerdrInstaller -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path -LiteralPath $HerdrInstallDir) {
        $env:Path = "$HerdrInstallDir;$env:Path"
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

function Set-HerdrPowerShellAlias {
    param(
        [Parameter(Mandatory)][string]$WslUser
    )

    $sshParent = Split-Path -Parent -Path $HerdrSshConfig
    if ($sshParent -and -not (Test-Path -LiteralPath $sshParent)) {
        New-Item -ItemType Directory -Path $sshParent -Force | Out-Null
    }

    $sshConfigStartMarker = "# >>> herdr WSL SSH config >>>"
    $sshConfigEndMarker = "# <<< herdr WSL SSH config <<<"
    $keyPath = $Key.Replace("\", "/")
    $knownHostsPath = $HerdrSshKnownHosts.Replace("\", "/")
    $sshConfigBlock = @(
        $sshConfigStartMarker
        "Host wsl-herdr"
        "    HostName 127.0.0.1"
        "    Port 2222"
        "    User $WslUser"
        "    IdentityFile $keyPath"
        "    IdentitiesOnly yes"
        "    StrictHostKeyChecking accept-new"
        "    UserKnownHostsFile $knownHostsPath"
        $sshConfigEndMarker
    ) -join [Environment]::NewLine
    $sshConfig = if (Test-Path -LiteralPath $HerdrSshConfig) {
        [System.IO.File]::ReadAllText($HerdrSshConfig)
    }
    else {
        ""
    }
    $sshConfigPattern = "(?ms)^" + [regex]::Escape($sshConfigStartMarker) + ".*?^" + [regex]::Escape($sshConfigEndMarker) + "\r?\n?"
    if ([regex]::IsMatch($sshConfig, $sshConfigPattern)) {
        $updatedSshConfig = [regex]::Replace($sshConfig, $sshConfigPattern, "$sshConfigBlock`r`n")
    }
    else {
        $separator = if ($sshConfig.Length -gt 0 -and -not $sshConfig.EndsWith("`n")) { "`r`n" } else { "" }
        $updatedSshConfig = $sshConfig + $separator + $sshConfigBlock + "`r`n"
    }
    [System.IO.File]::WriteAllText($HerdrSshConfig, $updatedSshConfig, [System.Text.UTF8Encoding]::new($false))

    $remoteBinParent = Split-Path -Parent -Path $HerdrShimFile
    if ($remoteBinParent -and -not (Test-Path -LiteralPath $remoteBinParent)) {
        New-Item -ItemType Directory -Path $remoteBinParent -Force | Out-Null
    }

    $shimContent = '@"%~dp0..\bin\herdr.exe" --remote wsl-herdr %*' + "`r`n"
    [System.IO.File]::WriteAllText($HerdrShimFile, $shimContent, [System.Text.UTF8Encoding]::new($false))

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $pathEntries = if ($userPath) { @($userPath -split ';' | Where-Object { [string]::IsNullOrWhiteSpace($_) -eq $false }) } else { @() }
    $remoteBinNormalized = $HerdrRemoteBinDir.TrimEnd('\')
    $alreadyInUserPath = $false
    foreach ($entry in $pathEntries) {
        if ($entry.Trim().TrimEnd('\') -ieq $remoteBinNormalized) {
            $alreadyInUserPath = $true
            break
        }
    }
    if (-not $alreadyInUserPath) {
        $newUserEntries = @($HerdrRemoteBinDir) + $pathEntries
        $newUserPath = $newUserEntries -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    }

    if ($env:Path -notlike "*$HerdrRemoteBinDir*") {
        $env:Path = "$HerdrRemoteBinDir;$env:Path"
    }

    $profilePath = [string]$PROFILE
    $profileParent = Split-Path -Parent -Path $profilePath
    if ($profileParent -and -not (Test-Path -LiteralPath $profileParent)) {
        New-Item -ItemType Directory -Path $profileParent -Force | Out-Null
    }

    $startMarker = "# >>> herdr WSL remote alias >>>"
    $endMarker = "# <<< herdr WSL remote alias <<<"
    $block = @(
        $startMarker
        "function herdr {"
        '    $herdrExe = Get-Command herdr.exe -CommandType Application -ErrorAction Stop'
        "    & `$herdrExe.Source --remote wsl-herdr @args"
        "}"
        $endMarker
    ) -join [Environment]::NewLine

    $existing = if (Test-Path -LiteralPath $profilePath) {
        [System.IO.File]::ReadAllText($profilePath)
    }
    else {
        ""
    }
    $pattern = "(?ms)^" + [regex]::Escape($startMarker) + ".*?^" + [regex]::Escape($endMarker) + "\r?\n?"
    if ([regex]::IsMatch($existing, $pattern)) {
        $updated = [regex]::Replace($existing, $pattern, "$block`r`n")
    }
    else {
        $separator = if ($existing.Length -gt 0 -and -not $existing.EndsWith("`n")) { "`r`n" } else { "" }
        $updated = $existing + $separator + $block + "`r`n"
    }
    [System.IO.File]::WriteAllText($profilePath, $updated, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Configured Herdr SSH target wsl-herdr in $HerdrSshConfig"
    Write-Host "Configured Herdr command shim in $HerdrShimFile and added to User PATH"
    Write-Host "Configured PowerShell Herdr alias in $profilePath. Open a new PowerShell or WezTerm window to use it."
}

Assert-Command "wsl.exe"
Assert-Command "ssh.exe"
Assert-Command "ssh-keygen.exe"
Assert-Command "powershell.exe"

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

$WslUser = ((& wsl.exe -d $Distro -- id -un) -replace "`0", "").Trim()
if (-not $WslUser -or $WslUser -notmatch '^[A-Za-z0-9_.-]+$') {
    throw "Could not determine a safe Ubuntu username."
}
$Target = "{0}@127.0.0.1" -f $WslUser

if (-not (Test-Path -LiteralPath $Key)) {
    throw "Dedicated WSL client key is missing: $Key. Run scripts/windows-herdr-key-bootstrap.ps1 and scripts/ubuntu-authorize-windows-key.sh first."
}

if ($Apply) {
    Set-IniValue -Path $WslConfig -Section "wsl2" -Key "memory" -Value "8GB"
    Set-IniValue -Path $WslConfig -Section "wsl2" -Key "processors" -Value "6"
    Set-IniValue -Path $WslConfig -Section "wsl2" -Key "swap" -Value "4GB"
    Set-IniValue -Path $WslConfig -Section "wsl2" -Key "localhostForwarding" -Value "true"

    if ($InstallHerdr) {
        Install-Herdr
    }

    if ($InstallWezTerm) {
        Install-WezTerm
    }

    if ($ConfigureHerdrAlias) {
        Set-HerdrPowerShellAlias -WslUser $WslUser
    }

    if ($ConfigureWezTerm) {
        Install-WezTermConfig
    }

    if ($InstallHackNerdFont) {
        Install-HackNerdFont
    }

    Write-Host "Applied Windows-side configuration. Run 'wsl.exe --shutdown' once if .wslconfig changed, restart Ubuntu, and run this script with -VerifyOnly."
}

if (Test-Path -LiteralPath $HerdrRemoteBinDir) {
    if ($env:Path -notlike "*$HerdrRemoteBinDir*") {
        $env:Path = "$HerdrRemoteBinDir;$env:Path"
    }
}
if (Test-Path -LiteralPath $HerdrInstallDir) {
    if ($env:Path -notlike "*$HerdrInstallDir*") {
        $env:Path = "$HerdrInstallDir;$env:Path"
    }
}
$HerdrCommand = Get-Command herdr.exe -CommandType Application -ErrorAction SilentlyContinue
if ($null -eq $HerdrCommand) {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $combined = "$userPath;$machinePath"
    foreach ($p in ($combined -split ';')) {
        if ($p -and (Test-Path -LiteralPath $p)) {
            $candidate = Join-Path $p "herdr.exe"
            if (Test-Path -LiteralPath $candidate) {
                $env:Path = "$p;$env:Path"
                $HerdrCommand = Get-Command herdr.exe -CommandType Application -ErrorAction SilentlyContinue
                if ($HerdrCommand) { break }
            }
        }
    }
}
if ($null -eq $HerdrCommand) {
    throw "Herdr is not installed. Run this script with -Apply -InstallHerdr first."
}
$HerdrDetectedVersion = (& $HerdrCommand.Source --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($HerdrDetectedVersion)) {
    throw "Installed Herdr command failed verification: herdr.exe --version"
}
if ($HerdrDetectedVersion -notmatch [regex]::Escape($HerdrVersion)) {
    throw "Expected Herdr $HerdrVersion, got: $HerdrDetectedVersion"
}

$WinGetCommand = Ensure-WinGet
$WinGetDetectedVersion = (& $WinGetCommand.Source --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($WinGetDetectedVersion)) {
    throw "WinGet verification failed: winget --version"
}

$WezTermCommand = Get-WezTermCommand
if ($null -eq $WezTermCommand) {
    $wingetList = & $WinGetCommand.Source list --exact --id $WezTermPackageId --source winget | Out-String
    if ($LASTEXITCODE -eq 0 -and $wingetList -match [regex]::Escape($WezTermPackageId)) {
        throw "WezTerm package '$WezTermPackageId' is installed via WinGet but 'wezterm.exe' was not found on PATH. A shell restart or PATH refresh may be required."
    }
    throw "WezTerm is not installed. Run this script with -Apply -InstallWezTerm first."
}
$WezTermDetectedVersion = (& $WezTermCommand.Source --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($WezTermDetectedVersion)) {
    throw "Installed WezTerm command failed verification: wezterm --version"
}

$PortTest = Test-NetConnection -ComputerName 127.0.0.1 -Port 2222 -WarningAction SilentlyContinue
if (-not $PortTest.TcpTestSucceeded) {
    throw "Ubuntu sshd is not reachable at 127.0.0.1:2222. Run scripts/ubuntu-bootstrap.sh inside Ubuntu first."
}

$KnownHosts = Join-Path $env:TEMP "orca-wsl-known-hosts"
$SshArgs = @(
    "-o", "BatchMode=yes",
    "-o", "IdentitiesOnly=yes",
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "UserKnownHostsFile=$KnownHosts",
    "-i", $Key,
    "-p", "2222",
    $Target,
    'set -eu; test "$(uname -s)" = Linux; case "$PWD" in /home/*) ;; *) exit 1;; esac; command -v git make g++ python3 >/dev/null; git --version; make --version | sed -n "1p"; g++ --version | sed -n "1p"; python3 --version'
)
& ssh.exe @SshArgs
if ($LASTEXITCODE -ne 0) {
    throw "Loopback SSH or Herdr node-pty prerequisites failed verification."
}

Write-Host "Verified WSL distro: $Distro"
Write-Host "Verified SSH target: $Target on 127.0.0.1:2222"
Write-Host "Verified dedicated key: $Key"
Write-Host "Verified Herdr client: $HerdrDetectedVersion"
Write-Host "Verified WinGet: $WinGetDetectedVersion"
Write-Host "Verified WezTerm: $WezTermDetectedVersion"
