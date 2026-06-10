# gstack-copilot: Strategic State Report

**Date:** 2026-06-10  
**Author:** GitHub Copilot CLI session on behalf of @aviraldua93  
**Plugin version live:** v0.2.2 at https://github.com/aviraldua93/gstack-copilot

This report synthesizes three deep investigations done today (post-v0.2.2 ship):
1. **Gbrain status** — what it is, how it integrates, where we stand
2. **Skill gap analysis** — per-skill tier ratings across all 53 skills
3. **Auto-update strategy** — daily sync from upstream gstack + versioning

---

## TL;DR

| Question | Answer |
|---|---|
| **Is the port shippable?** | ✅ Yes. v0.2.2 live, 53 skills, marketplace install works. 6 fresh-VM bugs found and fixed in v0.2.2. 5 deeper bugs in upstream gstack forwarded to garrytan/gstack#1955-1959. |
| **Is Gbrain integrated?** | ⚠️ Passively — the `setup-gbrain` / `sync-gbrain` skills are generated and present; the gbrain CLI itself is bring-your-own. PR #1998 (open upstream) would add native Copilot embedding support. Recommend opt-in `-WithGbrain` flag in installer. |
| **Skill quality breakdown** | 19 Tier A (ship as-is) / 25 Tier B (degraded but useful) / 9 Tier C (broken on Windows: ios-*, claude, codex deps, pair-agent, benchmark-models) / 1 Tier D (codex, already excluded). |
| **Daily auto-update** | Yes, GitHub Actions cron job design is ready. Polls upstream `VERSION` file, regenerates skills, runs static tests, opens PR; auto-merge for PATCH bumps only. |
| **Versioning** | `MAJOR.MINOR.PATCH+gstack.<upstream-4-part>` (e.g. `0.3.0+gstack.1.57.7.0`). SemVer-valid, preserves upstream traceability. |

---

## Part 1: Gbrain

### What it is

[garrytan/gbrain](https://github.com/garrytan/gbrain) (22k stars, MIT, Bun + TypeScript) is **a separate Garry Tan product** — a persistent knowledge base / semantic memory layer for AI agents. It is NOT gstack-internal.

- **CLI verbs**: `gbrain init`, `gbrain doctor`, `gbrain search`, `gbrain put`, `gbrain get`, `gbrain serve` (MCP stdio), `gbrain code-def` / `code-refs` / `code-callers` / `code-callees`
- **Backing store**: PGLite local (`~/.gbrain/brain.pglite`) OR Supabase Postgres OR remote MCP
- **Install**: `bun install -g github:garrytan/gbrain` (~30 min via the agent-driven install; ~30 sec for `gbrain init --pglite`)
- **Embeddings**: OpenAI/Voyage/Anthropic/Ollama — and **soon Copilot** (PR #1998)

### How gstack uses it

| Component | Purpose |
|---|---|
| `setup-gbrain` skill | One-command onboarding: install gbrain → init brain → register MCP → trust policy |
| `sync-gbrain` skill | Re-index this repo via `gbrain sources add` + `gbrain sync --strategy code` |
| `hosts/gbrain.ts` | gbrain itself is a *host* of gstack (skills generated for the gbrain agent runtime) |
| 17 helper bins | `gstack-brain-*` (memory-sync to private git repo) + `gstack-gbrain-*` (wrappers around `gbrain` CLI) |

### Where our port stands

**Status: passively integrated — skills are generated and present, but the underlying `gbrain` CLI is not auto-installed by our installer.**

- ✅ Both skills (`gstack-setup-gbrain`, `gstack-sync-gbrain`) ship in our v0.2.2 plugin
- ✅ Path-rewritten correctly: `GSTACK_ROOT="$HOME/.copilot/skills/gstack"` 
- ✅ Copilot CLI supports MCP (`copilot mcp add gbrain -- gbrain serve` works exactly like `claude mcp add`)
- ⚠️ Our `install.ps1` does NOT install the `gbrain` CLI
- ⚠️ `gstack-gbrain-detect` is in `~/.copilot/skills/gstack/bin/` but `command -v gbrain` returns nothing
- ⚠️ Skill is graceful — `/setup-gbrain` is designed to bootstrap gbrain itself

### The Copilot embedding breakthrough (PR #1998)

[garrytan/gbrain#1998](https://github.com/garrytan/gbrain/pull/1998) by [@tonyxu-io](https://github.com/tonyxu-io) adds a **native Copilot embedding provider** to gbrain:
- Uses `~/.copilot/config.json` for auth (already present on Copilot CLI machines)
- Auth chain: `GBRAIN_COPILOT_TOKEN` → `COPILOT_GITHUB_TOKEN` → `GH_TOKEN` → `GITHUB_TOKEN` → `~/.copilot/config.json`
- Implementation: 213 LOC, 5 files, all tests pass, mergeable: true
- Original PR #691 was closed 6/8 in Garry's "cathedral cleanup"; Tony rebased 6/9 → PR #1998

**When this merges**, every Copilot CLI user gets gbrain embeddings for free with no separate API key. **This is the moment to make Gbrain a first-class feature of our port.**

### Recommendation

**Tier the Gbrain story as opt-in / advanced, don't block install on it.**

1. ✅ Keep both skills in our marketplace (already there)
2. Add opt-in `-WithGbrain` switch to `install.ps1`:
   - If set: `bun install -g github:garrytan/gbrain` after existing steps
   - Plus auto-register MCP: `copilot mcp add gbrain -- gbrain serve`
3. Add Gbrain section to README pointing at the optional flag
4. Watch PR #1998 — when merged, document the Copilot-powered install path in README

### Windows caveats (per upstream)

- Open issues #1294, #1149, #1554, #1396 — "Windows / CRLF portability"
- No Windows binary release published; `binary self-update` degrades to notify-only on Windows
- POSIX-only signal handling guarded but not all paths Windows-clean

---

## Part 2: Skill gap analysis (full report: SKILL_GAP_ANALYSIS.md)

### Tier breakdown

| Tier | Count | Skills |
|---|---|---|
| **A — Ship as-is (pure prose/lightweight runtime)** | 19 | `context-restore`, `context-save`, `document-generate`, `document-release`, `health`, `investigate`, `landing-report`, `learn`, `retro`, `setup-deploy`, `unfreeze`, `upgrade`, root `gstack` (with binary probe fix) |
| **B — Degraded but useful** | 25 | All browser skills (`browse`, `qa`, `canary`, `scrape`, `design-*`), most workflow skills (`ship`, `office-hours`, `review`, `devex-review`, `cso`), safety skills (`careful`, `freeze`, `guard` — advisory-only), `setup-gbrain`/`sync-gbrain` (user-driven) |
| **C — Broken on Windows Copilot CLI** | 9 | All 5 `ios-*` (need macOS+Xcode+iPhone), `claude` (needs claude binary), `pair-agent` (needs ngrok+remote target), `benchmark-models` (needs cross-model CLIs), plus `autoplan`+plan-* if codex isn't shipped |
| **D — Already excluded** | 1 | `codex` (in `skipSkills`) |

### Cross-cutting gaps (in priority order)

1. **🔴 Safety hooks silently downgraded** — `careful`/`freeze`/`guard` body claims "blocked" / "every command checked" but `hooks:` frontmatter is stripped by opencode-derived allowlist. Bin scripts are dead code. **We already fixed this in v0.2.1 by wiring hooks.json with `${CLAUDE_PLUGIN_ROOT}` paths** — verify on next install.

2. **🟡 AskUserQuestion has no Copilot CLI equivalent** — 50 of 53 skills reference it (8-83 times each). Falls back to prose. **Fix:** add `toolRewrites: { 'AskUserQuestion': 'ask the user inline' }` to `hosts/copilot.ts`. Low risk, big clarity win.

3. **🟡 Agent tool wording doesn't match Copilot's `task` tool** — 9 skills (autoplan, ship, review, plan-*). **Fix:** add `toolRewrites: { 'Agent tool': 'task tool' }` to `hosts/copilot.ts`.

4. **🟢 Windows binary extension probes** — `[ -x .../browse ]` (no .exe). Git Bash auto-resolves `.exe` (we verified), so this works in practice on Windows. Native PowerShell shell-runs would fail. **Fix:** upstream PR to add `|| [ -x .../browse.exe ]` fallback.

5. **🟢 `open URL` is macOS-only** — 48 skills use bare `open` for the Boil-the-Ocean link. Cross-platform helper `gstack-open-url` already exists in runtime bin but is unused. **Fix:** upstream gstack PR.

6. **🟡 `codex` CLI unavailable** — 9 plan/review skills depend on it for "outside voice." Our skills run in single-voice mode, which is currently MISLABELED as CONFIRMED in consensus tables (filed upstream as garrytan/gstack#1956).

7. **🟢 `make-pdf` skill** — Windows binary probe + missing `GSTACK_MAKE_PDF` export. Already filed for upstream fix.

### Recommended host adapter changes (our fork)

```typescript
// hosts/copilot.ts — extend the inherited skipSkills
const copilot: HostConfig = {
  ...opencode,
  name: 'copilot',
  // ...existing fields...
  generation: {
    ...opencode.generation,
    skipSkills: [
      'codex',                       // already excluded
      'claude',                      // needs claude binary
      'pair-agent',                  // needs ngrok + remote target
      'benchmark-models',            // needs cross-model CLIs
      'ios-qa', 'ios-fix', 'ios-clean', 'ios-sync', 'ios-design-review',
      // Optionally skip if codex isn't reliably present:
      // 'autoplan', 'plan-ceo-review', 'plan-eng-review',
      // 'plan-design-review', 'plan-devex-review',
    ],
  },
  toolRewrites: {
    'Agent tool': 'task tool',
    'the Agent tool': 'the `task` tool',
    // 'AskUserQuestion' rewrite intentionally elided — most occurrences
    // are documentation of the format (decision-brief structure), not
    // tool invocations. Bulk rewrite would corrupt the docs.
  },
};
```

**Outcome:** 53 → 44 skills shipped, all with sharper Copilot-aware wording. Drops 9 known-broken skills; clearer per-tool routing for sub-agents.

---

## Part 3: Auto-update strategy

### Detection

- **Recommended signal**: Poll `https://raw.githubusercontent.com/garrytan/gstack/main/VERSION` daily. No rate limit, no auth, canonical (upstream's own `version-gate.yml` uses the same field).
- **Cadence observation**: Upstream ships **1-3 versions per day** (20 entries in last 2 weeks). Daily cron is right.

### Versioning

**Recommendation: `MAJOR.MINOR.PATCH+gstack.<upstream-4-part>`**

Example: `0.3.0+gstack.1.57.7.0`
- SemVer-valid (build metadata after `+` is ignored for ordering)
- Preserves upstream traceability
- npm/Copilot marketplace tooling orders correctly

**Bump rules:**
| Upstream change | Our bump |
|---|---|
| PATCH (e.g., 1.57.6.0 → 1.57.7.0), no skill set changes | Our PATCH |
| MINOR (e.g., 1.57.x → 1.58.0.0) OR new skills detected in regen diff | Our MINOR |
| MAJOR OR `hosts/copilot.ts` won't compile (HostConfig schema break) | Our MAJOR |

### Re-generation flow (CI-ready)

```bash
cd gstack-upstream
git fetch origin main && git checkout main && git pull --ff-only
cp ../ports/hosts-copilot.ts hosts/copilot.ts
bun run scripts/inject-copilot-host.ts hosts/index.ts
bun install --frozen-lockfile  # if package.json changed
bun test test/host-config.test.ts       # validates adapter compiles
bun test test/gen-skill-docs.test.ts    # validates generation clean
bun run gen:skill-docs --host copilot
# Static checks: no .claude/skills leakage, valid frontmatter, count >= 40
rm -rf ../marketplace/plugins/gstack/skills/*
rsync -a .copilot/skills/ ../marketplace/plugins/gstack/skills/
echo "$NEW_UPSTREAM" > ../.upstream-version
# Bump version per rules above
git commit -am "chore(upstream): sync gstack@$NEW_UPSTREAM → plugin@$NEW_OURS"
```

### GitHub Actions workflow

Full YAML in the research agent's report — saved to `~/.copilot/session-state/.../temp` and ready to drop into `.github/workflows/upstream-sync.yml`. Key features:
- Daily cron at 06:17 UTC (offset to avoid GH minute-zero spike)
- Concurrency lock (never two syncs in flight)
- Three-stage: detect → regen + tests → open PR
- Auto-merge gate: PATCH bumps only with green CI
- Failure escalation: opens tracking issue with workflow run link
- Static guards: no `.claude/skills` leakage, valid frontmatter, skill count ≥ 40

### Top 3 failure modes

| Failure | How CI catches it | Recovery |
|---|---|---|
| `hosts/copilot.ts` won't compile (HostConfig schema change upstream) | `test/host-config.test.ts` fails | Manual: read `scripts/host-config.ts` for new field, add to `ports/hosts-copilot.ts`, re-run workflow |
| Path rewriter format changes | Static `grep .claude/skills` check fails | Same as above |
| Skill removal breaks README skill list | Warning-only check; PR still merges | Auto-regenerate README skill list from `plugins/gstack/skills/` dir on each sync |

---

## Recommended next actions (in priority order)

### P0 — This week
1. **Add `toolRewrites` to `hosts/copilot.ts`** (fixes "Agent tool" wording across 9 skills)
2. **Add `skipSkills` for known-broken skills** (claude, pair-agent, ios-*, benchmark-models)
3. **Verify v0.2.1 hooks fix actually works** with a fresh install in a new terminal
4. **Set up GitHub Actions daily upstream-sync** workflow

### P1 — Next week
5. **Add `-WithGbrain` flag to `install.ps1`** (opt-in gbrain install + `copilot mcp add`)
6. **Watch upstream PR #1998** — when merged, document Copilot-powered gbrain path
7. **Write `versioning-policy.md`** documenting the `+gstack.X.Y.Z.W` scheme
8. **Test full install.ps1 on a fresh Windows VM** end-to-end

### P2 — When time allows
9. **PR upstream gstack** with `make-pdf` Windows binary probe fix
10. **PR upstream gstack** with cross-platform `open URL` → `gstack-open-url` fix
11. **Submit `hosts/copilot.ts` as a PR upstream** (low merge probability per closed-PR history, but cheap to try)
12. **Open tracking issue upstream** for "allowlist mode silently strips hooks; safety claims become misleading"

---

## Artifacts produced today

- `STRESS_TEST_REPORT.md` — 27/27 test run results
- `WINDOWS_AUDIT.md` — Windows compatibility findings
- `SKILL_GAP_ANALYSIS.md` — full 53-skill tier audit (20.4 KB)
- `STRATEGIC_STATE_REPORT.md` — this document
- Issues filed downstream: 6 closed (v0.2.2), 5 open + cross-linked upstream
- Issues filed upstream: garrytan/gstack#1955-1959 (5 autoplan bugs)
- v0.2.2 plugin live at https://github.com/aviraldua93/gstack-copilot with hooks wired
