# gstack for GitHub Copilot CLI

Port of [garrytan/gstack](https://github.com/garrytan/gstack) — Garry Tan's "engineering workflow as skills" — to the **GitHub Copilot CLI** plugin format.

One command installs Bun, builds gstack from source, registers the Copilot plugin, and verifies the install. On Windows _and_ macOS / Linux.

---

## Quick install

> ⚠️ **Run from a fresh terminal**, not from inside an active `copilot` session. Copilot CLI holds an exclusive lock on `~/.copilot/settings.json` and any plugin install/uninstall from a child shell will fail with `EPERM`. The installer detects this and bails with a clear message.

### Windows (PowerShell 5.1 or 7+)

```powershell
iwr -useb https://raw.githubusercontent.com/aviraldua93/gstack-copilot/main/install.ps1 -OutFile install.ps1; .\install.ps1
```

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/aviraldua93/gstack-copilot/main/install.sh | bash
```

### From a local checkout

If you already cloned this repo:

```powershell
.\install.ps1 -LocalPlugin    # Windows
```

```bash
./install.sh --local-plugin   # mac/Linux
```

---

## What the installer does

1. **Preflight** — checks for `git`, `copilot`, and (Windows only) `node`. Detects active Copilot session via `$env:COPILOT_CLI` and bails early.
2. **Bun** — installs the pinned version (`1.3.10`, matches `gstack-upstream/setup`) to `~/.bun/bin` via the official `bun.sh/install.ps1` / `bun.sh/install` script if not already present.
3. **Upstream gstack** — clones [`garrytan/gstack`](https://github.com/garrytan/gstack) into `~/.claude/skills/gstack/` (path is hardcoded in SKILL.md preambles — do not change).
4. **Build** — runs `bun install` + `bun run build` under Git Bash (Windows) / bash (mac/Linux) to produce the compiled helper binaries.
5. **Playwright Chromium** — installs the browser bundle (`~170 MB`). On Windows this uses Node.js, not Bun, because [oven-sh/bun#4253](https://github.com/oven-sh/bun/issues/4253) prevents Bun from launching Chromium on Windows.
6. **Plugin registration** — auto-detects a local `plugin/plugin.json` if you ran the script from a clone; otherwise clones the plugin shim. Idempotent: if already registered, runs `copilot plugin update gstack` instead.
7. **Verify** — `copilot plugin list` must show `gstack`, plus binary + helper sanity checks.

Total install time: 2–5 minutes (first run, mostly the Playwright download). Total disk footprint: ~500 MB (`~/.bun/` + `~/.claude/skills/gstack/node_modules` + Playwright Chromium).

---

## Upgrade

```powershell
# Windows
.\install.ps1 -Force          # pulls newest upstream gstack + rebuilds + re-registers
```

```bash
# mac/Linux
./install.sh --force
```

`-Force` triggers a clean re-clone of upstream and re-runs `bun install` + `bun run build`. The plugin step uses `copilot plugin update gstack`, so settings.json stays consistent.

---

## Uninstall

```powershell
# Windows
.\uninstall.ps1               # unregisters plugin + removes ~/.claude/skills/gstack
.\uninstall.ps1 -PurgeBun     # also removes ~/.bun
.\uninstall.ps1 -PurgeUserState   # also removes ~/.gstack user state (skill artifacts)
.\uninstall.ps1 -KeepUpstream     # only unregisters plugin, keeps everything else
```

```bash
# mac/Linux
./uninstall.sh
./uninstall.sh --purge-bun --purge-user-state --yes
./uninstall.sh --keep-upstream
```

All destructive operations prompt for confirmation unless you pass `-Yes` / `--yes`.

---

## What's included (15 skills)

| Skill | Trigger | What it does |
|---|---|---|
| `review` | "review this pr" | Pre-landing PR review |
| `investigate` | "investigate", "debug" | Systematic root-cause debugging |
| `plan-ceo-review` | "ceo review" | Strategic plan review |
| `plan-eng-review` | "eng review" | Architecture review |
| `autoplan` | "autoplan" | CEO → design → eng plan pipeline |
| `office-hours` | "office hours" | Reframe product idea before coding |
| `retro` | "retro" | Weekly engineering retrospective |
| `health` | "health" | Code quality dashboard |
| `careful` | "careful" | Warn before destructive commands |
| `guard` | "guard" | Activate careful + freeze |
| `qa` | "qa", "test" | Browser-based QA harness |
| `design-review` | "design review" | Pixel/UX review via browser |
| `browse` | "browse" | Headless browser session |
| `canary` | "canary" | Smoke test deployed change |
| `scrape` | "scrape" | Page scraper |

Browser-dependent skills (`qa`, `design-review`, `browse`, `canary`, `scrape`) need the Playwright + Chromium step to function.

---

## Architecture

```
plugin/                                   <- the Copilot CLI plugin
├── plugin.json                          <- minimal Copilot manifest
└── skills/
    ├── review/SKILL.md
    ├── investigate/SKILL.md
    └── ... (15 total)

~/.claude/skills/gstack/                 <- full gstack upstream lives here
├── bin/                                 <- gstack-config, gstack-paths, ...
├── browse/dist/                         <- compiled browse + find-browse binaries
├── design/dist/                         <- compiled design binary
└── node_modules/                        <- bun install output (~250 MB)
```

The SKILL.md files in `plugin/skills/` reference `~/.claude/skills/gstack/bin/...` directly. The two locations are coupled by design: Copilot CLI loads the SKILL.md from the plugin path, but the helper scripts and compiled binaries live in the upstream install path.

---

## Tool name mapping

This port keeps Claude's original tool names — Copilot CLI accepts them as aliases:

| Claude name | Copilot CLI canonical | Status |
|---|---|---|
| `Bash` | `execute` | ✅ valid alias |
| `Read` | `read` | ✅ valid alias |
| `Write` / `Edit` | `edit` | ✅ both valid |
| `Grep` / `Glob` | `search` | ✅ both valid |
| `Agent` | `agent` | ✅ alongside `Task`, `custom-agent` |
| `WebSearch` | `web` | ✅ alongside `WebFetch` |
| `AskUserQuestion` | _none_ | ❌ removed |

Other Claude-specific frontmatter fields (`preamble-tier`, `triggers`, `version`) are silently ignored by Copilot CLI.

---

## What could still break (and what to do)

1. **EPERM on `settings.json` during install** — you are inside an active `copilot` session.
   - **Fix**: exit all `copilot` sessions, open a brand-new terminal, re-run. The installer checks `$env:COPILOT_CLI` and aborts with this message before doing any damage.

2. **`browse.exe` is broken on Windows** — upstream gstack's `bun build --compile browse/src/cli.ts --outfile browse/dist/browse` currently produces a 59-byte bash shebang wrapper instead of a compiled Windows binary, and the wrapper recursively `exec`s itself. The installer detects this (`< 1KB` file size) and warns loudly. The 98 MB `find-browse.exe` _does_ build correctly.
   - **Impact**: browser-dependent skills (`qa`, `design-review`, `browse`, `canary`, `scrape`) won't work on Windows.
   - **Fix**: file an issue at <https://github.com/garrytan/gstack/issues>. Not solvable in this repo — it's upstream's build script.

3. **`~/.bun/bin` not on PATH after install** — the installer adds it to the current shell session only.
   - **Fix**: add to your permanent PATH. PowerShell: `[Environment]::SetEnvironmentVariable('Path', "$env:Path;$HOME\.bun\bin", 'User')`. Bash/Zsh: append `export PATH="$HOME/.bun/bin:$PATH"` to your `.bashrc` / `.zshrc`.

4. **Windows: `node` not found** — Playwright Chromium launch requires Node.js on Windows (Bun#4253). The installer fails preflight if Node isn't on PATH.
   - **Fix**: install Node.js (any LTS) from <https://nodejs.org>. Re-run installer.

5. **Windows: Git Bash not found** — `bun install` / `bun run build` need bash. WSL's bash stub (`C:\Windows\system32\bash.exe`) doesn't count if WSL isn't actually installed.
   - **Fix**: install Git for Windows from <https://git-scm.com/download/win> (provides `C:\Program Files\Git\bin\bash.exe`).

6. **PowerShell 5.1 vs 7** — the installer is compatible with both. It uses ASCII-only headers, regex `-match` / `$Matches` instead of PS7-only scriptblock-in-replace, and `Invoke-Capture` to isolate native command stderr from `$ErrorActionPreference=Stop`.

7. **Aspirational GitHub URLs** — the `iwr | iex` / `curl | bash` one-liners reference `aviraldua93/gstack-copilot`. Until that repo is published, use the local-checkout flow: clone this directory and run `.\install.ps1 -LocalPlugin` / `./install.sh --local-plugin`.

8. **Plugin install deprecation warning** — Copilot CLI 1.0.61 prints `⚠️  Warning: Direct plugin installs (repos, URLs, local paths) are deprecated. Only plugin@marketplace installs will be supported in a future release.` This works today and isn't fatal, but eventually gstack will need to be published to the Copilot plugin marketplace.

9. **First-run download size** — Bun (~30 MB) + `node_modules` (~250 MB) + Playwright Chromium (~170 MB) ≈ **500 MB**. Build step itself takes 1–3 minutes on a modern laptop.

10. **SKILL.md preamble bash blocks are NOT auto-executed** — Claude Code auto-runs the bash block at the top of each SKILL.md before the LLM sees the prompt. Copilot CLI does NOT do this — the LLM reads "## Preamble (run first)" and executes it via the `Bash` tool. Works, but slightly different ergonomics from the Claude Code experience.

11. **No `AskUserQuestion` tool** — gstack skills that relied on Claude's structured `AskUserQuestion` tool will ask in free text instead. Functional but less structured.

---

## Verification (after install)

```powershell
# Plugin is registered
copilot plugin list                    # should show: • gstack (vX.Y.Z)

# Helpers are in place
ls ~/.claude/skills/gstack/bin/        # should list gstack-config, gstack-paths, ...

# Compiled binaries are present (Windows)
ls ~/.claude/skills/gstack/browse/dist/    # find-browse.exe should be ~94 MB
                                            # browse.exe is currently broken upstream (see #2 above)

# Try a skill
copilot                                # start a session
> /skills list                         # in the session — confirms gstack appears
> review this pr                       # invokes the review skill
```

---

## Files in this repo

```
gstack-copilot/
├── install.ps1          # Windows one-command installer
├── install.sh           # macOS / Linux one-command installer
├── uninstall.ps1        # Windows uninstaller
├── uninstall.sh         # macOS / Linux uninstaller
├── plugin/              # the Copilot CLI plugin (registered with `copilot plugin install`)
│   ├── plugin.json
│   └── skills/
│       └── {15 skills}/SKILL.md
├── gstack-upstream/     # full clone of garrytan/gstack (reference only)
└── README.md            # this file
```

`plugin/skills/` is the deliverable that `copilot plugin install` consumes. `gstack-upstream/` is a reference clone for development; the installer pulls a fresh copy into `~/.claude/skills/gstack/`.

---

## Credits

- [Garry Tan](https://github.com/garrytan) — original [gstack](https://github.com/garrytan/gstack) skills for Claude Code
- This repo — port + Copilot CLI packaging + install automation
