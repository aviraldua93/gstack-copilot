# gstack for GitHub Copilot CLI

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Skills: 53](https://img.shields.io/badge/skills-53-blue)](#whats-included)
[![Tested: 27/27](https://img.shields.io/badge/stress--tested-27%2F27-brightgreen)](STRESS_TEST_REPORT.md)

A port of [garrytan/gstack](https://github.com/garrytan/gstack) — Garry Tan's
opinionated CEO / Eng / Design / QA / Release engineering workflow — to
[GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli)
plugin format.

**All 53 skills auto-generated** via gstack's official `hosts/copilot.ts`
adapter system — no hand-porting, no drift. Stress-tested end-to-end on
Windows: see [STRESS_TEST_REPORT.md](STRESS_TEST_REPORT.md).

---

## Install

In a **fresh terminal** (not inside an active `copilot` session, because
Copilot CLI holds a lock on `~/.copilot/settings.json` while running):

```shell
# 1. Register this marketplace
copilot plugin marketplace add aviraldua93/gstack-copilot

# 2. Install the gstack plugin
copilot plugin install gstack@gstack-copilot

# 3. Verify
copilot plugin list
```

For browser-dependent skills (`browse`, `qa`, `design-review`, `canary`,
`scrape`, `make-pdf`), you also need the runtime binaries. Run the one-shot
installer with **PowerShell 7+** (`pwsh`, not the default Windows PowerShell 5.1):

```powershell
iwr -useb https://raw.githubusercontent.com/aviraldua93/gstack-copilot/main/install.ps1 -OutFile install.ps1
pwsh -ExecutionPolicy Bypass -File .\install.ps1
```

If you've already installed the plugin via the marketplace path above, use
`-RuntimeOnly` to skip the redundant plugin register step:

```powershell
pwsh -ExecutionPolicy Bypass -File .\install.ps1 -RuntimeOnly
```

On macOS / Linux:
```bash
curl -fsSL https://raw.githubusercontent.com/aviraldua93/gstack-copilot/main/install.sh | bash
```

This installs Bun, builds gstack binaries from upstream, copies runtime assets
to `~/.copilot/skills/gstack/`, then downloads Playwright Chromium last (so a
Playwright failure won't strand the runtime).

---

## What's included (53 skills)

### Plan-mode reviews

| Skill | What it does |
|-------|-------------|
| `office-hours` | Reframe your product idea before you write code |
| `plan-ceo-review` | CEO-level review: find the 10-star product in the request |
| `plan-eng-review` | Lock architecture, data flow, edge cases, and tests |
| `plan-design-review` | Rate each design dimension 0-10 |
| `plan-devex-review` | DX-mode review: TTHW, magical moments, friction points |
| `plan-tune` | Self-tune AskUserQuestion sensitivity per question |
| `autoplan` | One command runs CEO → design → eng → DX review |
| `design-consultation` | Build a complete design system from scratch |
| `spec` | Turn vague intent into a precise, executable spec |

### Implementation + review

| Skill | What it does |
|-------|-------------|
| `review` | Pre-landing PR review. Finds bugs that pass CI but break in prod |
| `investigate` | Systematic root-cause debugging. No fixes without investigation |
| `design-review` | Live-site visual audit + fix loop |
| `design-shotgun` | Generate multiple AI design variants, comparison board, iterate |
| `design-html` | Generate production-quality HTML/CSS |
| `devex-review` | Live developer experience audit |
| `qa` | Open a real browser, find bugs, fix them, re-verify |
| `qa-only` | Same as `qa` but report-only |
| `scrape` | Pull data from a web page |
| `skillify` | Codify the most recent successful `/scrape` flow |

### Release + deploy

| Skill | What it does |
|-------|-------------|
| `ship` | Run tests, review, push, open PR |
| `land-and-deploy` | Merge the PR, wait for CI and deploy, verify production health |
| `canary` | Post-deploy monitoring loop |
| `landing-report` | Read-only dashboard for the ship queue |
| `document-release` | Update all docs to match what you just shipped |
| `document-generate` | Generate Diataxis docs from code |
| `setup-deploy` | One-time deploy config detection |
| `gstack-upgrade` | Update gstack to the latest version |

### Operational + memory

| Skill | What it does |
|-------|-------------|
| `context-save` | Save working context (git state, decisions, remaining work) |
| `context-restore` | Resume from a saved context |
| `learn` | Manage what gstack learned across sessions |
| `retro` | Weekly retro with per-person breakdowns |
| `health` | Code quality dashboard (type checker, linter, tests, dead code) |
| `benchmark` | Performance regression detection |
| `benchmark-models` | Cross-model benchmark for skills |
| `cso` | OWASP Top 10 + STRIDE security audit |

### Browser + agent integration

| Skill | What it does |
|-------|-------------|
| `browse` | Headless browser — real Chromium, real clicks, ~100ms/command |
| `open-gstack-browser` | Launch the visible GStack Browser with sidebar |
| `setup-browser-cookies` | Import cookies from your real browser |
| `pair-agent` | Pair a remote AI agent with your browser |

### iOS QA

| Skill | What it does |
|-------|-------------|
| `ios-qa` | Live-device iOS QA via USB CoreDevice tunnel |
| `ios-fix` | Autonomous iOS bug fixer with regression snapshot capture |
| `ios-design-review` | Designer's-eye QA on a real iPhone |
| `ios-clean` | Strip DebugBridge + #if DEBUG before Release build |
| `ios-sync` | Regenerate the iOS debug bridge |

### Safety + scoping

| Skill | What it does |
|-------|-------------|
| `careful` | Warn before destructive commands (rm -rf, DROP TABLE, force-push) |
| `freeze` | Lock edits to one directory. Hard block |
| `guard` | Activate both `careful` + `freeze` |
| `unfreeze` | Remove directory edit restrictions |
| `make-pdf` | Turn any markdown file into a publication-quality PDF |

---

## Architecture

This repository is **both a Copilot CLI marketplace and a plugin**:

```
.github/plugin/marketplace.json    # marketplace manifest (canonical path)
plugins/gstack/
├── plugin.json                    # plugin manifest (v0.2.1)
├── hooks.json                     # PreToolUse hooks for careful + freeze
├── skills/                        # 53 SKILL.md files (auto-generated)
├── LICENSE                        # MIT (Garry Tan)
└── NOTICE                         # Attribution + architecture explanation
install.ps1 / install.sh           # One-line installer (binaries + Playwright)
STRESS_TEST_REPORT.md              # End-to-end test results
```

### Why a faithful port instead of a rewrite

Upstream gstack ships a declarative host adapter system (see
[`docs/ADDING_A_HOST.md`](https://github.com/garrytan/gstack/blob/main/docs/ADDING_A_HOST.md)).
Adding Copilot CLI was a ~50-line `hosts/copilot.ts` file that extends
`hosts/opencode.ts`. Skills are then regenerated for the new host via:

```bash
bun run gen:skill-docs --host copilot
```

This means:
- **Zero hand-ported SKILL.md files** — all 53 skills are canonical, generated output
- **No drift from upstream** — `bun run build` regenerates everything
- **Same routing context preserved** — multi-line descriptions, triggers, preamble structure
- **Path rewrites are mechanical** — `~/.claude/skills/gstack` → `~/.copilot/skills/gstack` everywhere

---

## Known limitations

1. **Run install from a fresh terminal.** Copilot CLI locks `~/.copilot/settings.json`
   while a session is active, so any plugin install/uninstall from inside a
   session will fail with `EPERM`.
2. **`careful` / `guard` hooks require runtime files.** The `plugin/hooks.json`
   references `~/.copilot/skills/gstack/careful/bin/check-careful.sh`. If you only
   install the marketplace plugin (without `install.ps1`), the hook scripts will
   silently no-op. Run `install.ps1` for full safety enforcement.
3. **Bash required on Windows.** Skill preambles run via Git Bash. The installer
   detects this; if you don't have Git Bash, install [Git for Windows](https://git-scm.com/download/win).
4. **Bun runtime required.** Installer downloads Bun 1.3.10 with checksum
   verification.

---

## Attribution

Original work: [Garry Tan](https://github.com/garrytan) — MIT licensed.
This port: [@aviraldua93](https://github.com/aviraldua93).

The `hosts/copilot.ts` adapter that makes this port possible is inspired by
[PR #1852](https://github.com/garrytan/gstack/pull/1852) by `@lolisaigao1234`,
with `cliCommand` corrected to `copilot` (standalone CLI) instead of `gh`.

If gstack accepts an upstream Copilot CLI host PR, this fork becomes redundant
and you should `bun run gen:skill-docs --host copilot` from the canonical repo
instead.

---

## License

MIT — see [LICENSE](LICENSE).

This port preserves Garry Tan's original copyright in every SKILL.md file's
generation pipeline. Distribution of this fork is permitted under MIT terms
including the requirement to retain the copyright notice.
