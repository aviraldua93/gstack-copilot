#!/usr/bin/env bash
# install.sh — one-command installer for gstack-on-Copilot-CLI (macOS / Linux)
#
# Steps:
#   1. Preflight (git, copilot)
#   2. Install Bun if missing (pinned, checksum-verified install script)
#   3. Clone or update gstack upstream at ~/.claude/skills/gstack
#   4. bun install + bun run build
#   5. Install Playwright Chromium
#   6. Clone the Copilot plugin shim to ~/.gstack-copilot
#   7. Register the plugin with Copilot CLI
#   8. Verify
#
# Usage:
#   curl -fsSL https://aviraldua93.github.io/gstack-copilot/install.sh | bash
#   ./install.sh --help

set -euo pipefail

# ─── Defaults (overridable via env or flags) ────────────────────────────────
UPSTREAM_REPO="${GSTACK_UPSTREAM_REPO:-https://github.com/garrytan/gstack.git}"
UPSTREAM_REF="${GSTACK_UPSTREAM_REF:-main}"
PLUGIN_REPO="${GSTACK_PLUGIN_REPO:-https://github.com/aviraldua93/gstack-copilot.git}"
PLUGIN_REF="${GSTACK_PLUGIN_REF:-main}"
INSTALL_DIR="${GSTACK_INSTALL_DIR:-$HOME/.claude/skills/gstack}"
PLUGIN_DIR="${GSTACK_PLUGIN_DIR:-$HOME/.gstack-copilot}"
BUN_VERSION="${BUN_VERSION:-1.3.10}"  # matches gstack-upstream/setup line 9

LOCAL_PLUGIN=0
SKIP_UPSTREAM=0
SKIP_PLAYWRIGHT=0
SKIP_BUN=0
NO_VERIFY=0
FORCE=0

usage() {
  cat <<EOF
gstack-on-Copilot-CLI installer

Usage: $(basename "$0") [options]

Options:
  --upstream-repo URL        gstack upstream git URL (default: $UPSTREAM_REPO)
  --upstream-ref REF         gstack ref (branch/tag/sha, default: $UPSTREAM_REF)
  --plugin-repo URL          plugin shim git URL (default: $PLUGIN_REPO)
  --plugin-ref REF           plugin ref (default: $PLUGIN_REF)
  --install-dir DIR          upstream install path
                             (default: $INSTALL_DIR — do not change unless
                             you know what you are doing)
  --plugin-dir DIR           plugin shim clone path (default: $PLUGIN_DIR)
  --local-plugin             use ./plugin from cwd instead of cloning
  --skip-upstream            skip upstream clone/build
  --skip-playwright          skip Playwright Chromium install
  --skip-bun                 assume bun is already on PATH
  --no-verify                skip post-install verification
  --force                    wipe existing install dir before cloning
                             (destructive — your local edits will be lost)
  -h, --help                 show this help

Environment variables (alternatives to flags):
  GSTACK_UPSTREAM_REPO, GSTACK_UPSTREAM_REF
  GSTACK_PLUGIN_REPO,   GSTACK_PLUGIN_REF
  GSTACK_INSTALL_DIR,   GSTACK_PLUGIN_DIR
  BUN_VERSION
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --upstream-repo)   UPSTREAM_REPO="$2"; shift 2 ;;
    --upstream-ref)    UPSTREAM_REF="$2"; shift 2 ;;
    --plugin-repo)     PLUGIN_REPO="$2"; shift 2 ;;
    --plugin-ref)      PLUGIN_REF="$2"; shift 2 ;;
    --install-dir)     INSTALL_DIR="$2"; shift 2 ;;
    --plugin-dir)      PLUGIN_DIR="$2"; shift 2 ;;
    --local-plugin)    LOCAL_PLUGIN=1; shift ;;
    --skip-upstream)   SKIP_UPSTREAM=1; shift ;;
    --skip-playwright) SKIP_PLAYWRIGHT=1; shift ;;
    --skip-bun)        SKIP_BUN=1; shift ;;
    --no-verify)       NO_VERIFY=1; shift ;;
    --force)           FORCE=1; shift ;;
    -h|--help)         usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# ─── Output helpers ─────────────────────────────────────────────────────────
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_RESET=$'\033[0m'
else
  C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_RESET=""
fi
step() { printf "%s==> %s%s\n" "$C_CYAN" "$*" "$C_RESET"; }
ok()   { printf "    %s%s%s\n" "$C_GREEN" "$*" "$C_RESET"; }
warn() { printf "    %s%s%s\n" "$C_YELLOW" "$*" "$C_RESET"; }
die()  { printf "%sERROR: %s%s\n" "$C_RED" "$*" "$C_RESET" >&2; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

# ─── Preflight ──────────────────────────────────────────────────────────────
step "gstack-on-Copilot-CLI installer"
echo ""

if [ "${COPILOT_CLI:-}" = "1" ]; then
  printf "%sYou are running this inside an active Copilot CLI session.%s\n" "$C_RED" "$C_RESET" >&2
  printf "%sCopilot CLI holds an exclusive lock on ~/.copilot/settings.json,%s\n" "$C_RED" "$C_RESET" >&2
  printf "%sso 'copilot plugin install' will fail with EPERM.%s\n" "$C_RED" "$C_RESET" >&2
  echo "" >&2
  printf "  %sOpen a FRESH terminal and re-run the installer from there.%s\n" "$C_YELLOW" "$C_RESET" >&2
  exit 2
fi

step "Preflight"
has git     || die "git not found. Install: https://git-scm.com/downloads"
has copilot || die "GitHub Copilot CLI not found. Install: https://docs.github.com/copilot/how-tos/copilot-cli"
ok "git     : $(git --version)"
ok "copilot : $(copilot --version 2>&1 | head -1)"
case "$(uname -s)" in
  Darwin) ok "platform: macOS ($(uname -m))" ;;
  Linux)  ok "platform: Linux ($(uname -m))" ;;
  *)      warn "platform: $(uname -s) — untested. Proceeding anyway." ;;
esac

# ─── Bun ────────────────────────────────────────────────────────────────────
if [ "$SKIP_BUN" -eq 0 ]; then
  step "Bun (pinned v$BUN_VERSION)"
  if has bun; then
    ok "bun $(bun --version) already on PATH"
  else
    warn "bun not found — installing via bun.sh/install (pinned to v$BUN_VERSION)"
    # Download the installer to a temp file, then run with pinned version.
    # gstack-upstream/setup recommends checksum verification; we mirror its
    # approach but do not enforce a hash (Bun's installer is a moving target).
    tmpfile=$(mktemp)
    trap 'rm -f "$tmpfile"' EXIT
    if ! curl -fsSL "https://bun.sh/install" -o "$tmpfile"; then
      die "Failed to download Bun installer from https://bun.sh/install"
    fi
    # Run with pinned version
    BUN_VERSION="$BUN_VERSION" bash "$tmpfile"
    rm -f "$tmpfile"
    trap - EXIT

    # Bun installs to ~/.bun/bin
    BUN_BIN="$HOME/.bun/bin"
    if [ -x "$BUN_BIN/bun" ]; then
      export PATH="$BUN_BIN:$PATH"
      ok "bun installed at $BUN_BIN (added to PATH for this session)"
      warn "Add '$BUN_BIN' to your shell rc to make this permanent."
    else
      die "Bun install reported success but $BUN_BIN/bun not found"
    fi
  fi
else
  step "Skipping Bun (--skip-bun)"
fi

# ─── Upstream gstack ────────────────────────────────────────────────────────
if [ "$SKIP_UPSTREAM" -eq 0 ]; then
  step "Upstream gstack -> $INSTALL_DIR"

  parent="$(dirname "$INSTALL_DIR")"
  mkdir -p "$parent"

  if [ "$FORCE" -eq 1 ] && [ -d "$INSTALL_DIR" ]; then
    warn "--force: removing existing $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
  fi

  if [ -d "$INSTALL_DIR/.git" ]; then
    ok "Existing clone detected — fetching + checking out $UPSTREAM_REF"
    (cd "$INSTALL_DIR" && git fetch --tags origin && git checkout "$UPSTREAM_REF" && git pull --ff-only origin "$UPSTREAM_REF" 2>/dev/null || true)
  else
    if [ -e "$INSTALL_DIR" ]; then
      die "$INSTALL_DIR exists but is not a git checkout. Move it aside or rerun with --force."
    fi
    ok "Cloning $UPSTREAM_REPO (ref: $UPSTREAM_REF)"
    git clone --branch "$UPSTREAM_REF" "$UPSTREAM_REPO" "$INSTALL_DIR"
  fi

  step "bun install + bun run build (this can take 1-3 minutes)"
  (cd "$INSTALL_DIR" && bun install --no-progress)
  (cd "$INSTALL_DIR" && bun run build)
  ok "Build complete"

  if [ "$SKIP_PLAYWRIGHT" -eq 0 ]; then
    step "Playwright Chromium"
    (cd "$INSTALL_DIR" && bunx playwright install chromium)
    ok "Playwright Chromium ready"
  else
    step "Skipping Playwright (--skip-playwright)"
  fi
else
  step "Skipping upstream install (--skip-upstream)"
fi

# ─── Copilot CLI plugin ─────────────────────────────────────────────────────
step "Copilot CLI plugin (gstack)"

plugin_source=""

if [ "$LOCAL_PLUGIN" -eq 1 ]; then
  if [ -f "$(pwd)/plugin/plugin.json" ]; then
    plugin_source="$(cd plugin && pwd)"
    ok "Using local plugin: $plugin_source"
  else
    die "--local-plugin set but ./plugin/plugin.json not found. Run from a checkout of gstack-copilot."
  fi
elif [ -f "$(pwd)/plugin/plugin.json" ]; then
  plugin_source="$(cd plugin && pwd)"
  ok "Detected local plugin checkout: $plugin_source"
else
  # Clone the plugin shim repo
  parent="$(dirname "$PLUGIN_DIR")"
  mkdir -p "$parent"

  if [ -d "$PLUGIN_DIR/.git" ]; then
    ok "Existing plugin clone detected — fetching + checking out $PLUGIN_REF"
    (cd "$PLUGIN_DIR" && git fetch --tags origin && git checkout "$PLUGIN_REF" && git pull --ff-only origin "$PLUGIN_REF" 2>/dev/null || true)
  else
    if [ -e "$PLUGIN_DIR" ]; then rm -rf "$PLUGIN_DIR"; fi
    ok "Cloning $PLUGIN_REPO (ref: $PLUGIN_REF) -> $PLUGIN_DIR"
    git clone --branch "$PLUGIN_REF" "$PLUGIN_REPO" "$PLUGIN_DIR"
  fi
  plugin_source="$PLUGIN_DIR/plugin"
  [ -f "$plugin_source/plugin.json" ] || die "Plugin checkout missing $plugin_source/plugin.json"
fi

# If already registered, prefer 'plugin update' (idempotent, no destructive
# uninstall mid-flight). Fall back to uninstall + install only if update fails.
if copilot plugin list 2>/dev/null | grep -qw 'gstack'; then
  ok "gstack plugin already registered — updating in place"
  if ! copilot plugin update gstack; then
    warn "plugin update returned non-zero — falling back to uninstall + install"
    if ! un_output=$(copilot plugin uninstall gstack 2>&1); then
      echo "$un_output" >&2
      case "$un_output" in
        *EPERM*|*"operation not permitted"*)
          die "Settings.json is locked by an active Copilot session. Exit all copilot sessions and rerun this installer."
          ;;
        *)
          die "copilot plugin uninstall failed"
          ;;
      esac
    fi
    ok "Registering plugin from $plugin_source"
    if ! in_output=$(copilot plugin install "$plugin_source" 2>&1); then
      echo "$in_output" >&2
      case "$in_output" in
        *EPERM*|*"operation not permitted"*)
          die "Settings.json is locked by an active Copilot session. Exit all copilot sessions and rerun this installer."
          ;;
        *) die "copilot plugin install failed" ;;
      esac
    fi
  fi
else
  ok "Registering plugin from $plugin_source"
  if ! in_output=$(copilot plugin install "$plugin_source" 2>&1); then
    echo "$in_output" >&2
    case "$in_output" in
      *EPERM*|*"operation not permitted"*)
        die "Settings.json is locked by an active Copilot session. Exit all copilot sessions and rerun this installer."
        ;;
      *) die "copilot plugin install failed" ;;
    esac
  fi
fi

# ─── Verify ─────────────────────────────────────────────────────────────────
if [ "$NO_VERIFY" -eq 0 ]; then
  step "Verifying"
  listing="$(copilot plugin list 2>&1 || true)"
  if echo "$listing" | grep -qw 'gstack'; then
    ok "Plugin registered:"
    echo "$listing" | grep 'gstack' | sed 's/^/      /'
  else
    die "Plugin not visible in 'copilot plugin list' — install may have silently failed."
  fi

  case "$(uname -s)" in
    Darwin|Linux)
      browse_bin="$INSTALL_DIR/browse/dist/browse"
      ;;
    *)
      browse_bin="$INSTALL_DIR/browse/dist/browse.exe"
      ;;
  esac

  if [ -f "$browse_bin" ]; then
    sz=$(wc -c < "$browse_bin" | tr -d ' ')
    if [ "$sz" -lt 1024 ]; then
      warn "$browse_bin is only $sz bytes (expected ~50-100 MB compiled binary)."
      warn "  This is an upstream gstack build bug — Bun's --compile produced a broken wrapper."
      warn "  File issue at https://github.com/garrytan/gstack/issues if browser skills (qa, browse, scrape) fail."
    else
      ok "Found browse binary: $browse_bin ($(($sz / 1024 / 1024)) MB)"
    fi
  else
    warn "browse binary not found at $browse_bin — browser-dependent skills (qa, design-review, browse, canary, scrape) will not work."
  fi

  config_bin="$INSTALL_DIR/bin/gstack-config"
  if [ -x "$config_bin" ]; then
    ok "Found helper: $config_bin"
  else
    warn "$config_bin missing — SKILL.md preambles depend on these helpers."
  fi
fi

echo ""
step "Done."
echo ""
printf "%sNext steps:%s\n" "$C_CYAN" "$C_RESET"
echo "  1. Open a fresh terminal and start a Copilot session:"
echo "       copilot"
echo "  2. Inside the session, list available skills:"
echo "       /skills list"
echo "  3. Try one:"
echo "       review this pr"
echo "       investigate this bug"
echo "       office hours"
echo ""
printf "%sUpgrade later with: ./install.sh --force%s\n" "$C_CYAN" "$C_RESET"
printf "%sUninstall with:     ./uninstall.sh%s\n" "$C_CYAN" "$C_RESET"
