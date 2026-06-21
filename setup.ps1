#Requires -Version 5.1
<#
.SYNOPSIS
  Install the shuk CLI on Windows (PowerShell).

.DESCRIPTION
  Creates a shuk.ps1 wrapper and a shuk.cmd shim in $HOME\.local\bin, then
  adds that directory to your Windows User PATH so `shuk` works from any
  PowerShell or CMD terminal without typing an extension.

  Requires Git Bash (Git for Windows) or WSL with bash available.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ShukRoot = $PSScriptRoot
$BinDir   = "$env:USERPROFILE\.local\bin"

function ok($msg)   { Write-Host "[ok] $msg" -ForegroundColor Green }
function info($msg) { Write-Host "[  ] $msg" }
function warn($msg) { Write-Host "[!!] $msg" -ForegroundColor Yellow }
function die($msg)  { Write-Host "[!!] $msg" -ForegroundColor Red; exit 1 }

# ── Find bash ─────────────────────────────────────────────────────────────────
$BashExe = $null
$WslRoot  = $null

foreach ($p in @(
    'C:\Program Files\Git\bin\bash.exe',
    'C:\Program Files (x86)\Git\bin\bash.exe',
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
)) {
    if (Test-Path $p) { $BashExe = $p; break }
}

if (-not $BashExe) {
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        $testOut = wsl echo ok 2>$null
        if ($LASTEXITCODE -eq 0 -and $testOut -eq 'ok') {
            $WslRoot = (wsl wslpath ($ShukRoot.Replace('\', '\\'))) 2>$null
            if (-not $WslRoot) { die "WSL found but path conversion failed. Run setup.sh inside WSL instead." }
        }
    }
}

if (-not $BashExe -and -not $WslRoot) {
    die "shuk requires Git Bash or WSL.`nInstall Git for Windows: https://git-scm.com  or enable WSL: https://aka.ms/wsl"
}

# ── Create bin dir ─────────────────────────────────────────────────────────────
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

# ── Write shuk.ps1 wrapper ────────────────────────────────────────────────────
# The wrapper hardcodes SHUK_ROOT so it works from any working directory.
$PsWrapper = "$BinDir\shuk.ps1"

if ($BashExe) {
    Set-Content -Path $PsWrapper -Encoding UTF8 -Value @"
`$env:SHUK_ROOT = '$ShukRoot'
& '$BashExe' '$ShukRoot\bin\shuk' @args
exit `$LASTEXITCODE
"@
} else {
    Set-Content -Path $PsWrapper -Encoding UTF8 -Value @"
wsl bash '$WslRoot/bin/shuk' @args
exit `$LASTEXITCODE
"@
}

# ── Write shuk.cmd shim ───────────────────────────────────────────────────────
# .cmd is in PATHEXT by default, so `shuk` (no extension) resolves automatically
# in both PowerShell and CMD.
$CmdShim = "$BinDir\shuk.cmd"
[System.IO.File]::WriteAllText($CmdShim,
    "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0shuk.ps1`" %*`r`n",
    [System.Text.Encoding]::ASCII)

# ── Add BinDir to Windows User PATH ──────────────────────────────────────────
$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($null -eq $userPath) { $userPath = '' }
if ($userPath -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable('PATH', "$userPath;$BinDir", 'User')
    ok "Added $BinDir to User PATH — restart your terminal to apply"
} else {
    ok "$BinDir already in User PATH"
}

ok "Installed shuk.ps1 -> $PsWrapper"
ok "Installed shuk.cmd -> $CmdShim"
if ($BashExe) { info "Using bash: $BashExe" }
else           { info "Using WSL bash (root: $WslRoot)" }
Write-Host ""
info "Next: shuk doctor"
