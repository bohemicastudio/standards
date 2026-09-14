#!/usr/bin/env bash
# lib/common.sh — shared helpers and project paths for checks/*.sh.
# Sourced by collect-evidence.sh after it has parsed arguments and cd'ed into the target.
# Expects: HERE (scripts dir), TARGET, URL, QUICK. Provides: STACK_JSON, FRAMEWORK, PM, NUXT_CONFIG,
#          *_DIRS / *_FILES path lists, block/note/g/gl/show/lsx/html_text/curl_head/curl_status/in_git.

LIMIT=40                       # max lines per block
EXCL="--exclude-dir=node_modules --exclude-dir=.nuxt --exclude-dir=.output --exclude-dir=dist --exclude-dir=build --exclude-dir=vendor --exclude-dir=.git --exclude-dir=storage --exclude-dir=.astro --exclude-dir=coverage"
FIND_EXCL="-not -path */node_modules/* -not -path */vendor/* -not -path ./.git/* -not -path */.nuxt/* -not -path */.output/* -not -path */dist/*"

# ---------- stack ----------
STACK_JSON="$(bash "$HERE/detect-stack.sh" .)"
FRAMEWORK="$(printf '%s' "$STACK_JSON" | grep -oE '"framework": "[^"]+"' | cut -d'"' -f4)"
PM="$(printf '%s' "$STACK_JSON" | grep -oE '"package_manager": "[^"]+"' | cut -d'"' -f4)"
NUXT_CONFIG="$(printf '%s' "$STACK_JSON" | grep -oE '"config":"[^"]+"' | cut -d'"' -f4)"

# ---------- helpers ----------
existing() { local d; for d in "$@"; do [ -e "$d" ] && printf '%s ' "$d"; done; }
# directories by role (only those that exist are used)
APP_DIRS="$(existing app src pages components layouts composables plugins middleware app.vue error.vue resources/views resources/js public/index.html index.html)"
SERVER_DIRS="$(existing server src/server src/pages/api src/api app/Http app/Models routes src/routes src/plugins src/middlewares config)"
CONFIG_FILES="$(existing nuxt.config.ts nuxt.config.js nuxt.config.mjs astro.config.mjs astro.config.ts astro.config.js vite.config.ts vite.config.js vite.config.mjs config/app.php config/session.php config/cors.php config/middlewares.js config/middlewares.ts config/server.js config/server.ts)"
CI_FILES="$(existing .github/workflows .gitlab-ci.yml bitbucket-pipelines.yml Dockerfile docker/Dockerfile docker-compose.yml docker-compose.yaml compose.yml compose.yaml .dockerignore ecosystem.config.js ecosystem.config.cjs Procfile)"
NGINX_FILES="$(find . -maxdepth 3 \( -name 'nginx.conf' -o -name '*.nginx' -o -name 'nginx*.conf' -o -name 'Caddyfile' -o -name 'traefik*.yml' \) -not -path '*/node_modules/*' 2>/dev/null | tr '\n' ' ')"

block() { printf '\n=== %s ===\n' "$1"; }
note()  { printf -- '-- %s\n' "$*"; }
# g PATTERN PATHS... : grep recursively, capped, "(none)" when empty
g() {
  local pat="$1"; shift
  local out
  [ $# -eq 0 ] && { echo "(no matching directories in this project)"; return; }
  # shellcheck disable=SC2086
  out="$(grep -rnIE $EXCL -e "$pat" "$@" 2>/dev/null | head -n $LIMIT)"
  if [ -n "$out" ]; then printf '%s\n' "$out"; else echo "(none)"; fi
}
# gl PATTERN PATHS... : files that do NOT match (for "pages without meta")
gl() {
  local pat="$1"; shift
  [ $# -eq 0 ] && { echo "(no matching directories)"; return; }
  # shellcheck disable=SC2086
  grep -rLIE $EXCL -e "$pat" "$@" 2>/dev/null | head -n $LIMIT
}
show() { # print a file, capped
  if [ -f "$1" ]; then note "$1:"; head -n "${2:-$LIMIT}" "$1"; else echo "(missing: $1)"; fi
}
curl_head() { curl -sSI -L --max-time 15 -A "bohemica-standards-audit" "$1" 2>&1 | tr -d '\r' | head -n 40; }
curl_status() { curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' --max-time 15 -A "bohemica-standards-audit" "$1" 2>&1; }
in_git() { command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; }
lsx() { local f found=0; for f in "$@"; do [ -e "$f" ] && { echo "$f"; found=1; }; done; [ $found = 1 ] || echo "(none)"; }
# html_text: stdin HTML -> visible text on one line (drops script/style/noscript/svg, tags, collapses whitespace)
html_text() { perl -0777 -pe 's/<(script|style|noscript|svg|template)\b.*?<\/\1>//gsi; s/<!--.*?-->//gs; s/<[^>]+>/ /g; s/&nbsp;/ /g; s/\s+/ /g' 2>/dev/null; }
