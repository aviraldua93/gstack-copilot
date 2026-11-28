---
name: freeze
description: |
  Restrict file edits to a specific directory for the session. Blocks Edit,
  Write and NotebookEdit outside the allowed path. Use when debugging to prevent accidentally
  "fixing" unrelated code, or when you want to scope changes to one module.
  Use when asked to "freeze", "restrict edits", "only edit this folder",
  or "lock down edits". (gstack)
---
<!-- AUTO-GENERATED from SKILL.md.tmpl — do not edit directly -->
<!-- Regenerate: bun run gen:skill-docs -->
> **Safety Advisory — not enforced on GitHub Copilot CLI:** advisory, not blocked. GitHub Copilot CLI runs no gstack safety hooks, so nothing stops a command automatically. On Claude Code this skill's hooks verify file edits are within the allowed scope boundary before applying, and verify file writes are within the allowed scope boundary before applying, and check NotebookEdit operations for safety; here, do those checks yourself: always pause and verify before executing potentially destructive operations. If uncertain about a command's safety, ask the user for confirmation before proceeding.


# /freeze — Restrict Edits to a Directory

Lock file edits to a specific directory. Any Edit, Write or NotebookEdit
operation targeting a file outside the allowed path will be **blocked** (not
just warned).

```bash
GSTACK_STATE_ROOT=$(~/.copilot/skills/gstack/bin/gstack-paths --get GSTACK_STATE_ROOT); : "${GSTACK_STATE_ROOT:?gstack-paths failed; reinstall with ./setup or /gstack-upgrade}"
mkdir -p "$GSTACK_STATE_ROOT"/analytics
echo '{"skill":"freeze","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","repo":"'$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")'"}'  >> "$GSTACK_STATE_ROOT"/analytics/skill-usage.jsonl 2>/dev/null || true
```

## Setup

Ask the user which directory to restrict edits to. Use AskUserQuestion:

- Question: "Which directory should I restrict edits to? Files outside this path will be blocked from editing."
- Text input (not multiple choice) — the user types a path.

Once the user provides a directory path:

Set the user-selected boundary with the shared state writer. It resolves the physical absolute path and serializes replacement with investigation cleanup:
```bash
[ -d "${GSTACK_ROOT:-/-}/bin" ]&&[ -d "$GSTACK_ROOT/lib" ]||{ _r=$(git rev-parse --show-toplevel 2>/dev/null)/.copilot/skills/gstack;[ -d "$_r/bin" ]||_r=~/.copilot/skills/gstack;[ -d "$_r/bin" ]||{ echo "gstack: no install found (tried $_r). Fix: ./setup --host copilot from your gstack checkout; ./setup --status shows it.">&2;exit 1;};GSTACK_ROOT=$_r;}
bash "$GSTACK_ROOT/freeze/bin/freeze-state.sh" set "<user-provided-path>"
```

Only report success if the helper succeeds. On `FREEZE_BUSY` or unexpected state, preserve it and ask the user to inspect recovery after any active writer finishes; never write or delete the state file directly.

Tell the user: "Edits are now restricted to `<path>/`. Any Edit, Write or
NotebookEdit outside this directory will be blocked. To change the boundary, run `/freeze`
again. To remove it, run `/unfreeze`."

## How it works

The hook reads `file_path` from the Edit/Write tool input JSON, or
`notebook_path` from a NotebookEdit (Jupyter notebook) call (shared
real-JSON extractor with /careful — one copy, sourced by both hooks), then
checks whether the path starts with the freeze directory. If not, it returns a
`hookSpecificOutput` payload with `permissionDecision: "deny"` to block the
operation (nested under `hookSpecificOutput` — Claude Code ignores a top-level
`permissionDecision`).

Polarity is fail-closed: a tool payload the hook cannot parse is DENIED, not
allowed — a boundary that fails open is not a boundary. A payload that parses
but has neither path field (a non-file tool) is allowed. A deny names the
tool, the path field, the boundary and `/unfreeze`. The path is resolved before
the check: `~`, `..` and relative paths, and symlinks at every depth, even
through folders that do not exist yet. A path the hook cannot place (a symlink
loop, a line break, a Windows drive-relative path, over 4096 characters) is
denied.

The freeze boundary persists until explicitly removed via the state file. The hook
script reads it on every Edit/Write/NotebookEdit invocation. Boundaries containing spaces
are supported.

## Notes

- The trailing `/` on the freeze directory prevents `/src` from matching `/src-old`
- Freeze applies to Edit, Write and NotebookEdit only — Read, Bash, PowerShell, Glob, Grep are unaffected
- This prevents accidental edits, not a security boundary — Bash or PowerShell commands like `sed` or `Set-Content` can still modify files outside the boundary
- To deactivate, run `/unfreeze`; ending or killing a conversation does not remove persisted state
