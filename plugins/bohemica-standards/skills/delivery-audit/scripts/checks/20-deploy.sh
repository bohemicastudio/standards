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
