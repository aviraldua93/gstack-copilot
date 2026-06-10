#!/usr/bin/env bash
# uninstall.sh — reverse install.sh for gstack-on-Copilot-CLI
#
# By default removes:
#   - the Copilot CLI plugin registration ('gstack')
#   - ~/.claude/skills/gstack       (upstream)
#   - ~/.gstack-copilot             (plugin shim clone)
#
# Optional flags:
#   --keep-upstream        keep ~/.claude/skills/gstack
#   --keep-plugin-clone    keep ~/.gstack-copilot
#   --purge-bun            also remove ~/.bun (other tools may use it)
#   --purge-user-state     also remove ~/.gstack and ~/.gstack-dev
#                          (DESTRUCTIVE — your projects, decisions, learnings,
#                           session history, model caches)
#   --install-dir DIR      override upstream path
#   --plugin-dir DIR       override plugin shim path
#   -y, --yes              skip confirmation prompt

set -euo pipefail

INSTALL_DIR="${GSTACK_INSTALL_DIR:-$HOME/.claude/skills/gstack}"
PLUGIN_DIR="${GSTACK_PLUGIN_DIR:-$HOME/.gstack-copilot}"
KEEP_UPSTREAM=0
KEEP_PLUGIN_CLONE=0
PURGE_BUN=0
PURGE_USER_STATE=0
YES=0

usage() {
  cat <<EOF
gstack-on-Copilot-CLI uninstaller

Usage: $(basename "$0") [options]

Options:
  --keep-upstream        keep $INSTALL_DIR
  --keep-plugin-clone    keep $PLUGIN_DIR
  --purge-bun            also remove ~/.bun
  --purge-user-state     also remove ~/.gstack and ~/.gstack-dev (DESTRUCTIVE)
  --install-dir DIR      override upstream path
  --plugin-dir DIR       override plugin shim path
  -y, --yes              skip confirmation
  -h, --help             show this help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --keep-upstream)     KEEP_UPSTREAM=1; shift ;;
    --keep-plugin-clone) KEEP_PLUGIN_CLONE=1; shift ;;
    --purge-bun)         PURGE_BUN=1; shift ;;
    --purge-user-state)  PURGE_USER_STATE=1; shift ;;
    --install-dir)       INSTALL_DIR="$2"; shift 2 ;;
    --plugin-dir)        PLUGIN_DIR="$2"; shift 2 ;;
    -y|--yes)            YES=1; shift ;;
    -h|--help)           usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_RESET=$'\033[0m'
else
  C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_RESET=""
fi
step() { printf "%s==> %s%s\n" "$C_CYAN" "$*" "$C_RESET"; }
ok()   { printf "    %s%s%s\n" "$C_GREEN" "$*" "$C_RESET"; }
warn() { printf "    %s%s%s\n" "$C_YELLOW" "$*" "$C_RESET"; }

if [ "${COPILOT_CLI:-}" = "1" ]; then
  printf "%sYou are running this inside an active Copilot CLI session.%s\n" "$C_RED" "$C_RESET" >&2
  printf "%sExit the session and re-run uninstall.sh from a fresh terminal.%s\n" "$C_RED" "$C_RESET" >&2
  exit 2
fi

step "gstack uninstaller"
echo ""
echo "The following will be removed:"
echo "  - Copilot CLI plugin registration: gstack"
[ "$KEEP_UPSTREAM" -eq 0 ]     && echo "  - Upstream gstack:    $INSTALL_DIR"
[ "$KEEP_PLUGIN_CLONE" -eq 0 ] && echo "  - Plugin shim clone:  $PLUGIN_DIR"
[ "$PURGE_BUN" -eq 1 ]         && echo "  - Bun runtime:        $HOME/.bun"
if [ "$PURGE_USER_STATE" -eq 1 ]; then
  printf "  %s- User state (DESTRUCTIVE):%s\n" "$C_RED" "$C_RESET"
  printf "      %s%s/.gstack%s\n"     "$C_RED" "$HOME" "$C_RESET"
  printf "      %s%s/.gstack-dev%s\n" "$C_RED" "$HOME" "$C_RESET"
fi
echo ""

if [ "$YES" -eq 0 ]; then
  printf "Proceed? [y/N] "
  read -r resp
  case "$resp" in y|Y) ;; *) echo "Aborted."; exit 0 ;; esac
fi

# ─── Unregister plugin ──────────────────────────────────────────────────────
step "Unregistering Copilot CLI plugin"
if command -v copilot >/dev/null 2>&1; then
  if copilot plugin list 2>/dev/null | grep -qw 'gstack'; then
    if copilot plugin uninstall gstack; then
      ok "Plugin unregistered"
    else
      warn "copilot plugin uninstall returned non-zero. Continuing."
    fi
  else
    warn "Plugin 'gstack' not registered (skipping)"
  fi
else
  warn "copilot CLI not on PATH (skipping plugin unregister)"
fi

# ─── Remove upstream ────────────────────────────────────────────────────────
if [ "$KEEP_UPSTREAM" -eq 0 ]; then
  step "Removing upstream gstack"
  if [ -e "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    ok "Removed $INSTALL_DIR"
  else
    warn "$INSTALL_DIR not present (skipping)"
  fi
fi

# ─── Remove plugin clone ────────────────────────────────────────────────────
if [ "$KEEP_PLUGIN_CLONE" -eq 0 ]; then
  step "Removing plugin shim clone"
  if [ -e "$PLUGIN_DIR" ]; then
    rm -rf "$PLUGIN_DIR"
    ok "Removed $PLUGIN_DIR"
  else
    warn "$PLUGIN_DIR not present (skipping)"
  fi
fi

# ─── Optional: Bun ──────────────────────────────────────────────────────────
if [ "$PURGE_BUN" -eq 1 ]; then
  step "Removing Bun runtime"
  if [ -e "$HOME/.bun" ]; then
    rm -rf "$HOME/.bun"
    ok "Removed $HOME/.bun"
  else
    warn "$HOME/.bun not present (skipping)"
  fi
fi

# ─── Optional: user state ───────────────────────────────────────────────────
if [ "$PURGE_USER_STATE" -eq 1 ]; then
  step "Removing user state (destructive)"
  for d in "$HOME/.gstack" "$HOME/.gstack-dev"; do
    if [ -e "$d" ]; then
      rm -rf "$d"
      ok "Removed $d"
    else
      warn "$d not present (skipping)"
    fi
  done
fi

echo ""
step "Done."
echo ""
echo "Verification:"
echo "  copilot plugin list   # should no longer show 'gstack'"
