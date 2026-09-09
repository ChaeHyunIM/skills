#!/usr/bin/env bash
# Reports what `verify` needs in this repo and on this machine, with the fix for each missing piece.
#
#   usage: check-env.sh [--install-config] [--strict]
#
#   --install-config  copy templates/playwright.config.ts and the e2e tsconfig into the repo (never
#                     overwrites) and add `.e2e/` to .gitignore
#   --strict          exit 1 when a piece required for web flows is missing
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
INSTALL=0; STRICT=0
for a in "$@"; do case "$a" in --install-config) INSTALL=1;; --strict) STRICT=1;; esac; done

missing=0
ok()   { printf 'OK    %-28s %s\n' "$1" "${2:-}"; }
miss() { printf 'MISS  %-28s %s\n' "$1" "$2"; missing=$((missing+1)); }
info() { printf 'INFO  %-28s %s\n' "$1" "${2:-}"; }
ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

echo "repo: $ROOT"; echo

command -v pnpm >/dev/null && ok pnpm "$(pnpm --version)" || miss pnpm "install pnpm"
command -v node >/dev/null && ok node "$(node --version)" || miss node "install node"

if node -e 'const p=require(process.argv[1]);process.exit((p.devDependencies||{})["@playwright/test"]?0:1)' "$ROOT/package.json" 2>/dev/null; then
  ok "@playwright/test" "$(cd "$ROOT" && pnpm exec playwright --version 2>/dev/null | head -1)"
else
  miss "@playwright/test" "pnpm add -Dw @playwright/test && pnpm exec playwright install chromium"
fi

cache="$HOME/Library/Caches/ms-playwright"; [ -d "$cache" ] || cache="$HOME/.cache/ms-playwright"
if ls "$cache" 2>/dev/null | grep -q '^chromium'; then ok "chromium (playwright)" "$cache"; else miss "chromium (playwright)" "pnpm exec playwright install chromium"; fi

if [ -f "$ROOT/playwright.config.ts" ]; then ok playwright.config.ts; else
  if [ "$INSTALL" = 1 ]; then cp "$SKILL_DIR/templates/playwright.config.ts" "$ROOT/playwright.config.ts" && ok playwright.config.ts "installed from template"; else miss playwright.config.ts "check-env.sh --install-config"; fi
fi

if grep -qxF '.e2e/' "$ROOT/.gitignore" 2>/dev/null; then ok ".gitignore .e2e/"; else
  if [ "$INSTALL" = 1 ]; then printf '\n# e2e 검증 산출물 — storage state·결과·증거·서버 로그\n.e2e/\n' >> "$ROOT/.gitignore" && ok ".gitignore .e2e/" "added"; else miss ".gitignore .e2e/" "check-env.sh --install-config"; fi
fi

if [ "$INSTALL" = 1 ]; then
  for app in "$ROOT"/apps/*/; do
    [ -f "$app/vite.config.ts" ] || continue
    mkdir -p "$app/e2e"
    [ -f "$app/e2e/tsconfig.json" ] || cp "$SKILL_DIR/templates/e2e-tsconfig.json" "$app/e2e/tsconfig.json"
  done
  info "apps/*/e2e" "created for vite apps"
fi

if claude mcp list 2>/dev/null | grep -qE '^playwright:'; then ok "playwright MCP (claude)"; else info "playwright MCP (claude)" "claude mcp add playwright -- npx @playwright/mcp@latest --caps testing"; fi
if grep -qs '^\[mcp_servers\.playwright\]' "$HOME/.codex/config.toml"; then ok "playwright MCP (codex)"; else info "playwright MCP (codex)" "add [mcp_servers.playwright] to ~/.codex/config.toml (references/web-playwright.md)"; fi

command -v argent >/dev/null && ok argent "$(argent --version 2>/dev/null | head -1)" || info argent "npm i -g @swmansion/argent (app flows only)"
command -v ffmpeg >/dev/null && ok ffmpeg || info ffmpeg "brew install ffmpeg (webm → mp4, frame extraction)"
booted=$(xcrun simctl list devices booted 2>/dev/null | grep -c Booted || true)
info "iOS simulators booted" "${booted:-0}"

ghv=$(gh --version 2>/dev/null | head -1 | awk '{print $3}')
if [ -n "$ghv" ] && ver_ge "$ghv" 2.99.0; then ok "gh --attach" "$ghv"; else miss "gh --attach" "brew upgrade gh (have ${ghv:-none}, need >= 2.99.0); until then publish text only"; fi

if ls "$ROOT"/.e2e/storage-state/*.json >/dev/null 2>&1; then ok "storage state" "$(ls "$ROOT"/.e2e/storage-state/*.json | xargs -n1 basename | tr '\n' ' ')"; else info "storage state" "none - human login via Playwright MCP, then browser_storage_state -> .e2e/storage-state/<app>.json"; fi

echo
if [ "$missing" = 0 ]; then echo "all required pieces present"; else echo "$missing required piece(s) missing"; fi
if [ "$STRICT" = 1 ] && [ "$missing" != 0 ]; then exit 1; fi
exit 0
