[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Assert-Command {
    param([Parameter(Mandatory)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

Assert-Command "ssh-keygen.exe"

$Key = Join-Path $env:USERPROFILE ".ssh\orca-wsl-ed25519"
$KeyDir = Split-Path -Parent $Key
$TempPub = Join-Path ([System.IO.Path]::GetTempPath()) "orca-wsl-manual.pub"

if (-not (Test-Path -LiteralPath $KeyDir)) {
    New-Item -ItemType Directory -LiteralPath $KeyDir -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $Key)) {
    & ssh-keygen.exe -t ed25519 -f $Key -C "orca-wsl" -N '""'
    if ($LASTEXITCODE -ne 0) {
        throw "ssh-keygen failed to generate key at $Key"
    }
}

$PublicKey = (& ssh-keygen.exe -y -f $Key | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($PublicKey)) {
    throw "Could not derive the dedicated WSL client public key from $Key"
}

$PublicKey = ($PublicKey -replace "`r", "" -replace "`n", "").Trim()

$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($TempPub, $PublicKey + "`n", $Utf8NoBom)

$Fingerprint = (& ssh-keygen.exe -lf $TempPub | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($Fingerprint)) {
    throw "Could not verify exported public key at $TempPub"
}

Write-Host "Prepared Windows client key: $Key"
Write-Host "Exported public key to: $TempPub"
Write-Host "Public key fingerprint: $Fingerprint"
