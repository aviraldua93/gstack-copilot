<#
.SYNOPSIS
  Uninstall gstack-on-Copilot-CLI (Windows).

.DESCRIPTION
  Reverses everything install.ps1 did:
    1. Unregister the Copilot CLI plugin
    2. Remove ~/.claude/skills/gstack (upstream)
    3. Remove ~/.gstack-copilot (plugin shim clone)
    4. Optionally remove ~/.bun (Bun runtime — keep by default; other tools use it)
    5. Optionally remove ~/.gstack and ~/.gstack-dev (user state — keep by default;
       contains your projects, decisions, learnings)

.PARAMETER KeepUpstream
  Don't remove ~/.claude/skills/gstack

.PARAMETER KeepPluginClone
  Don't remove ~/.gstack-copilot

.PARAMETER PurgeBun
  Also remove ~/.bun (Bun runtime). NOT default — other tools may use Bun.

.PARAMETER PurgeUserState
  Also remove ~/.gstack and ~/.gstack-dev (your projects, decisions,
  learnings, session history, model caches). NOT default — destructive.

.PARAMETER InstallDir
  Override the upstream install path. Default: ~/.claude/skills/gstack

.PARAMETER PluginDir
  Override the plugin shim path. Default: ~/.gstack-copilot

.PARAMETER Yes
  Skip the confirmation prompt.

.EXAMPLE
  .\uninstall.ps1

.EXAMPLE
  .\uninstall.ps1 -PurgeUserState -PurgeBun -Yes
#>
[CmdletBinding()]
param(
  [switch]$KeepUpstream,
  [switch]$KeepPluginClone,
  [switch]$PurgeBun,
  [switch]$PurgeUserState,
  [string]$InstallDir = (Join-Path $HOME '.claude\skills\gstack'),
  [string]$PluginDir = (Join-Path $HOME '.gstack-copilot'),
  [switch]$Yes
)

$ErrorActionPreference = 'Stop'

function Write-Step  { param($Msg) Write-Host "==> $Msg" -ForegroundColor Cyan }
function Write-Ok    { param($Msg) Write-Host "    $Msg" -ForegroundColor Green }
function Write-Warn2 { param($Msg) Write-Host "    $Msg" -ForegroundColor Yellow }
function Write-Bad   { param($Msg) Write-Host "    $Msg" -ForegroundColor Red }
function Die         { param($Msg) Write-Host "ERROR: $Msg" -ForegroundColor Red; exit 1 }

# See install.ps1 for context. Stop-mode + native stderr = false-positive
# terminating errors; this helper isolates the native call.
function Invoke-Capture {
  param(
    [Parameter(Mandatory)][string]$File,
    [string[]]$Args = @()
  )
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $out = & $File @Args 2>&1 | Out-String
    return @{ ExitCode = $LASTEXITCODE; Output = $out.Trim() }
  } finally {
    $ErrorActionPreference = $prev
  }
}

if ($env:COPILOT_CLI -eq '1') {
  Write-Bad "You are running this inside an active Copilot CLI session."
  Write-Bad "Copilot CLI holds an exclusive lock on ~/.copilot/settings.json,"
  Write-Bad "so 'copilot plugin uninstall' will fail with EPERM."
  Write-Host ""
  Write-Host "  Open a FRESH terminal and re-run from there." -ForegroundColor Yellow
  exit 2
}

Write-Step "gstack uninstaller (Windows)"
Write-Host ""
Write-Host "The following will be removed:" -ForegroundColor White
Write-Host "  - Copilot CLI plugin registration: gstack" -ForegroundColor White
if (-not $KeepUpstream)    { Write-Host "  - Upstream gstack:    $InstallDir" -ForegroundColor White }
if (-not $KeepPluginClone) { Write-Host "  - Plugin shim clone:  $PluginDir" -ForegroundColor White }
if ($PurgeBun)             { Write-Host "  - Bun runtime:        $HOME\.bun" -ForegroundColor Yellow }
if ($PurgeUserState) {
  Write-Host "  - User state (DESTRUCTIVE):" -ForegroundColor Red
  Write-Host "      $HOME\.gstack"      -ForegroundColor Red
  Write-Host "      $HOME\.gstack-dev"  -ForegroundColor Red
}
Write-Host ""

if (-not $Yes) {
  $resp = Read-Host "Proceed? [y/N]"
  if ($resp -notmatch '^[yY]') { Write-Host "Aborted."; exit 0 }
}

# --- Unregister plugin -------------------------------------------------------
Write-Step "Unregistering Copilot CLI plugin"
$listRes = Invoke-Capture -File 'copilot' -Args @('plugin','list')
if ($listRes.ExitCode -eq 0 -and $listRes.Output -match '\bgstack\b') {
  $un = Invoke-Capture -File 'copilot' -Args @('plugin','uninstall','gstack')
  if ($un.ExitCode -ne 0) {
    if ($un.Output -match 'EPERM|operation not permitted') {
      Die "Settings.json is locked by an active Copilot session. Exit all copilot sessions and rerun."
    }
    Write-Warn2 "copilot plugin uninstall returned $($un.ExitCode):"
    if ($un.Output) { $un.Output -split "`r?`n" | ForEach-Object { Write-Host "      $_" } }
    Write-Warn2 "Continuing."
  } else {
    Write-Ok "Plugin unregistered"
    if ($un.Output) { $un.Output -split "`r?`n" | ForEach-Object { Write-Host "      $_" } }
  }
} else {
  Write-Warn2 "Plugin 'gstack' not registered (skipping)"
}

# --- Remove upstream ---------------------------------------------------------
if (-not $KeepUpstream) {
  Write-Step "Removing upstream gstack"
  if (Test-Path $InstallDir) {
    Remove-Item -Recurse -Force $InstallDir
    Write-Ok "Removed $InstallDir"
  } else {
    Write-Warn2 "$InstallDir not present (skipping)"
  }
}

# --- Remove plugin clone -----------------------------------------------------
if (-not $KeepPluginClone) {
  Write-Step "Removing plugin shim clone"
  if (Test-Path $PluginDir) {
    Remove-Item -Recurse -Force $PluginDir
    Write-Ok "Removed $PluginDir"
  } else {
    Write-Warn2 "$PluginDir not present (skipping)"
  }
}

# --- Optional: Bun -----------------------------------------------------------
if ($PurgeBun) {
  Write-Step "Removing Bun runtime"
  $bunRoot = Join-Path $HOME '.bun'
  if (Test-Path $bunRoot) {
    Remove-Item -Recurse -Force $bunRoot
    Write-Ok "Removed $bunRoot"
  } else {
    Write-Warn2 "$bunRoot not present (skipping)"
  }
}

# --- Optional: user state ----------------------------------------------------
if ($PurgeUserState) {
  Write-Step "Removing user state (destructive)"
  foreach ($d in @((Join-Path $HOME '.gstack'), (Join-Path $HOME '.gstack-dev'))) {
    if (Test-Path $d) {
      Remove-Item -Recurse -Force $d
      Write-Ok "Removed $d"
    } else {
      Write-Warn2 "$d not present (skipping)"
    }
  }
}

Write-Host ""
Write-Step "Done."
Write-Host ""
Write-Host "Verification:" -ForegroundColor Cyan
Write-Host "  copilot plugin list   # should no longer show 'gstack'"
