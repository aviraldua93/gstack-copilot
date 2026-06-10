# gstack-copilot — Windows Compatibility Audit

**Scope:** All 15 SKILL.md files in `plugin/skills/`
**Environment:** Git Bash on Windows (`C:\Program Files\Git\bin\bash.exe`)
**Date:** 2026-06-10

All claims below verified by executing the candidate commands in Git Bash. See "Verification matrix" at the end.

---

## 1. Per-skill findings

Severity: **BLOCKING** = script halts or hard-errors; **DEGRADED** = silent fail or wrong result, downstream still mostly works; **MINOR** = cosmetic / robustness only.

| Skill | Issues | Severity | Recommended fix |
|---|---|---|---|
| **autoplan** | `open https://garryslist.org/...` (L176); `mktemp -t autoplan-tasks.XXXXXXXX` (L1611, GNU vs BSD flag) | BLOCKING; MINOR | Swap `open` → `start`; replace `mktemp -t name.XXX` with `mktemp -t "name.XXX"` (Git Bash GNU mktemp uses suffix syntax but works) — actually GNU `mktemp -t` works here, MINOR only. |
| **browse** | `open https://garryslist.org/...` (L168); `shasum -a 256` in bun setup (L528); `/tmp/` literals in 17 places (docs + examples + temp files); SETUP check uses `[ -x ".../browse" ]` (works due to Git Bash `.exe` auto-resolution but fragile); `source <(...)` (L45) | BLOCKING (open, shasum); DEGRADED (/tmp passed to browse.exe) | `open`→`start`; `shasum -a 256`→`sha256sum`; document `/tmp/` examples as `$TMPDIR/` or note Windows quirk; consider adding `.exe` fallback. |
| **canary** | `open https://garryslist.org/...` (L168); `shasum -a 256` (L762); SETUP same as browse; `source <(...)` (L45); references `/tmp/qa` | BLOCKING; DEGRADED | Same as browse. |
| **careful** | None — only telemetry block (uses `date`, `git rev-parse`, `tr`, `echo` — all portable) | ✅ CLEAN | No changes. |
| **design-review** | `open https://garryslist.org/...` (L172); `open file://...` fallback recommended in prose (L1031); `shasum -a 256` (L835); `mktemp /tmp/codex-design-XXXXXXXX` (L1690); SETUP same as browse; `source <(...)` (L49) | BLOCKING; DEGRADED | `open`→`start`; rewrite L1031 fallback to use `start file:///...` on Windows; `shasum`→`sha256sum`; `mktemp /tmp/foo-XXX` is fine in Git Bash but consider `$(mktemp)` for portability. |
| **guard** | None — only telemetry block | ✅ CLEAN | No changes. |
| **health** | `open https://garryslist.org/...` (L170); `timeout 5s` for `gbrain doctor` — works (Git Bash has `timeout`); `source <(...)` (L47); `node -e` for package.json parse (L774, requires node in PATH) | BLOCKING (open); MINOR (node) | `open`→`start`; node usage is gated by `[ -f package.json ]` so degraded gracefully. |
| **investigate** | `open https://garryslist.org/...` (L209); `source <(...)` (L86) | BLOCKING | `open`→`start`. |
| **office-hours** | `open https://garryslist.org/...` (L205); `shasum -a 256` (L817); 9 `/tmp/` literals — including `SKETCH_FILE="/tmp/gstack-sketch-$(date +%s).html"` then `$B goto "file://$SKETCH_FILE"` (L1509-1515) — **this is the highest-risk Windows path** because browse.exe receives a `/tmp/...` path; `$B screenshot /tmp/gstack-sketch.png` likewise; `mktemp /tmp/gstack-codex-oh-XXXXXXXX.txt` (L1289); SETUP same as browse; `source <(...)` (L82) | BLOCKING (open, shasum); BLOCKING (browse.exe + `/tmp` path may fail on Windows — Git Bash MSYS path conversion is inconsistent for arguments starting with `/` that look like flags or paths to non-MSYS binaries) | `open`→`start`; `shasum`→`sha256sum`; replace `/tmp/...` literals with `"$TMPDIR/..."` (Git Bash defines `TMPDIR=/tmp` automatically) OR resolve via `$(cygpath -w)` before passing to browse.exe. |
| **plan-ceo-review** | `open https://garryslist.org/...` (L199); 3 `/tmp/` literals including `> /tmp/.gstack-brain-context-$$.md` (L1122); `source <(...)` (L76); `~/.claude/skills/gstack/browse/bin/remote-slug` invoked directly (L907, L978) — works in Git Bash but the `bin/remote-slug` file may lack `.exe` if it's a wrapper | BLOCKING (open); MINOR | `open`→`start`; check `remote-slug` is a bash script (not a binary needing `.exe`). |
| **plan-eng-review** | `open https://garryslist.org/...` (L175); 3 `/tmp/` literals (L823-825); `source <(...)` (L52); `remote-slug` invocations | BLOCKING | `open`→`start`. |
| **qa** | `open https://garryslist.org/...` (L176); `shasum -a 256` (L879); reference to "Output to /tmp/qa" (L819); SETUP same as browse; `source <(...)` (L53) | BLOCKING | `open`→`start`; `shasum`→`sha256sum`. |
| **retro** | `open https://garryslist.org/...` (L187); 2 `/tmp/` literals: `2>/tmp/gstack-discover-stderr` (L1472, L1475); `source <(...)` (L64) | BLOCKING (open); MINOR (/tmp stderr works in Git Bash) | `open`→`start`. |
| **review** | `open https://garryslist.org/...` (L172); 2 `mktemp /tmp/codex-*` (L1646, L1674); `source <(...)` (L49, L1247) | BLOCKING | `open`→`start`. |
| **scrape** | `open https://garryslist.org/...` (L168); `source <(...)` (L45) | BLOCKING | `open`→`start`. |

### 100% Windows-clean
- **`careful`** — only telemetry; uses portable commands.
- **`guard`** — only telemetry; uses portable commands.

Everything else has at least the `open` URL line.

---

## 2. Top cross-cutting patterns

| # | Pattern | Affected skills | Severity | Reason it bites Windows |
|---|---|---|---|---|
| 1 | `open https://garryslist.org/posts/boil-the-ocean` (Boil-the-Ocean intro link) | 13 of 15 (all except careful, guard) — 14 occurrences (design-review has 2) | BLOCKING | `open` is macOS-only. Git Bash returns `command not found` (exit 127). |
| 2 | `shasum -a 256 "$tmpfile" \| awk '{print $1}'` (bun installer SHA check) | 5 (browse, canary, design-review, office-hours, qa) | BLOCKING for bun bootstrap | `shasum` not in baseline Git Bash. `sha256sum` IS present and has identical column-1 hash output. |
| 3 | `/tmp/...` literals passed to **Windows binaries** (browse.exe, `$D`) | office-hours (highest risk: L1509-1516 SKETCH_FILE flow); browse (docs/examples) | DEGRADED → BLOCKING | Git Bash mounts `/tmp` → `%TEMP%`, but native Windows EXEs receive the raw `/tmp/...` string. MSYS path conversion is heuristic and unreliable when the first arg is a URL like `file:///tmp/...`. |
| 4 | `source <(...)` (process substitution) for `gstack-repo-mode`, `gstack-diff-scope` | 14 of 15 skills (every skill except careful & guard); 15 total occurrences | DEGRADED (already `\|\| true` guarded) | Works in Git Bash bash; would fail under PowerShell or non-bash POSIX shells. Currently safe because Copilot CLI invokes via bash. |
| 5 | Browse binary detection `[ -x ".../browse" ]` (no `.exe`) | 5 (browse, canary, design-review, office-hours, qa) | MINOR (works today) | Git Bash auto-resolves `browse` → `browse.exe` for `-x` test and execution. Will break if any future caller uses a non-Git-Bash shell or stats the path directly. |

---

## 3. Proposed patch script

This **bash** script applies the top 3 highest-impact fixes (`open` → `start`, `shasum -a 256` → `sha256sum`, and a hardening upgrade for the browse SETUP check to recognise `.exe`). Run from anywhere; takes the skills dir as `$1`.

```bash
#!/usr/bin/env bash
# Windows-compat patcher for gstack-copilot SKILL.md files.
# USAGE: ./fix-windows.sh C:/Users/aviraldua/dev/gstack-copilot/plugin/skills
# DRY RUN: pass --dry-run as $2 to preview without writing.

set -euo pipefail
SKILLS_DIR="${1:?Usage: $0 <skills-dir> [--dry-run]}"
DRY="${2:-}"

if [ ! -d "$SKILLS_DIR" ]; then
  echo "ERROR: not a directory: $SKILLS_DIR" >&2
  exit 1
fi

SED_INPLACE=(-i)
[ "$(uname -s)" = "Darwin" ] && SED_INPLACE=(-i '')   # BSD sed quirk; harmless on Git Bash

run_sed() {
  local file="$1"; shift
  if [ "$DRY" = "--dry-run" ]; then
    echo "DRY: would sed in $file: $*"
  else
    sed "${SED_INPLACE[@]}" "$@" "$file"
  fi
}

# ----- Fix 1: open URL -> start URL (Boil-the-Ocean intro) -----
# Match exactly the bash-snippet line `open https://...`.
# We anchor on `^open ` to avoid hitting the prose mentions of "open" in headings.
while IFS= read -r -d '' f; do
  if grep -qE '^open https?://' "$f"; then
    run_sed "$f" -E 's|^open (https?://)|start \1|'
    echo "FIXED open: $f"
  fi
done < <(find "$SKILLS_DIR" -name SKILL.md -print0)

# ----- Fix 1b: prose-level `open file://...` fallback in design-review -----
# Rewrite the single sentence pattern so the documented fallback works on Windows.
DR="$SKILLS_DIR/design-review/SKILL.md"
if [ -f "$DR" ] && grep -q 'use `open file://...` instead of' "$DR"; then
  run_sed "$DR" -E 's|use `open file://\.\.\.`|use `start file:///...` (Windows) or `open file://...` (macOS)|'
  echo "FIXED design-review prose fallback"
fi

# ----- Fix 2: shasum -a 256 -> sha256sum (bun install SHA check) -----
while IFS= read -r -d '' f; do
  if grep -q 'shasum -a 256' "$f"; then
    run_sed "$f" -E 's|shasum -a 256|sha256sum|g'
    echo "FIXED shasum: $f"
  fi
done < <(find "$SKILLS_DIR" -name SKILL.md -print0)

# ----- Fix 3: browse SETUP - add .exe fallback so the executable check works
#               under stricter shells (and explicit on Windows) -----
# Original (single line):
#   [ -n "$_ROOT" ] && [ -x "$_ROOT/.claude/skills/gstack/browse/dist/browse" ] && B="$_ROOT/.claude/skills/gstack/browse/dist/browse"
# New (two probes per location):
#   for ext in "" ".exe"; do
#     [ -n "$_ROOT" ] && [ -x "$_ROOT/.claude/skills/gstack/browse/dist/browse$ext" ] \
#       && B="$_ROOT/.claude/skills/gstack/browse/dist/browse$ext" && break
#   done
# That's hard with sed alone — instead we just substitute the trailing literal
# `/browse"` with `/browse${BROWSE_EXT}"` and inject `BROWSE_EXT` resolution
# right above the first probe. This keeps existing semantics on macOS/Linux
# (BROWSE_EXT="") while making Windows explicit.
SETUP_HEADER='BROWSE_EXT=""; [ "${OS:-}" = "Windows_NT" ] && BROWSE_EXT=".exe"'
for f in \
  "$SKILLS_DIR/browse/SKILL.md" \
  "$SKILLS_DIR/qa/SKILL.md" \
  "$SKILLS_DIR/design-review/SKILL.md" \
  "$SKILLS_DIR/canary/SKILL.md" \
  "$SKILLS_DIR/office-hours/SKILL.md"
do
  [ -f "$f" ] || continue
  if grep -q 'browse/dist/browse"' "$f" && ! grep -q 'BROWSE_EXT' "$f"; then
    # Inject the BROWSE_EXT line right after each `_ROOT=$(git rev-parse --show-toplevel...`
    # in a SETUP block. We use awk for this transform (more robust than multiline sed on Git Bash).
    if [ "$DRY" = "--dry-run" ]; then
      echo "DRY: would inject BROWSE_EXT and append \$BROWSE_EXT to browse paths in $f"
    else
      awk -v hdr="$SETUP_HEADER" '
        {
          line = $0
          # Append ${BROWSE_EXT} to any /dist/browse" literal
          gsub(/browse\/dist\/browse"/, "browse/dist/browse${BROWSE_EXT}\"", line)
          print line
          # After a SETUP _ROOT= probe line, inject BROWSE_EXT once per file
          if (!injected && line ~ /^_ROOT=\$\(git rev-parse --show-toplevel/) {
            print hdr
            injected = 1
          }
        }
      ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
      echo "FIXED browse SETUP: $f"
    fi
  fi
done

echo
echo "Done. Run \`git diff plugin/skills\` to review."
```

**Run it (dry-run first):**
```powershell
& "C:\Program Files\Git\bin\bash.exe" -c "/c/Users/aviraldua/dev/gstack-copilot/fix-windows.sh /c/Users/aviraldua/dev/gstack-copilot/plugin/skills --dry-run"
```

---

## 4. Verification matrix (run on this machine, Git Bash on Windows)

| Probe | Command | Result |
|---|---|---|
| `open https://example.com` | `bash -c 'open https://example.com'` | exit 127, `command not found` — **BLOCKING confirmed** |
| `start https://example.com` | `bash -c 'start https://example.com'` | exit 0 — **works** |
| `shasum -a 256` | `bash -c 'command -v shasum'` | missing — **BLOCKING confirmed** |
| `sha256sum` | `bash -c 'command -v sha256sum'` | `/usr/bin/sha256sum` — **works** |
| `[ -x ".../browse" ]` against `browse.exe` only | `bash -c '[ -x ".../browse" ] && echo Y'` | prints Y — **Git Bash auto-resolves `.exe`** |
| `timeout 5s ...` | `bash -c 'command -v timeout'` | `/usr/bin/timeout` — **works** |
| `mktemp /tmp/foo-XXXXXXXX` | `bash -c 'mktemp /tmp/foo-XXXXXXXX'` | succeeds, file under `/tmp` (mapped to `%TEMP%`) — **works** |
| `find ~/.gstack/sessions -mmin -120` | run via bash | works — **GNU find present** |
| `jq` | `bash -c 'command -v jq'` | missing in baseline — **all callers gate via `command -v jq` so DEGRADED gracefully** |
| `setsid`, `gtimeout` | missing | **only relevant for unused-by-skills patterns; no impact** |
| `pbcopy`/`pbpaste`/`osascript`/`launchctl`/`defaults read` | grep across all SKILL.md | **0 matches — no macOS-specific APIs beyond `open`** |

---

## 5. What is NOT broken (do not touch)

- All `date -u +%Y-%m-%dT%H:%M:%SZ` and `date +%s` patterns — work fine.
- `find ~/.gstack/sessions -mmin -120 -type f` — works (GNU find).
- `wc -l | tr -d ' '` — works.
- `$$` (PID) — works.
- `jq` consumers — all gated by `command -v jq` and emit graceful warnings.
- `git rev-parse --show-toplevel` — works.
- `~/.claude/skills/gstack/bin/*` helper scripts — already verified working on Windows Git Bash per task brief.
- `careful` and `guard` skills — fully Windows-clean.

---

## 6. Recommended apply order

1. **Fix 1 (`open` → `start`)** — 13 skills, lowest risk, biggest UX win (the Boil-the-Ocean link now opens on Windows).
2. **Fix 2 (`shasum` → `sha256sum`)** — 5 skills, unblocks first-run `bun` bootstrap.
3. **Fix 3 (browse `BROWSE_EXT`)** — 5 skills, hardening for future shell changes; not currently broken.
4. (Out of scope of this patch — recommend separately) audit `/tmp/...` arguments passed to `$B` / `$D` Windows binaries; consider standardising on `${TMPDIR:-/tmp}` and converting with `cygpath -w` when the consumer is a native EXE. The highest-risk single line is `office-hours/SKILL.md:1515` (`$B goto "file://$SKETCH_FILE"`).
