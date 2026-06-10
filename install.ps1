#Requires -Version 7.0
<#
.SYNOPSIS
  One-command installer for gstack-on-Copilot-CLI (Windows). Requires PowerShell 7.0+.

.DESCRIPTION
  Installs gstack (Garry Tan's engineering workflow skills) as a
  GitHub Copilot CLI plugin.

  On Windows PowerShell 5.1 (the default `powershell.exe`), this script will
  refuse to run with a clear error. Use `pwsh` (PowerShell 7+) instead.

  Steps performed:
    1. Preflight (git, copilot, node)
    2. Install Bun if missing (latest from bun.sh — see -BunVersion to pin)
    3. Clone or update gstack upstream at ~/.claude/skills/gstack
    4. bun install + bun run build (via Git Bash on Windows)
    5. Copy runtime root to ~/.copilot/skills/gstack (bin/, browse, design, hooks)
    6. Install Playwright Chromium (Node.js launcher used on Windows)
    7. Clone the Copilot plugin shim (this repo) to ~/.gstack-copilot
    8. Register the plugin with Copilot CLI (skipped with -RuntimeOnly)
    9. Verify

  Step ordering: runtime root copy (step 5) is intentionally BEFORE Playwright
  (step 6) so a Playwright failure doesn't strand the runtime install.

.PARAMETER RuntimeOnly
  Skip the Copilot plugin register/update step. Useful when the plugin was
  already installed via the marketplace path:
    copilot plugin marketplace add aviraldua93/gstack-copilot
    copilot plugin install gstack@gstack-copilot
  Then run this script with -RuntimeOnly to add the runtime binaries.

.PARAMETER SkipPluginRegister
  Alias for -RuntimeOnly with a clearer name.

.PARAMETER UpstreamRepo
  Git URL of upstream gstack. Default: https://github.com/garrytan/gstack.git

.PARAMETER UpstreamRef
  Branch/tag/sha of upstream gstack to check out. Default: main

.PARAMETER PluginRepo
  Git URL of the Copilot CLI plugin shim. Default:
  https://github.com/aviraldua93/gstack-copilot.git

.PARAMETER PluginRef
  Branch/tag/sha of the plugin shim to check out. Default: main

.PARAMETER LocalPlugin
  Use a local plugin directory instead of cloning. When run from a checkout of
  this repo (cwd contains plugin/plugin.json), auto-detected.

.PARAMETER InstallDir
  Where to install upstream gstack. Default: ~/.claude/skills/gstack
  Do not change this unless you know what you are doing — SKILL.md preambles
  hardcode this path.

.PARAMETER PluginDir
  Where to clone the plugin shim. Default: ~/.gstack-copilot

.PARAMETER SkipUpstream
  Skip the upstream clone/build (useful if you only want to refresh the plugin
  registration).

.PARAMETER SkipPlaywright
  Skip the Playwright Chromium install (useful if you've already done it).

.PARAMETER SkipBun
  Skip the Bun install check (assume it's already on PATH).

.PARAMETER NoVerify
  Skip the post-install verification.

.PARAMETER Force
  Wipe the existing install dir before cloning. Destructive — your local
  edits to ~/.claude/skills/gstack will be lost.

.EXAMPLE
  iwr -useb https://aviraldua93.github.io/gstack-copilot/install.ps1 | iex

.EXAMPLE
  .\install.ps1 -LocalPlugin

.EXAMPLE
  .\install.ps1 -UpstreamRef v1.50.0.0 -Force
#>
[CmdletBinding()]
param(
  [string]$UpstreamRepo = 'https://github.com/garrytan/gstack.git',
  [string]$UpstreamRef = 'main',
  [string]$PluginRepo = 'https://github.com/aviraldua93/gstack-copilot.git',
  [string]$PluginRef = 'main',
  [switch]$LocalPlugin,
  [string]$InstallDir = (Join-Path $HOME '.claude\skills\gstack'),
  [string]$PluginDir = (Join-Path $HOME '.gstack-copilot'),
  [switch]$SkipUpstream,
  [switch]$SkipPlaywright,
  [switch]$SkipBun,
  [switch]$NoVerify,
  [switch]$Force,
  [switch]$RuntimeOnly,
  [switch]$SkipPluginRegister,
  [string]$BunVersion = ''  # empty = install latest; set to e.g. '1.3.10' to pin
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # speeds up Invoke-WebRequest

# Treat both flags identically.
$SkipPluginRegister = $SkipPluginRegister -or $RuntimeOnly

# --- Output helpers ----------------------------------------------------------
function Write-Step  { param($Msg) Write-Host "==> $Msg" -ForegroundColor Cyan }
function Write-Ok    { param($Msg) Write-Host "    $Msg" -ForegroundColor Green }
function Write-Warn2 { param($Msg) Write-Host "    $Msg" -ForegroundColor Yellow }
function Write-Bad   { param($Msg) Write-Host "    $Msg" -ForegroundColor Red }
function Die         { param($Msg) Write-Host "ERROR: $Msg" -ForegroundColor Red; exit 1 }

function Test-Command {
  param([string]$Name)
  $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

# Invoke an external command and capture combined stdout/stderr without letting
# stderr writes turn into terminating errors under $ErrorActionPreference=Stop.
# Returns @{ ExitCode = int; Output = string }.
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

# Locate Git Bash — Windows bash on PATH is the WSL stub if WSL isn't installed.
function Get-GitBash {
  $candidates = @(
    'C:\Program Files\Git\bin\bash.exe',
    'C:\Program Files (x86)\Git\bin\bash.exe'
  )
  foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
  $gitCmd = Get-Command git -ErrorAction SilentlyContinue
  if ($gitCmd) {
    $bash = Join-Path (Split-Path (Split-Path $gitCmd.Source -Parent) -Parent) 'bin\bash.exe'
    if (Test-Path $bash) { return $bash }
  }
  Die "Git Bash not found. Install Git for Windows: https://git-scm.com/download/win"
}

# Invoke a bash command using Git Bash, with CWD set, stream output, fail on non-zero.
function Invoke-Bash {
  param(
    [Parameter(Mandatory)][string]$Command,
    [string]$Cwd = (Get-Location).Path
  )
  $bash = Get-GitBash
  # Convert Windows path to MSYS-style for cd (PS 5.1 compatible — no scriptblock-replace)
  $msysCwd = $Cwd -replace '\\', '/'
  if ($msysCwd -match '^([A-Za-z]):(.*)$') {
    $msysCwd = '/' + $Matches[1].ToLower() + $Matches[2]
  }
  $script = "set -e; cd `"$msysCwd`"; $Command"
  & $bash -lc $script
  if ($LASTEXITCODE -ne 0) { Die "bash command failed (exit $LASTEXITCODE): $Command" }
}

# --- Preflight ---------------------------------------------------------------
Write-Step "gstack-on-Copilot-CLI installer (Windows)"
Write-Host ""

# --- Preflight ---------------------------------------------------------------
Write-Step "gstack-on-Copilot-CLI installer (Windows)"
Write-Host ""

# Fix #1: COPILOT_CLI check moved DOWN to the plugin-register block.
# Runtime work (Bun, clone, build, Playwright, runtime root copy) does NOT
# touch ~/.copilot/settings.json, so it should not be blocked by the session
# lock guard. Only the actual plugin install/uninstall steps need the guard.

Write-Step "Preflight"
if (-not (Test-Command git))     { Die "git not found. Install Git for Windows: https://git-scm.com/download/win" }
if (-not (Test-Command copilot)) { Die "GitHub Copilot CLI not found. Install: https://docs.github.com/copilot/how-tos/copilot-cli" }
if (-not (Test-Command node))    { Die "Node.js not found. Required on Windows for Playwright. Install: https://nodejs.org/" }
Write-Ok ("git      : " + (git --version))
Write-Ok ("copilot  : " + ((copilot --version) -split "`r?`n")[0])
Write-Ok ("node     : " + (node --version))
$gitBash = Get-GitBash
Write-Ok ("git-bash : " + $gitBash)
if ($env:COPILOT_CLI -eq '1') {
  Write-Warn2 "Detected COPILOT_CLI=1. Runtime install will run; plugin register will be skipped (Copilot session holds settings.json lock)."
  $SkipPluginRegister = $true
}

# --- Bun ---------------------------------------------------------------------
if (-not $SkipBun) {
  $bunLabel = if ($BunVersion) { "v$BunVersion" } else { "latest" }
  Write-Step "Bun ($bunLabel)"
  if (Test-Command bun) {
    $bunVer = (bun --version).Trim()
    Write-Ok "bun $bunVer already on PATH"
  } else {
    Write-Warn2 "bun not found — installing via official PowerShell installer"
    # Bun's official Windows install: https://bun.sh/install.ps1
    # We pin the version via env var BUN_VERSION so we don't pick up surprises.
    $env:BUN_VERSION = $BunPinnedVersion
    try {
      Invoke-Expression (Invoke-WebRequest -UseBasicParsing -Uri 'https://bun.sh/install.ps1').Content
    } catch {
      Die "Bun install failed: $($_.Exception.Message)"
    }
    # Bun installs to ~/.bun/bin
    $bunBin = Join-Path $HOME '.bun\bin'
    if (Test-Path (Join-Path $bunBin 'bun.exe')) {
      $env:PATH = "$bunBin;$env:PATH"
      Write-Ok "bun installed at $bunBin (added to PATH for this session)"
      Write-Warn2 "Add '$bunBin' to your User PATH to make this permanent."
    } else {
      Die "Bun install reported success but bun.exe not found at $bunBin"
    }
  }
} else {
  Write-Step "Skipping Bun (--SkipBun)"
}

# --- Upstream gstack ---------------------------------------------------------
if (-not $SkipUpstream) {
  Write-Step "Upstream gstack -> $InstallDir"

  $parent = Split-Path $InstallDir -Parent
  if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

  if ($Force -and (Test-Path $InstallDir)) {
    Write-Warn2 "--Force: removing existing $InstallDir"
    Remove-Item -Recurse -Force $InstallDir
  }

  if (Test-Path (Join-Path $InstallDir '.git')) {
    Write-Ok "Existing clone detected — fetching + checking out $UpstreamRef"
    Invoke-Bash -Cwd $InstallDir -Command "git fetch --tags origin && git checkout `"$UpstreamRef`" && git pull --ff-only origin `"$UpstreamRef`" || true"
  } else {
    if (Test-Path $InstallDir) {
      Die "$InstallDir exists but is not a git checkout. Move it aside or re-run with -Force."
    }
    Write-Ok "Cloning $UpstreamRepo (ref: $UpstreamRef)"
    Invoke-Bash -Cwd $parent -Command "git clone --branch `"$UpstreamRef`" `"$UpstreamRepo`" `"$InstallDir`""
  }

  Write-Step "bun install + bun run build (this can take 1-3 minutes)"
  Invoke-Bash -Cwd $InstallDir -Command "bun install --no-progress"
  Invoke-Bash -Cwd $InstallDir -Command "bun run build"
  Write-Ok "Build complete"

  # --- Copilot runtime root ----------------------------------------------------
  # (Fix #6 reorder: runtime root copy is BEFORE Playwright now.)
  # Skills generated by gstack's hosts/copilot.ts adapter reference paths under
  # ~/.copilot/skills/gstack/ (e.g. for bin/, browse/dist/, browse/src/, design/).
  # Copy the runtime assets from the upstream install so preambles + binaries resolve.
  # browse/src/ is required because the compiled browse.exe loads server.ts relative
  # to its location (../src/server.ts) — pure-dist install fails at runtime.
  Write-Step "Copilot runtime root (~/.copilot/skills/gstack/)"
  $copilotGstack = Join-Path $env:USERPROFILE '.copilot\skills\gstack'
  $copilotRuntimeCmd = @"
set -e
SRC="$($InstallDir -replace '\\','/')"
DST="$HOME/.copilot/skills/gstack"
mkdir -p "`$DST"
for sub in bin browse/dist browse/src design/dist design/src make-pdf/dist make-pdf/src ETHOS.md careful/bin freeze/bin; do
  if [ -e "`$SRC/`$sub" ]; then
    target="`$DST/`$sub"
    mkdir -p "`$(dirname `$target)"
    rm -rf "`$target"
    cp -R "`$SRC/`$sub" "`$target"
  fi
done
# Skill-specific reference files referenced by review/qa/plan-devex-review skills
mkdir -p "`$DST/review" "`$DST/qa" "`$DST/plan-devex-review"
for f in checklist.md design-checklist.md greptile-triage.md TODOS-format.md; do
  [ -f "`$SRC/review/`$f" ] && cp "`$SRC/review/`$f" "`$DST/review/`$f"
done
[ -d "`$SRC/review/specialists" ] && cp -R "`$SRC/review/specialists" "`$DST/review/specialists"
[ -d "`$SRC/qa/templates" ] && cp -R "`$SRC/qa/templates" "`$DST/qa/templates"
[ -d "`$SRC/qa/references" ] && cp -R "`$SRC/qa/references" "`$DST/qa/references"
[ -f "`$SRC/plan-devex-review/dx-hall-of-fame.md" ] && cp "`$SRC/plan-devex-review/dx-hall-of-fame.md" "`$DST/plan-devex-review/dx-hall-of-fame.md"
echo "OK: runtime root populated at `$DST"
"@
  Invoke-Bash -Cwd $InstallDir -Command $copilotRuntimeCmd
  Write-Ok "Copilot runtime root ready at $copilotGstack"

  # --- Playwright Chromium ---------------------------------------------------
  # (Fix #6: wrapped in try/catch so a Playwright failure DOES NOT strand the
  # runtime install. Runtime root is already populated above; browser skills
  # will just be unavailable until the user resolves Playwright.)
  if (-not $SkipPlaywright) {
    Write-Step "Playwright Chromium"
    try {
      Invoke-Bash -Cwd $InstallDir -Command "bunx playwright install chromium"

      # On Windows, Bun cannot launch Chromium due to oven-sh/bun#4253.
      # Node has to be able to require('playwright') from the install dir.
      # Use `npm.cmd` (not bare `npm`) so Git Bash on Windows finds the shim
      # without depending on PATHEXT resolution. See:
      # https://github.com/aviraldua93/gstack-copilot/issues/6
      Write-Ok "Verifying Node.js can load Playwright (Windows-specific)"
      Invoke-Bash -Cwd $InstallDir -Command "node -e `"require('playwright')`" 2>/dev/null || npm.cmd install --no-save playwright"
      Invoke-Bash -Cwd $InstallDir -Command "node -e `"require('@ngrok/ngrok')`" 2>/dev/null || npm.cmd install --no-save @ngrok/ngrok || true"
      Write-Ok "Playwright Chromium ready"
    } catch {
      Write-Bad "Playwright install failed: $($_.Exception.Message)"
      Write-Warn2 "Runtime root is already populated. Non-browser skills work."
      Write-Warn2 "To enable browser skills (qa, browse, canary, scrape):"
      Write-Warn2 "  cd $InstallDir; bunx playwright install chromium; npm.cmd install --no-save playwright"
    }
  } else {
    Write-Step "Skipping Playwright (--SkipPlaywright)"
  }
} else {
  Write-Step "Skipping upstream install (--SkipUpstream)"
}

# --- Copilot CLI plugin ------------------------------------------------------
# Fix #2: -RuntimeOnly / -SkipPluginRegister skip this block entirely.
# Fix #1: COPILOT_CLI auto-sets $SkipPluginRegister in preflight, so this
# also auto-skips when running inside an active Copilot session.
if ($SkipPluginRegister) {
  Write-Step "Copilot CLI plugin (gstack) — SKIPPED"
  Write-Ok "Skipping plugin register/update (-RuntimeOnly or -SkipPluginRegister or active Copilot session)."
  Write-Ok "If the plugin isn't already installed, run from a fresh terminal:"
  Write-Ok "  copilot plugin marketplace add aviraldua93/gstack-copilot"
  Write-Ok "  copilot plugin install gstack@gstack-copilot"
  Write-Host ""
  Write-Step "Done."
  Write-Ok "Runtime root ready. Plugin register skipped."
  exit 0
}

Write-Step "Copilot CLI plugin (gstack)"

# Decide plugin source: local checkout, explicit dir, or clone the shim repo.
$pluginSource = $null

if ($LocalPlugin) {
  $localCandidate = Join-Path (Get-Location).Path 'plugin'
  if (Test-Path (Join-Path $localCandidate 'plugin.json')) {
    $pluginSource = (Resolve-Path $localCandidate).Path
    Write-Ok "Using local plugin: $pluginSource"
  } else {
    Die "-LocalPlugin set but '$localCandidate\plugin.json' not found. Run from a checkout of gstack-copilot."
  }
} elseif (Test-Path (Join-Path (Get-Location).Path 'plugin\plugin.json')) {
  $pluginSource = (Resolve-Path (Join-Path (Get-Location).Path 'plugin')).Path
  Write-Ok "Detected local plugin checkout: $pluginSource"
} else {
  # Clone the plugin shim repo
  $parent = Split-Path $PluginDir -Parent
  if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

  if (Test-Path (Join-Path $PluginDir '.git')) {
    Write-Ok "Existing plugin clone detected — fetching + checking out $PluginRef"
    Invoke-Bash -Cwd $PluginDir -Command "git fetch --tags origin && git checkout `"$PluginRef`" && git pull --ff-only origin `"$PluginRef`" || true"
  } else {
    if (Test-Path $PluginDir) { Remove-Item -Recurse -Force $PluginDir }
    Write-Ok "Cloning $PluginRepo (ref: $PluginRef) -> $PluginDir"
    Invoke-Bash -Cwd $parent -Command "git clone --branch `"$PluginRef`" `"$PluginRepo`" `"$PluginDir`""
  }
  $pluginSource = Join-Path $PluginDir 'plugin'
  if (-not (Test-Path (Join-Path $pluginSource 'plugin.json'))) {
    Die "Plugin checkout missing $pluginSource\plugin.json"
  }
}

# If already registered, prefer 'plugin update' (idempotent, no destructive
# uninstall mid-flight). Fall back to uninstall + install only if update fails.
$listRes = Invoke-Capture -File 'copilot' -Args @('plugin','list')
$alreadyInstalled = ($listRes.ExitCode -eq 0 -and $listRes.Output -match '\bgstack\b')

function Assert-NotLocked {
  param([string]$Output, [string]$Verb)
  if ($Output -match 'EPERM|operation not permitted') {
    Die "Settings.json is locked by an active Copilot session. Exit all copilot sessions and rerun this installer. (during $Verb)"
  }
}

if ($alreadyInstalled) {
  Write-Ok "gstack plugin already registered — updating in place"
  $upd = Invoke-Capture -File 'copilot' -Args @('plugin','update','gstack')
  if ($upd.ExitCode -ne 0) {
    Assert-NotLocked $upd.Output 'plugin update'
    Write-Warn2 "plugin update returned $($upd.ExitCode) — falling back to uninstall + install"
    $un = Invoke-Capture -File 'copilot' -Args @('plugin','uninstall','gstack')
    if ($un.ExitCode -ne 0) {
      Assert-NotLocked $un.Output 'plugin uninstall'
      Die "copilot plugin uninstall failed:`n$($un.Output)"
    }
    Write-Ok "Registering plugin from $pluginSource"
    $ins = Invoke-Capture -File 'copilot' -Args @('plugin','install',$pluginSource)
    if ($ins.ExitCode -ne 0) {
      Assert-NotLocked $ins.Output 'plugin install'
      Die "copilot plugin install failed:`n$($ins.Output)"
    }
    if ($ins.Output) { $ins.Output -split "`r?`n" | ForEach-Object { Write-Host "      $_" } }
  } else {
    if ($upd.Output) { $upd.Output -split "`r?`n" | ForEach-Object { Write-Host "      $_" } }
  }
} else {
  Write-Ok "Registering plugin from $pluginSource"
  $ins = Invoke-Capture -File 'copilot' -Args @('plugin','install',$pluginSource)
  if ($ins.ExitCode -ne 0) {
    Assert-NotLocked $ins.Output 'plugin install'
    Die "copilot plugin install failed:`n$($ins.Output)"
  }
  if ($ins.Output) { $ins.Output -split "`r?`n" | ForEach-Object { Write-Host "      $_" } }
}

# --- Verify ------------------------------------------------------------------
if (-not $NoVerify) {
  Write-Step "Verifying"
  $listRes2 = Invoke-Capture -File 'copilot' -Args @('plugin','list')
  if ($listRes2.Output -match '\bgstack\b') {
    Write-Ok "Plugin registered:"
    $listRes2.Output -split "`r?`n" | Where-Object { $_ -match 'gstack' } | ForEach-Object { Write-Host "      $_" -ForegroundColor Green }
  } else {
    Die "Plugin not visible in 'copilot plugin list' — install may have silently failed."
  }

  # Check the upstream binary works
  $browseBin = Join-Path $InstallDir 'browse\dist\browse.exe'
  $findBrowseBin = Join-Path $InstallDir 'browse\dist\find-browse.exe'
  if (Test-Path $browseBin) {
    $sz = (Get-Item $browseBin).Length
    if ($sz -lt 1024) {
      Write-Warn2 "$browseBin is only $sz bytes (expected ~50-100 MB compiled binary)."
      Write-Warn2 "  This is an upstream gstack build bug on Windows — Bun's --compile produced a broken shebang wrapper."
      Write-Warn2 "  File issue at https://github.com/garrytan/gstack/issues if browser skills (qa, browse, scrape) fail."
    } else {
      Write-Ok "Found browse binary: $browseBin ($([math]::Round($sz/1MB,1)) MB)"
    }
  } else {
    Write-Warn2 "browse.exe not found at $browseBin — browser-dependent skills will not work."
  }
  if (Test-Path $findBrowseBin) {
    $sz2 = (Get-Item $findBrowseBin).Length
    Write-Ok "Found find-browse binary: $findBrowseBin ($([math]::Round($sz2/1MB,1)) MB)"
  }

  # Check a representative bin script
  $configBin = Join-Path $InstallDir 'bin\gstack-config'
  if (Test-Path $configBin) {
    Write-Ok "Found helper: $configBin"
  } else {
    Write-Warn2 "$configBin missing — SKILL.md preambles depend on these helpers."
  }
}

Write-Host ""
Write-Step "Done."
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Open a fresh terminal and start a Copilot session:"
Write-Host "       copilot" -ForegroundColor White
Write-Host "  2. Inside the session, list available skills:"
Write-Host "       /skills list" -ForegroundColor White
Write-Host "  3. Try one:"
Write-Host "       review this pr" -ForegroundColor White
Write-Host "       investigate this bug" -ForegroundColor White
Write-Host "       office hours" -ForegroundColor White
Write-Host ""
Write-Host "Upgrade later with: .\install.ps1 -Force" -ForegroundColor Cyan
Write-Host "Uninstall with:     .\uninstall.ps1" -ForegroundColor Cyan
