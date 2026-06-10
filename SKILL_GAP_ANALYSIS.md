# Skill Gap Analysis (gstack-copilot v0.2.2 vs upstream gstack)

> Audit performed against:
> - Upstream gstack: `C:\Users\aviraldua\dev\gstack-copilot\gstack-upstream\` (`.copilot/skills/gstack-*` generated output, 53 skills)
> - Installed plugin: `C:\Users\aviraldua\.copilot\installed-plugins\gstack-copilot\gstack\skills\` (53 skills, byte-identical content to upstream-generated, CRLF-normalized)
> - Runtime root: `C:\Users\aviraldua\.copilot\skills\gstack\` (bin/, browse/dist (`browse.exe`), design/dist (`design.exe`), make-pdf/dist (`pdf.exe`), careful/bin, freeze/bin, plan-devex-review/, qa/, review/, ETHOS.md)
> - Host adapters audited: `hosts/copilot.ts`, `hosts/opencode.ts`, `hosts/factory.ts`, `hosts/claude.ts`
> - Generator: `scripts/gen-skill-docs.ts`

## Summary

| Tier | Count | Definition |
|---|---|---|
| **A — Ships as-is** | 19 | Pure prose / works against shipped runtime; no codex/claude/iOS hard deps |
| **B — Degraded but useful** | 25 | Works but loses key functionality silently (AskUserQuestion has no equivalent, hooks stripped, optional codex/claude calls no-op) |
| **C — Broken on Copilot CLI (Windows)** | 9 | Hard dependency on tooling we don't ship (claude binary, codex, ngrok, iOS stack, or a Windows binary-extension bug) |
| **D — Skipped by host config** | 1 | `codex` skill is in `generation.skipSkills` and not generated |
| **Generated total** | **53** | Plus the merged `gstack` root preamble skill |

**Big takeaway**: `AskUserQuestion` is referenced in 50/53 skill bodies but has no Copilot CLI equivalent and no host-side rewrite. This is the single largest portability gap; every Tier B classification below traces to it at least partially.

## Per-skill table

| Skill | Tier | Issues | Recommended action |
|---|---|---|---|
| `autoplan` | C | Core value is orchestrating 7 `codex exec` calls + 8 `Agent tool` (≠`task`) sub-reviews across CEO/eng/DX gates; 45 AskUserQuestion prompts. Without codex, the "auto-decision" pipeline collapses into manual checklists. | Mark as `requires-codex`; document degraded mode; consider conditional skip when `command -v codex` missing |
| `benchmark` | B | Uses `$B` browse binary (8 hits) which is `browse.exe` on Windows — bash probe `[ -x .../browse ]` (no .exe) likely fails. 3 codex calls are optional. | Fix runtime symlink (`browse` → `browse.exe`) or fix SKILL.md probe; otherwise ships |
| `benchmark-models` | C | Explicitly compares Claude/GPT/Gemini outputs; fails fast if none of the three CLIs are authed. Copilot CLI ships none of them. | Document as `requires-cross-model-clis`; add to skipSkills until at least one CLI is reliably present |
| `browse` | B | 83 `$B` invocations — every command depends on the browse binary; Windows extension mismatch (`browse` vs `browse.exe`); skill politely asks to run `./setup` if probe fails, but `setup` is bash. | Fix probe to also try `browse.exe`; add Windows path to runtime bin shim |
| `canary` | B | Same `$B` Windows issue as `browse`; 17 browse hits. Falls back gracefully. | Same fix as `browse` |
| `careful` | B | **Critical**: upstream uses `hooks: PreToolUse` for Bash to actually BLOCK destructive commands; allowlist frontmatter transform strips `hooks:`. Body still claims *"Every bash command will be checked"* — this is now an empty promise. Host injects a "Safety Advisory" prose blurb as compensation. `careful/bin/check-careful.sh` exists in runtime but is dead code. | Document advisory-only behavior in marketplace README and SKILL body; consider patching the generator to rewrite the misleading "blocked" wording when hooks are stripped |
| `claude` | C | The whole skill is a wrapper around `claude -p --output-format json`. Probes `command -v claude` at line 799 and exits if missing. Copilot CLI doesn't ship `claude`. | Add to `skipSkills` for copilot host (parallel to how Claude host skips its own `claude` skill) |
| `context-restore` | A | Pure prose + git state read. No external tooling required. | Ship as-is |
| `context-save` | A | Pure prose + git state read. | Ship as-is |
| `cso` | B | 33 AskUserQuestion (chief security officer interactive workflow); no `$B`/`$D`/codex hard deps. Falls back to text. | Ship; flag interactive degradation |
| `design-consultation` | B | 17 `$D` design binary hits — Windows `design` vs `design.exe` probe issue. Light codex (4) and AskUserQuestion (47). | Fix design binary probe; otherwise ships |
| `design-html` | B | 8 `$D` + 7 `$B` hits — same Windows extension issue. | Same |
| `design-review` | B | 28 `$B` + 9 `$D` hits — heavy browse/design dependency. | Same |
| `design-shotgun` | B | 22 `$D` hits. | Same |
| `devex-review` | B | 32 AskUserQuestion; no real codex/browse use. | Ship; flag AskUserQuestion degradation |
| `document-generate` | A | Pure prose + file writes. | Ship as-is |
| `document-release` | A | Pure prose + git diff reading + file edits; 39 AskUserQuestion is the only friction. | Ship; flag AskUserQuestion degradation |
| `freeze` | B | Same as `careful` — `hooks: PreToolUse` for Edit/Write stripped. Body claims "restricted to allowed path" but no enforcement. `freeze/bin/check-freeze.sh` is dead code. | Same as `careful` |
| `gstack` (root) | B | The root preamble skill bundles browse functionality (88 `$B` hits). Windows binary extension issue applies. | Fix binary probe |
| `guard` | B | Composite of `careful` + `freeze`; both sets of hooks stripped. Advisory-only on Copilot CLI. | Same as `careful` |
| `health` | A | Wraps existing project tools (lint/test/typecheck). No gstack-binary or external CLI deps. | Ship as-is |
| `investigate` | A | Pure debugging methodology; 35 AskUserQuestion is the only friction. No codex/browse hard deps. | Ship; flag AskUserQuestion degradation |
| `ios-clean` | C | Requires Xcode CoreDevice, Swift toolchain, real iPhone over USB, `gstack-ios-qa-daemon`. macOS-only stack. | Add to `skipSkills` for copilot host (Windows runtime); keep available on macOS variants |
| `ios-design-review` | C | Same iOS stack requirements. | Add to `skipSkills` (Windows) |
| `ios-fix` | C | Same iOS stack + Swift edits. | Add to `skipSkills` (Windows) |
| `ios-qa` | C | Same iOS stack + DebugBridge/StateServer SPM package. | Add to `skipSkills` (Windows) |
| `ios-sync` | C | Same iOS stack. | Add to `skipSkills` (Windows) |
| `land-and-deploy` | B | 7 `$B` browse hits + invokes `flyctl`/platform CLIs the user must already have installed (per `setup-deploy` config). | Ship; document that platform CLIs must be present |
| `landing-report` | A | Pure prose summary skill; no external tooling. | Ship as-is |
| `learn` | A | Pure pedagogical / explanation skill. | Ship as-is |
| `make-pdf` | C | **Windows bug**: SKILL.md probes `make-pdf/dist/pdf` (no .exe). Runtime ships `pdf.exe`. Probe always fails; skill prints `MAKE_PDF_NOT_AVAILABLE`. Also references `$HOME$GSTACK_MAKE_PDF/pdf` but `GSTACK_MAKE_PDF` is never exported in the preamble (only `GSTACK_BIN`, `GSTACK_BROWSE`, `GSTACK_DESIGN`). | **Upstream fix needed**: extend probe to also test `pdf.exe`; export `GSTACK_MAKE_PDF` in preamble |
| `office-hours` | B | 5 real codex calls (review-style), 2 browse, 7 design, 49 AskUserQuestion, 3 `mcp__` references. Optional gemini path. | Ship; document degradation |
| `open-gstack-browser` | B | 14 `$B` hits; Windows binary extension issue. | Fix binary probe |
| `pair-agent` | C | Requires `ngrok` to expose local agent for remote pairing; also expects a remote target environment to connect to. Neither shipped. | Add to `skipSkills` until pair-agent infrastructure is in place |
| `plan-ceo-review` | C | Core function is `codex review` of the plan — 5 real codex calls + 60 AskUserQuestion. Without codex this is just a long prose checklist. | Mark `requires-codex`; OR add to `skipSkills` until codex shipped |
| `plan-design-review` | C | Same shape: 5 codex + 26 design + 67 AskUserQuestion. Codex review of design plan is the value. | Same |
| `plan-devex-review` | C | 5 codex + 64 AskUserQuestion. | Same |
| `plan-eng-review` | C | 5 codex + 73 AskUserQuestion. | Same |
| `plan-tune` | B | Settings management for AskUserQuestion preferences across skills; ironically depends on AskUserQuestion to work. 6 `mcp__` references. | Ship; document that "tune" decisions are stored but the questions they tune don't pop up the same way on Copilot CLI |
| `qa` | B | 36 `$B` hits — heavy browser-driven QA. Windows binary extension issue. | Fix binary probe |
| `qa-only` | B | 31 `$B` hits. Same. | Same |
| `retro` | A | Pure prose retrospective skill. | Ship as-is |
| `review` | B | 6 real codex calls (specialist sub-reviews) + 4 Agent tool refs + 39 AskUserQuestion + 30 gbrain hits. Core review logic works without codex; loses outside-voice sub-reviews. | Ship; document degradation; consider host-side `Agent tool` → `task` rewrite |
| `scrape` | B | 15 `$B` hits (browse-based scraping); Windows binary extension issue. | Fix binary probe |
| `setup-browser-cookies` | B | 5 `$B` hits. | Fix binary probe |
| `setup-deploy` | A | Pure detection + writes config to CLAUDE.md; no external tool invocation in this skill itself. | Ship as-is |
| `setup-gbrain` | B | 5 real `gbrain *` invocations + 6 `mcp__` references — but this skill's PURPOSE is to install gbrain. User can complete setup. | Ship; user-driven install path |
| `ship` | B | 7 real codex calls (optional security review gate) + 9 Agent tool refs + 21 gbrain refs + 8 `gh pr` calls + redact-prepush integration. Core ship flow works without codex. | Ship; document degradation; flag Agent→task wording |
| `skillify` | B | 21 `$B` hits (browse used to codify a workflow into a skill). Windows binary extension issue. | Fix binary probe |
| `spec` | C | `--execute` flag spawns `claude -p` in a worktree (lines 1952-1958); 8 codex calls + 3 claude calls + 73 AskUserQuestion. Default mode works without claude binary, but `--execute` (advertised as a key feature) is broken without it. | Document `--execute` requires claude binary; otherwise functional |
| `sync-gbrain` | B | 7 real gbrain invocations — but again the skill exists to wire gbrain. | Ship; user-driven |
| `unfreeze` | A | Pure prose; restores edit permissions. | Ship as-is |
| `upgrade` / `gstack-upgrade` | A | Pure prose + git pull guidance. | Ship as-is |
| `codex` | D | Excluded by `generation.skipSkills: ['codex']` in `hosts/opencode.ts:22` (inherited by copilot). | (already correctly skipped) |

## Cross-cutting gaps (patterns affecting many skills)

### 1. Safety hooks silently downgraded to prose (`careful`, `freeze`, `guard`)
Upstream `hooks: PreToolUse` frontmatter enforces destructive-command warnings via `careful/bin/check-careful.sh` and `freeze/bin/check-freeze.sh`. The opencode/copilot host adapter uses `transformFrontmatter` allowlist mode (`keepFields: ['name','description']`) which **strips all hook configuration**. The body still says *"Every bash command will be checked for destructive patterns before running"* — this is now untrue. The bin scripts exist in runtime but are never invoked. The host injects a "Safety Advisory" prose blurb at the top of the body, but Copilot CLI cannot enforce; it can only advise.

**Affects**: `careful`, `freeze`, `guard` (3 skills).

### 2. `AskUserQuestion` has no Copilot CLI equivalent and no host-side rewrite
50 of 53 skills reference `AskUserQuestion` (8–83 times each; `plan-ceo-review` is the heaviest at 83). Copilot CLI has no equivalent structured-choice tool. The body falls back to writing the question as prose, which in interactive `copilot` chat may pause and wait, but in non-interactive / agent-orchestrated runs (e.g., spawned sub-skills) may just stall or silently choose the default. There are no `toolRewrites` in `hosts/copilot.ts` or `hosts/opencode.ts` to translate this.

**Affects**: Nearly every interactive skill.

### 3. "Agent tool" body wording doesn't match Copilot CLI's `task` tool
9 skills (`autoplan`, `ship`, `review`, plan-*-reviews) instruct *"use the Agent tool to spawn a sub-review"*. Copilot CLI exposes a `task` tool with `explore`/`general-purpose`/`code-review` subagent types. The model may or may not infer the mapping; literal "Agent tool" instructions can lead the model to claim the tool doesn't exist.

**Affects**: ~9 skills.

### 4. Windows binary extension probes fail (`browse`, `design`, `make-pdf`)
Runtime ships `browse.exe`, `design.exe`, `pdf.exe` on Windows. All SKILL.md probes use POSIX `[ -x "...browse" ]` (no extension). On strict POSIX shells this returns false; on MSYS2/Cygwin bash it sometimes auto-resolves `.exe` (undocumented). The `make-pdf` skill has the additional bug that `GSTACK_MAKE_PDF` is never exported by the preamble.

**Affects**: `browse`, `canary`, `qa`, `qa-only`, `design-*`, `make-pdf`, `gstack` root, `scrape`, `skillify`, `setup-browser-cookies`, `office-hours`, `open-gstack-browser`, `land-and-deploy`, `benchmark` (≈14 skills on Windows).

### 5. `open URL` is macOS-only (Windows: not a command; Linux: needs `xdg-open`)
48 of 53 skills include a `bash` block with `open https://garryslist.org/posts/boil-the-ocean` (the "Boil the Ocean" ethos link), conditional on first-run user opt-in. On Windows this would fail with `open: command not found`. A `gstack-open-url` cross-platform helper EXISTS in `runtime/bin/` but **no skill body actually invokes it** — they all use bare `open`.

**Affects**: 48 skills (first-run only, soft failure).

### 6. `codex` CLI not installed; whole class of "outside voice" reviews degrades
9 skills make multiple real `codex exec` calls (`autoplan` 9, `spec` 8, `ship` 7, `review` 6, plan-*-reviews 5 each, `office-hours` 5, `sync-gbrain`/`design-consultation`/`design-review`/`devex-review` 4). All probe `command -v codex` and degrade gracefully, but for `autoplan`/`plan-*-review`/`benchmark-models` the codex calls ARE the value proposition.

**Affects**: 9 plan/review skills (TIER_C); 8+ optional-codex skills (TIER_B).

### 7. `claude` CLI not installed
`gstack-claude` is a direct wrapper that errors out without `claude -p`. `gstack-spec` advertises `--execute` mode which spawns `claude -p` in a worktree.

**Affects**: `claude` (TIER_C), `spec` `--execute` flag (TIER_C feature within a TIER_B skill), `benchmark-models` (TIER_C).

### 8. `mcp__conductor__AskUserQuestion`, `mcp__gbrain__*`, `mcp__claude` references in bodies
Body text mentions these MCP namespaces verbatim. Conductor IDE is not present on Copilot CLI; gbrain MCP server is not registered (the gbrain CLI is, after `setup-gbrain`); `mcp__claude` is Claude-specific.

**Affects**: ~40 skills (low impact since text is descriptive, not executed verbatim).

### 9. iOS stack (CoreDevice + Xcode + USB + Swift toolchain)
5 ios-* skills hard-depend on macOS + Xcode + connected device. On Windows: zero shot.

**Affects**: `ios-qa`, `ios-fix`, `ios-clean`, `ios-sync`, `ios-design-review` (5 skills).

### 10. `pair-agent` needs `ngrok` + remote pairing target
22 `ngrok` references in body. Not shipped, not installable as a skill.

**Affects**: `pair-agent`.

### 11. Installed plugin has CRLF line endings; upstream-generated has LF
Identical content, identical line counts, ~1.8% size inflation per file from CR bytes. Doesn't break functionality (bash interpreters tolerate CRLF in heredocs and most contexts) but worth knowing — the marketplace install path is normalizing line endings.

## Specific recommendations

### Ship as-is (19 skills, Tier A)
`context-restore`, `context-save`, `document-generate`, `document-release`, `health`, `investigate`, `landing-report`, `learn`, `retro`, `setup-deploy`, `unfreeze`, `upgrade`/`gstack-upgrade`

Plus the merged `gstack` root preamble (with the Windows binary fix described below).

### Add to `skipSkills` in `hosts/copilot.ts` (9 skills)
For a Windows-primary Copilot CLI install, these should be skipped during generation to avoid shipping non-functional skills:

```ts
// hosts/copilot.ts — extend the inherited skipSkills
generation: {
  ...this.opencodeBase.generation,
  skipSkills: [
    'codex',                       // already excluded
    'claude',                      // needs claude binary
    'pair-agent',                  // needs ngrok + remote target
    'ios-qa', 'ios-fix', 'ios-clean', 'ios-sync', 'ios-design-review',  // macOS+Xcode+iPhone
    'benchmark-models',            // needs at least one of claude/gpt/gemini CLI authed
  ],
}
```

If keeping the plan-review skills, document them as `requires-codex`; otherwise also skip: `autoplan`, `plan-ceo-review`, `plan-eng-review`, `plan-design-review`, `plan-devex-review` (5 more).

### Needs runtime / generator fixes (upstream gstack)

1. **`make-pdf` Windows binary probe** — `gstack-upstream/.../gstack-make-pdf/SKILL.md` line ~122: extend probe from
   ```bash
   [ -x "$HOME$GSTACK_MAKE_PDF/pdf" ]
   ```
   to
   ```bash
   [ -x "$HOME$GSTACK_MAKE_PDF/pdf" ] || [ -x "$HOME$GSTACK_MAKE_PDF/pdf.exe" ]
   ```
   AND export `GSTACK_MAKE_PDF="$GSTACK_ROOT/make-pdf/dist"` in the preamble alongside `GSTACK_BROWSE` and `GSTACK_DESIGN`.

2. **`browse` / `design` Windows binary probes** — the canonical fallback in `browse`, `canary`, `qa`, etc:
   ```bash
   [ -x "$_ROOT/.copilot/skills/gstack/browse/dist/browse" ] && B="..."
   ```
   should also test `browse.exe`. Same for `$D` / `design.exe`.

3. **`open URL` cross-platform fix** — replace bare `open https://...` with `$GSTACK_BIN/gstack-open-url https://...` so the bundled helper (which detects platform: `open` on macOS, `xdg-open` on Linux, `cmd /c start` on Windows) is used. The helper already exists in runtime bin/.

4. **Hook-stripping advisory wording** — when the generator strips `hooks:` frontmatter, it should ALSO rewrite the body text claiming enforcement (`careful`/`freeze`/`guard` say *"Every bash command will be checked"* and *"blocked"* — should become *"flagged before execution"*).

### Needs new `toolRewrites` in `hosts/copilot.ts`
Add a copilot-specific `toolRewrites` mapping (factory.ts supports the pattern; copilot/opencode currently use none):

```ts
toolRewrites: {
  'Agent tool': 'task tool',            // Copilot CLI uses `task` subagents
  'the Agent tool': 'the `task` tool',
  'AskUserQuestion': 'ask the user inline',   // textual fallback
  'mcp__conductor__AskUserQuestion': 'ask the user inline',
}
```

This is body-text rewriting only — it would not need backend tool routing logic; it makes the model's prose-level instructions match Copilot CLI's actual tool surface.

### Needs runtime documentation additions
The marketplace `README.md` and `~/.copilot/skills/gstack/ETHOS.md` should call out:

1. **Optional external CLIs that unlock features**: `codex` (for autoplan/review/plan-*), `claude` (for `/claude` skill and `spec --execute`), `gh` (mostly assumed; document version requirements), `flyctl`/`vercel`/etc (for land-and-deploy depending on detected platform).
2. **Safety skills are advisory-only on Copilot CLI** — `careful`/`freeze`/`guard` do not block destructive commands; they only ask the agent to behave cautiously. Use a separate guardrail tool if hard enforcement is required.
3. **iOS skills require macOS host + Xcode + iPhone over USB** — not usable on Windows.
4. **gbrain skills (`setup-gbrain`, `sync-gbrain`)** are user-driven install paths; gbrain is not shipped pre-installed.

### Needs upstream gstack-copilot project fix (your fork)
1. Add `toolRewrites` and extended `skipSkills` to `hosts/copilot.ts` per above.
2. Fix the binary-extension probes in upstream gstack — these affect Copilot CLI on Windows but ALSO would affect any opencode-style Windows install. Worth pushing upstream.
3. Open a tracking issue: "Allowlist frontmatter mode silently strips `hooks:`; safety skills become advisory-only — generator should at minimum log a warning when a stripped field changes runtime behavior."
4. Consider a host-level `bodyRewrites` mechanism (in addition to `pathRewrites` and `toolRewrites`) so safety-skill bodies can be patched to match degraded enforcement.

---
*End of audit. 53 skills analyzed; 19 ship-as-is, 25 degraded-but-useful, 9 broken on Windows / Copilot CLI, 1 skipped.*
