#!/usr/bin/env bash
# detect-stack.sh — detect what a delivered project is, deterministically.
#
# Usage:  bash detect-stack.sh [target-dir]
# Output: one JSON object on stdout, exit 0. Never asks questions, never modifies files.
# Deps:   bash, coreutils, grep. Uses `node` for package.json parsing when available,
#         falls back to grep. `git` is optional (used only for env_committed).
# Runs under Git Bash on Windows and on Linux/macOS.

set -u

TARGET="${1:-.}"
if [ ! -d "$TARGET" ]; then
  printf '{"error":"target directory not found: %s"}\n' "$TARGET"
  exit 0
fi
cd "$TARGET" || exit 0

# ---------- helpers ----------
has_file() { [ -e "$1" ]; }
first_match() { # first existing path among args, or empty
  for f in "$@"; do [ -e "$f" ] && { printf '%s' "$f"; return; }; done
}
json_bool() { if [ "$1" = "1" ]; then printf 'true'; else printf 'false'; fi; }
json_str_or_null() { if [ -n "$1" ]; then printf '"%s"' "$1"; else printf 'null'; fi; }
json_array() { # args -> ["a","b"]
  local out="" x
  for x in "$@"; do
    [ -z "$x" ] && continue
    out="${out:+$out,}\"$x\""
  done
  printf '[%s]' "$out"
}

# ---------- package.json ----------
PKG_JSON="package.json"
DEPS=""            # newline-separated list of all dep names (deps + devDeps)
if has_file "$PKG_JSON"; then
  if command -v node >/dev/null 2>&1; then
    DEPS="$(node -e '
      const p = JSON.parse(require("fs").readFileSync("package.json","utf8"));
      const d = Object.assign({}, p.dependencies||{}, p.devDependencies||{});
      process.stdout.write(Object.keys(d).join("\n"));
    ' 2>/dev/null)"
  fi
  if [ -z "$DEPS" ]; then
    # grep fallback: any quoted key inside the file; over-inclusive but fine for presence checks
    DEPS="$(grep -oE '"[@A-Za-z0-9_./-]+"[[:space:]]*:' "$PKG_JSON" | sed -E 's/^"([^"]+)".*/\1/' | sort -u)"
  fi
fi
has_dep() { printf '%s\n' "$DEPS" | grep -qx -- "$1"; }

# ---------- composer.json ----------
COMPOSER_DEPS=""
if has_file composer.json; then
  COMPOSER_DEPS="$(grep -oE '"[A-Za-z0-9_./-]+/[A-Za-z0-9_./-]+"[[:space:]]*:' composer.json | sed -E 's/^"([^"]+)".*/\1/' | sort -u)"
fi
has_composer_dep() { printf '%s\n' "$COMPOSER_DEPS" | grep -qx -- "$1"; }

# ---------- framework ----------
FRAMEWORK="unknown"
SSR="null"
NUXT_CONFIG="$(first_match nuxt.config.ts nuxt.config.js nuxt.config.mjs)"
ASTRO_CONFIG="$(first_match astro.config.mjs astro.config.ts astro.config.js)"

if has_dep nuxt && [ -n "$NUXT_CONFIG" ]; then
  FRAMEWORK="nuxt"
elif has_dep nuxt; then
  FRAMEWORK="nuxt"; NUXT_CONFIG=""
elif has_dep astro || [ -n "$ASTRO_CONFIG" ]; then
  FRAMEWORK="astro"
elif has_dep @strapi/strapi; then
  FRAMEWORK="strapi"
elif has_composer_dep laravel/framework; then
  FRAMEWORK="laravel"
elif has_composer_dep symfony/framework-bundle; then
  FRAMEWORK="symfony"
elif has_dep @nestjs/core; then
  FRAMEWORK="nest"
elif has_dep fastify; then
  FRAMEWORK="fastify"
elif has_dep express; then
  FRAMEWORK="express"
elif has_dep vue && has_dep vite; then
  FRAMEWORK="vue-vite"
elif has_dep vue; then
  FRAMEWORK="vue"
fi

# ---------- nuxt details ----------
NUXT_JSON="null"
if [ "$FRAMEWORK" = "nuxt" ]; then
  SSR_SETTING="unset"
  MODULES=""
  if [ -n "$NUXT_CONFIG" ]; then
    if grep -qE '^\s*ssr\s*:\s*false' "$NUXT_CONFIG"; then
      SSR_SETTING="false"
    elif grep -qE '^\s*ssr\s*:\s*true' "$NUXT_CONFIG"; then
      SSR_SETTING="true"
    fi
    # module names: quoted strings that look like package names, from the modules: [...] block
    MODULES="$(awk '/modules\s*:\s*\[/{flag=1} flag{print} flag&&/\]/{flag=0}' "$NUXT_CONFIG" \
      | grep -oE "['\"][@A-Za-z0-9_./-]+['\"]" | tr -d "'\"" | sort -u | tr '\n' ' ')"
  fi
  case "$SSR_SETTING" in
    false) SSR="false" ;;
    *)     SSR="true" ;;   # Nuxt default is SSR on
  esac
  # shellcheck disable=SC2086
  NUXT_JSON="$(printf '{"config":%s,"ssr_setting":"%s","modules":%s}' \
    "$(json_str_or_null "$NUXT_CONFIG")" "$SSR_SETTING" "$(json_array $MODULES)")"
fi

case "$FRAMEWORK" in
  vue-vite|vue) SSR="false" ;;
  astro)        if [ -n "$ASTRO_CONFIG" ] && grep -qE "output\s*:\s*['\"](server|hybrid)['\"]" "$ASTRO_CONFIG"; then SSR="true"; else SSR="false"; fi ;;
  laravel|symfony|strapi|nest|fastify|express) SSR="null" ;;
esac

# ---------- language ----------
LANGS=""
[ -n "$(first_match tsconfig.json tsconfig.base.json)" ] && LANGS="$LANGS ts"
has_file "$PKG_JSON" && ! has_file tsconfig.json && LANGS="$LANGS js"
has_file composer.json && LANGS="$LANGS php"

# ---------- package manager ----------
PM=""
if   has_file pnpm-lock.yaml; then PM="pnpm"
elif has_file yarn.lock;      then PM="yarn"
elif has_file bun.lockb || has_file bun.lock; then PM="bun"
elif has_file package-lock.json; then PM="npm"
elif has_file composer.lock;  then PM="composer"
fi
LOCKFILE=0; [ -n "$PM" ] && LOCKFILE=1

# ---------- database / orm ----------
DB=""
if   has_dep prisma || has_dep @prisma/client || [ -d prisma ]; then DB="prisma"
elif has_dep drizzle-orm; then DB="drizzle"
elif has_dep typeorm; then DB="typeorm"
elif has_dep mongoose; then DB="mongoose"
elif has_dep sequelize; then DB="sequelize"
elif has_dep knex; then DB="knex"
elif has_composer_dep doctrine/orm; then DB="doctrine"
elif [ "$FRAMEWORK" = "laravel" ]; then DB="eloquent"
elif [ "$FRAMEWORK" = "strapi" ]; then DB="strapi-db"
fi

# ---------- deploy signals ----------
DEPLOY=""
DOCKERFILE="$(first_match Dockerfile dockerfile docker/Dockerfile .docker/Dockerfile)"
[ -n "$DOCKERFILE" ] || [ -n "$(first_match docker-compose.yml docker-compose.yaml compose.yml compose.yaml)" ] && DEPLOY="$DEPLOY docker"
NGINX_CONF="$(find . -maxdepth 3 \( -name 'nginx.conf' -o -name '*.nginx' -o -name 'nginx*.conf' \) -not -path '*/node_modules/*' 2>/dev/null | head -1)"
[ -n "$NGINX_CONF" ] && DEPLOY="$DEPLOY nginx"
[ -d .github/workflows ] && DEPLOY="$DEPLOY github-actions"
has_file .gitlab-ci.yml && DEPLOY="$DEPLOY gitlab-ci"
has_file vercel.json && DEPLOY="$DEPLOY vercel"
{ has_file netlify.toml || [ -d netlify ]; } && DEPLOY="$DEPLOY netlify"
has_file ecosystem.config.js || has_file ecosystem.config.cjs && DEPLOY="$DEPLOY pm2"
has_file Procfile && DEPLOY="$DEPLOY procfile"
has_file .platform.app.yaml && DEPLOY="$DEPLOY platform-sh"
[ -d .forge ] || has_file forge.yml && DEPLOY="$DEPLOY forge"
CI=0; { [ -d .github/workflows ] || has_file .gitlab-ci.yml || has_file bitbucket-pipelines.yml; } && CI=1

# ---------- misc presence flags ----------
ENV_EXAMPLE=0; [ -n "$(first_match .env.example .env.sample .env.dist .env.template)" ] && ENV_EXAMPLE=1
ENV_COMMITTED=0
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git ls-files -- '.env' '.env.*' '*/.env' '*/.env.*' 2>/dev/null | grep -vE '\.(example|sample|dist|template)$' | grep -q .; then
    ENV_COMMITTED=1
  fi
fi
README=0; [ -n "$(first_match README.md readme.md README.MD README.txt README)" ] && README=1
ROBOTS=0; [ -n "$(first_match public/robots.txt static/robots.txt robots.txt)" ] && ROBOTS=1
SITEMAP_MODULE=0
{ has_dep @nuxtjs/sitemap || has_dep @nuxtjs/seo || has_dep nuxt-simple-sitemap || has_dep @astrojs/sitemap; } && SITEMAP_MODULE=1
NUXT_SECURITY=0; has_dep nuxt-security && NUXT_SECURITY=1
NUXT_IMAGE=0; has_dep @nuxt/image && NUXT_IMAGE=1
I18N=0; { has_dep @nuxtjs/i18n || has_dep vue-i18n || has_dep astro-i18next; } && I18N=1
SENTRY=0; { printf '%s\n' "$DEPS" | grep -q '^@sentry/' || has_composer_dep sentry/sentry-laravel; } && SENTRY=1
TESTS=0; { has_dep vitest || has_dep jest || has_dep @playwright/test || has_dep cypress || has_composer_dep phpunit/phpunit || has_composer_dep pestphp/pest; } && TESTS=1

# ---------- output ----------
# shellcheck disable=SC2086
printf '{\n'
printf '  "target": "%s",\n' "$(pwd -W 2>/dev/null || pwd)"
printf '  "framework": "%s",\n' "$FRAMEWORK"
printf '  "ssr": %s,\n' "$SSR"
printf '  "language": %s,\n' "$(json_array $LANGS)"
printf '  "package_manager": %s,\n' "$(json_str_or_null "$PM")"
printf '  "db": %s,\n' "$(json_str_or_null "$DB")"
printf '  "deploy": %s,\n' "$(json_array $DEPLOY)"
printf '  "has": {\n'
printf '    "dockerfile": %s,\n' "$(json_str_or_null "$DOCKERFILE")"
printf '    "nginx_conf": %s,\n' "$(json_str_or_null "${NGINX_CONF#./}")"
printf '    "env_example": %s,\n' "$(json_bool $ENV_EXAMPLE)"
printf '    "env_committed": %s,\n' "$(json_bool $ENV_COMMITTED)"
printf '    "lockfile": %s,\n' "$(json_bool $LOCKFILE)"
printf '    "readme": %s,\n' "$(json_bool $README)"
printf '    "ci": %s,\n' "$(json_bool $CI)"
printf '    "robots_txt": %s,\n' "$(json_bool $ROBOTS)"
printf '    "sitemap_module": %s,\n' "$(json_bool $SITEMAP_MODULE)"
printf '    "nuxt_security_module": %s,\n' "$(json_bool $NUXT_SECURITY)"
printf '    "nuxt_image_module": %s,\n' "$(json_bool $NUXT_IMAGE)"
printf '    "i18n": %s,\n' "$(json_bool $I18N)"
printf '    "error_tracking": %s,\n' "$(json_bool $SENTRY)"
printf '    "tests": %s\n' "$(json_bool $TESTS)"
printf '  },\n'
printf '  "nuxt": %s,\n' "$NUXT_JSON"
printf '  "exposure": "unknown"\n'
printf '}\n'
