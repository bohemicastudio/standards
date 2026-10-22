#!/usr/bin/env bash
# checks/20-deploy.sh — evidence blocks for the Deploy & Headers checklist.
# Sourced by collect-evidence.sh; helpers and paths come from lib/common.sh.

block DEP-01
for f in README.md readme.md README.MD README; do
  [ -f "$f" ] && { note "$f headings:"; grep -nE '^#{1,3} ' "$f" | head -n 30; note "keywords:"; grep -ciE 'deploy|env|\.env|build|docker|install|setup|run' "$f" | sed 's/^/keyword lines: /'; break; }
done
[ -d docs ] && { note "docs/:"; ls docs | head -n 20; }

block DEP-02
note "lockfiles:"; lsx package-lock.json pnpm-lock.yaml yarn.lock bun.lockb bun.lock composer.lock
note "install commands in CI/Dockerfile:"
# shellcheck disable=SC2086
g 'npm (ci|install|i)\b|pnpm (install|i)\b|yarn install|bun install|composer install' $CI_FILES

block DEP-03
[ -f package.json ] && { note "engines:"; grep -nA3 '"engines"' package.json || echo "(none)"; }
lsx .nvmrc .node-version .tool-versions
# shellcheck disable=SC2086
g 'FROM |node-version|php-version|image:\s*(node|php)' $CI_FILES
[ -f composer.json ] && grep -nE '"php"\s*:' composer.json

block DEP-04
for f in Dockerfile docker/Dockerfile .docker/Dockerfile; do [ -f "$f" ] && { show "$f" 60; break; }; done
show .dockerignore 20
# shellcheck disable=SC2086
g 'HEALTHCHECK|healthcheck:|USER |restart:' $CI_FILES

block DEP-05
[ -n "$NUXT_CONFIG" ] && { note "nitro/routeRules in $NUXT_CONFIG:"; grep -nE 'nitro|preset|routeRules|prerender|swr|isr' "$NUXT_CONFIG" || echo "(none)"; }
# shellcheck disable=SC2086
g 'output\s*:|adapter|base\s*:|NITRO_PRESET' $CONFIG_FILES $CI_FILES
[ -f package.json ] && { note "scripts:"; grep -nA12 '"scripts"' package.json | head -n 16; }

block DEP-06
# shellcheck disable=SC2086
g 'restart:|pm2|systemd|supervisor|max_memory_restart|instances' $CI_FILES 2>/dev/null
lsx ecosystem.config.* *.service
block DEP-07
[ -n "$NGINX_FILES" ] && { note "proxy config:"; grep -nE 'proxy_set_header|return 301|listen 80|ssl_certificate|X-Forwarded|reverse_proxy' $NGINX_FILES | head -n 30; } || echo "(no proxy config in repo)"
if [ -n "$URL" ]; then note "live: http -> https redirect:"; curl_status "http://${URL#https://}/"; fi

block DEP-08-10
note "security headers in config:"
# shellkcheck disable=SC2086
g 'strictTransportSecurity|Strict-Transport-Security|contentSecurityPolicy|Content-Security-Policy|X-Frame-Options|frame-ancestors|X-Content-Type-Options|Referrer-Policy|Permissions-Policy|nuxt-security|security\s*:\s*\{|headers\s*:\s*\{' $CONFIG_FILES $NGINX_FILES $CI_FILES
if [ -n "$URL" ]; then note "live headers ($URL):"; curl_head "$URL"; fi

block DEP-11
[ -n "$NUXT_CONFIG" ] && grep -nE 'cache-control|Cache-Control|immutable|swr|isr' "$NUXT_CONFIG"
[ -n "$NGINX_FILES" ] && grep -nE 'expires|Cache-Control|immutable|_nuxt|/assets/|/_astro/' $NGINX_FILES | head -n 20
if [ -n "$URL" ]; then
  ASSET="$(curl -s --max-time 15 -A "bohemica-standards-audit" "$URL" 2>/dev/null | grep -oE '(src|href)="[^"]+\.(js|css)(\?[^"]*)?"' | head -n 1 | cut -d'"' -f2)"
  if [ -n "$ASSET" ]; then
    case "$ASSET" in http*) A="$ASSET" ;; /*) A="$URL$ASSET" ;; *) A="$URL/$ASSET" ;; esac
    note "live asset $A:"; curl_head "$A" | grep -iE '^(HTTP|cache-control|content-encoding|etag)'
  fi
  note "live HTML cache-control:"; curl_head "$URL" | grep -iE '^(cache-control|cdn-cache-control)'
fi
echo "(end)"

block DEP-12
# shellcheck disable=SC2086
g 'gzip|brotli|compressPublicAssets|compression' $NGINX_FILES $CONFIG_FILES 2>/dev/null
if [ -n "$URL" ]; then note "live content-encoding:"; curl -sSI --max-time 15 -H "Accept-Encoding: gzip, br" -A "bohemica-standards-audit" "$URL" 2>&1 | tr -d '\r' | grep -iE '^(HTTP|content-encoding)'; fi

block DEP-13
lsx server/api/health* server/routes/health* src/pages/api/health* src/pages/health*
# shellcheck disable=SC2086
g 'health|/up\b|HEALTHCHECK' $CI_FILES routes 2>/dev/null

block DEP-14
note "CI files:"; lsx .github/workflows/* .gitlab-ci.yml bitbucket-pipelines.yml
note "CI steps:"
# shellcheck disable=SC2086
g 'run:|script:|- (npm|pnpm|yarn|bun|composer|php|vendor/bin)' .github/workflows .gitlab-ci.yml bitbucket-pipelines.yml 2>/dev/null
[ -f package.json ] && { note "package.json scripts:"; grep -nE '"(lint|typecheck|type-check|test|build|check)[^"]*"\s*:' package.json; }

block DEP-15
# shellcheck disable=SC2086
g '@sentry|sentry|bugsnag|glitchtip|SENTRY_DSN|logtail|datadog|winston|pino' package.json composer.json $CONFIG_FILES .env.example $SERVER_DIRS 2>/dev/null

block DEP-16
note "hardcoded absolute URLs in source (excluding well-known):"
# shellcheck disable=SC2086
grep -rnIoE $EXCL -e 'https?://[a-z0-9.-]+\.(cz|sk|com|eu|io|net|org|app|dev)[/"'"'"' ]' $APP_DIRS $SERVER_DIRS $CONFIG_FILES 2>/dev/null \
  | grep -vE 'schema\.org|w3\.org|fonts\.g|googleapis|gstatic|example\.|localhost|github\.com|npmjs|nuxt\.com|vuejs\.org|astro\.build|laravel\.com|unpkg|jsdelivr|cdnjs' | head -n $LIMIT || true
echo "(end)"

block DEP-17
note "Dependabot:"
DB_FILE="$(lsx .github/dependabot.yml .github/dependabot.yaml | grep -v '^(none)$' | head -n 1)"
if [ -n "$DB_FILE" ]; then grep -nE 'package-ecosystem|directory|interval|open-pull-requests-limit|groups:' "$DB_FILE" | head -n $LIMIT; else echo "(no .github/dependabot.yml)"; fi
note "Renovate:"
RN_FILE="$(lsx renovate.json renovate.json5 .renovaterc .renovaterc.json .github/renovate.json .github/renovate.json5 .gitlab/renovate.json | grep -v '^(none)$' | head -n 1)"
if [ -n "$RN_FILE" ]; then show "$RN_FILE" 20
elif [ -f package.json ] && grep -q '"renovate"\s*:' package.json; then echo "package.json has a \"renovate\" key"
else echo "(no Renovate config)"; fi
note "CI audit / dependency scanning steps:"
# shellcheck disable=SC2086
g 'npm audit|pnpm audit|yarn (npm )?audit|composer audit|osv-scanner|snyk|trivy|dependency-review-action|Dependency-Scanning|dependency_scanning' $CI_FILES
note "ecosystems and manifest directories in the repo:"
{
  find . -maxdepth 4 \( -name node_modules -o -name vendor -o -name .git \) -prune -o -type f \( -name package.json -o -name composer.json -o -name 'Dockerfile*' -o -name 'docker-compose*.y*ml' -o -name 'compose.y*ml' \) -print 2>/dev/null \
    | sed -E 's#^\./##; s#(^|/)package\.json$#\1 npm#; s#(^|/)composer\.json$#\1 composer#; s#(^|/)(Dockerfile[^/]*|docker-compose[^/]*|compose\.ya?ml)$#\1 docker#' \
    | awk '{ d = $1; e = $2; if (e == "") { e = d; d = "/" } else { sub(/\/$/, "", d); d = "/" d } print e "\t" d }'
  [ -d .github/workflows ] && printf 'github-actions\t/\n'
} | sort -u | head -n $LIMIT
note "GitHub alert / security-update settings:"
GH_REPO="$(git remote get-url origin 2>/dev/null | sed -nE 's#^(https://|git@)github\.com[:/]([^/]+/[^/.]+)(\.git)?$#\2#p')"
if [ -z "$GH_REPO" ]; then echo "unknown (origin is not a GitHub repository)"
elif ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then echo "unknown ($GH_REPO; gh not installed or not logged in)"
elif [ "$QUICK" = 1 ]; then echo "unknown ($GH_REPO; skipped in --quick)"
else
  gh_flag() { gh api "repos/$GH_REPO/$1" >/dev/null 2>&1 && echo enabled || echo "disabled or no admin access"; }
  echo "$GH_REPO vulnerability alerts: $(gh_flag vulnerability-alerts)"
  echo "$GH_REPO automated security fixes: $(gh api "repos/$GH_REPO/automated-security-fixes" --jq '.enabled' 2>/dev/null || echo "unknown (no admin access)")"
fi
