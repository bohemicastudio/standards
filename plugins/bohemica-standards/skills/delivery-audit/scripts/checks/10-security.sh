#!/usr/bin/env bash
# checks/10-security.sh — evidence blocks for the Security checklist.
# Sourced by collect-evidence.sh; helpers and paths come from lib/common.sh.

block SEC-01
if in_git; then
  note "tracked env/key files:"
  git ls-files | grep -E '(^|/)\.env(\.|$)|\.(pem|key|p12|pfx)$|service-account.*\.json$' | grep -vE '\.(example|sample|dist|template)$' || echo "(none)"
  note "env/key files ever added to history:"
  git log --all --diff-filter=A --name-only --pretty=format: -- '.env' '.env.*' '**/.env' '**/.env.*' '*.pem' '*.key' '*.p12' '*service-account*.json' 2>/dev/null | grep -vE '^$|\.(example|sample|dist|template)$' | sort -u | head -n 20 || true
else
  note "not a git repository — history not checked"
fi
if command -v gitleaks >/dev/null 2>&1; then
  note "gitleaks:"; gitleaks detect --no-banner --redact --report-format json --report-path /dev/null 2>&1 | tail -n 15
else
  note "gitleaks not installed — pattern grep only (file:line, values hidden):"
  # shellcheck disable=SC2086
  grep -rnIE $EXCL --exclude='*.lock' --exclude='pnpm-lock.yaml' --exclude='package-lock.json' --exclude='*.min.js' --exclude='*.map' \
    -e '(AKIA[0-9A-Z]{16}|sk_live_[0-9a-zA-Z]{20,}|sk-[A-Za-z0-9]{32,}|ghp_[A-Za-z0-9]{36}|xox[baprs]-[0-9A-Za-z-]{10,}|AIza[0-9A-Za-z_-]{35}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----)' . 2>/dev/null \
    | cut -d: -f1,2 | head -n $LIMIT || true
  echo "(end of pattern grep)"
fi

block SEC-02
note "env example keys:"
for f in .env.example .env.sample .env.dist .env.template; do [ -f "$f" ] && { echo "$f:"; grep -oE '^[A-Z0-9_]+' "$f" | tr '\n' ' '; echo; }; done
note "env reads in source (process.env / import.meta.env / env()):"
# shellcheck disable=SC2086
g 'process\.env\.[A-Z0-9_]+|import\.meta\.env\.[A-Z0-9_]+|\benv\(\s*['"'"'"][A-Z0-9_]+' $APP_DIRS $SERVER_DIRS $CONFIG_FILES
if [ -n "$NUXT_CONFIG" ]; then
  note "runtimeConfig block ($NUXT_CONFIG):"
  awk '/runtimeConfig\s*:/{flag=1;depth=0} flag{print; n=gsub(/\{/,"{"); m=gsub(/\}/,"}"); depth+=n-m; if(depth<=0 && NR>1 && (n||m)) flag=0}' "$NUXT_CONFIG" | head -n $LIMIT
fi

block SEC-03
note "public-prefixed variables that look sensitive (NUXT_PUBLIC_/VITE_/PUBLIC_/MIX_):"
# shellcheck disable=SC2086
g '(NUXT_PUBLIC_|VITE_|PUBLIC_|MIX_)[A-Z0-9_]*(SECRET|PASSWORD|PRIVATE|TOKEN|API_KEY|APIKEY)' . 2>/dev/null
note "runtimeConfig.public usage on client:"
# shellcheck disable=SC2086
g 'useRuntimeConfig\(\)\.public|config\.public\.' $APP_DIRS

block SEC-04
case "$PM" in
  npm)  note "npm audit --omit=dev:";  npm audit --omit=dev --audit-level=high 2>&1 | tail -n 25 ;;
  pnpm) note "pnpm audit --prod:";     pnpm audit --prod 2>&1 | tail -n 25 ;;
  yarn) note "yarn npm audit:";        yarn npm audit --environment production 2>&1 | tail -n 25 ;;
  bun)  note "bun audit:";             bun audit 2>&1 | tail -n 25 ;;
  composer) note "composer audit:";    composer audit 2>&1 | tail -n 25 ;;
  *) echo "(no lockfile / package manager detected — audit skipped)" ;;
esac
[ -f composer.lock ] && [ "$PM" != "composer" ] && { note "composer audit:"; composer audit 2>&1 | tail -n 25; }

block SEC-05
note "framework versions:"
[ -f package.json ] && grep -E '"(nuxt|vue|vite|astro|@strapi/strapi|express|fastify|@nestjs/core|nitropack|h3)"\s*:' package.json
[ -f composer.json ] && grep -E '"(php|laravel/framework|symfony/framework-bundle)"\s*:' composer.json
[ -f .nvmrc ] && { note ".nvmrc:"; cat .nvmrc; }

block SEC-06
note "request input reads:"
# shellcheck disable=SC2086
g 'readBody\(|readValidatedBody\(|getQuery\(|getValidatedQuery\(|getRouterParam|\$request->(input|all|get|query)\(|request\(\)->|Astro\.request|req\.(body|query|params)' $SERVER_DIRS
note "validators present:"
# shellcheck disable=SC2086
g 'zod|valibot|yup|joi|readValidated|getValidated|->validate\(|FormRequest|class-validator|@nestjs/common.*Pipe' $SERVER_DIRS

block SEC-07
note "server routes / handlers:"
for d in server/api server/routes src/pages/api src/api routes app/Http/Controllers; do
  [ -d "$d" ] && { echo "$d/:"; find "$d" -type f \( -name '*.ts' -o -name '*.js' -o -name '*.php' -o -name '*.mjs' \) | sed 's#^\./##' | head -n $LIMIT; }
done
note "server middleware:"
lsx server/middleware src/middleware app/Http/Middleware
note "auth checks in handlers:"
# shellcheck disable=SC2086
g 'requireUserSession|getUserSession|getServerSession|auth\(\)|->middleware\(|Route::middleware|authorize\(|Gate::|can\(|verifyToken|jwt' $SERVER_DIRS

block SEC-08
# shellkcheck disable=SC2086
g 'v-html|innerHTML|\{!!|set:html|dangerouslySetInnerHTML' $APP_DIRS

block SEC-09
note "outgoing fetch in server code:"
# shellcheck disable=SC2086
g '\$fetch\(|fetch\(|ofetch|axios\.|Http::|file_get_contents\(\s*\$|curl_init' $SERVER_DIRS

block SEC-10
# shellcheck disable=SC2086
g 'setCookie\(|useCookie\(|cookie\(|httpOnly|sameSite|same_site|http_only|secure.*cookie|SESSION_SECURE' $SERVER_DIRS $CONFIG_FILES $APP_DIRS

block SEC-11
# shellcheck disable=SC2086
g 'rateLimiter|rate-limit|ratelimit|throttle|limit_req|RateLimiter' $SERVER_DIRS $CONFIG_FILES $NGINX_FILES

block SEC-12
# shellcheck disable=SC2086
g 'readMultipartFormData|formidable|multer|busboy|->file\(|storeAs\(|move_uploaded_file|upload' $SERVER_DIRS

block SEC-13
[ -n "$NUXT_CONFIG" ] && { note "$NUXT_CONFIG debug/devtools/sourcemap:"; grep -nE 'devtools|debug\s*:|sourcemap' "$NUXT_CONFIG" || echo "(none)"; }
note "APP_DEBUG / NODE_ENV in env example, CI, Dockerfile:"
# shellcheck disable=SC2086
g 'APP_DEBUG|NODE_ENV' .env.example .env.sample $CI_FILES 2>/dev/null
note "stack traces in error pages:"
# shellcheck disable=SC2086
g '\.stack\b|error\.message|APP_DEBUG' error.vue app/error.vue src/pages/404.astro src/pages/500.astro resources/views/errors 2>/dev/null

block SEC-14
# shellcheck disable=SC2086
g 'cors|Access-Control-Allow|allowed_origins|corsHandler' $SERVER_DIRS $CONFIG_FILES $NGINX_FILES

block SEC-15
# shellcheck disable=SC2086
g '<script[^>]+src=|useScript|googletagmanager|gtag\(|hotjar|clarity\.ms|facebook\.net|smartlook|leadhub|ecomail' $APP_DIRS $CONFIG_FILES

block SEC-16
if in_git; then git ls-files .npmrc .yarnrc.yml auth.json 2>/dev/null; fi
# shellcheck disable=SC2086
grep -rnIE $EXCL -e '_authToken|NPM_TOKEN=[A-Za-z0-9]|GITHUB_TOKEN=[A-Za-z0-9]|COMPOSER_AUTH=' .npmrc .yarnrc.yml auth.json $CI_FILES 2>/dev/null | cut -d: -f1,2 | head -n 20 || true
echo "(end)"

block SEC-17
[ -n "$NUXT_CONFIG" ] && { grep -nE 'sourcemap' "$NUXT_CONFIG" || echo "(no sourcemap setting in $NUXT_CONFIG)"; }
# shellcheck disable=SC2086
g 'sourcemap' $CONFIG_FILES
note "map files in build output:"
ls .output/public/_nuxt/*.map dist/assets/*.map dist/_astro/*.map public/build/assets/*.map 2>/dev/null | head -n 5 || true
echo "(end)"

block SEC-18
note "route middleware files:"
lsx middleware app/middleware src/middleware
note "pages using middleware:"
# shellcheck disable=SC2086
g 'definePageMeta\(\{[^}]*middleware|middleware\s*:' pages app/pages src/pages 2>/dev/null
note "admin/preview/debug routes:"
find . $FIND_EXCL -type f \( -ipath '*admin*' -o -ipath '*preview*' -o -ipath '*debug*' \) 2>/dev/null | head -n 20
# shellcheck disable=SC2086
g '/admin|/preview|/_debug|/telescope|/horizon|/nova' routes $SERVER_DIRS 2>/dev/null

block SEC-19
note "client side — form fields in templates:"
# shellcheck disable=SC2046
form_scan fields $(template_files)
SCHEMA_DIRS="$(existing $SERVER_DIRS schemas shared utils app/utils src/schemas src/utils src/validation app/Rules)"
note "length rules in server and shared schema dirs (zod/valibot .max, Laravel max:/between:/size:, maxLength):"
# shellcheck disable=SC2086
g '([^h]|^)\.max\(|maxLength|max_length|max:[0-9]+|between:[0-9]+|size:[0-9]+|Rule::.*max' $SCHEMA_DIRS
note "string rules missing a max or a trim on the same line (heuristic; trim only judged for zod/valibot):"
# shellcheck disable=SC2086
[ -n "$SCHEMA_DIRS" ] && grep -rnIE $EXCL --exclude='*.json' -e 'z\.string\(\)|v\.string\(\)|[|'"'"'"]string[|'"'"'"]' $SCHEMA_DIRS 2>/dev/null \
  | perl -ne 'chomp; my @m; push @m, "max" unless /max|between:|size:/i; push @m, "trim" if /[zv]\.string\(\)/ && !/trim/; print "$_  [no @{[join q(, no ), @m]}]\n" if @m' | head -n 20
echo "(end)"
note "trimming in server and shared schema code (zod .trim(), valibot v.trim(), handlers):"
# shellcheck disable=SC2086
g '\.trim\(\)|v\.trim\(\)|Str::(trim|squish)\(|\btrim\(\$' $SCHEMA_DIRS
if [ "$FRAMEWORK" = "laravel" ]; then
  note "Laravel TrimStrings middleware (11+: on unless bootstrap/app.php removes it; 10: listed in Kernel.php):"
  # shellcheck disable=SC2046
  TS_HITS="$(grep -nHE 'TrimStrings|trimStrings|ConvertEmptyStringsToNull|convertEmptyStringsToNull' $(existing bootstrap/app.php app/Http/Kernel.php app/Http/Middleware/TrimStrings.php) /dev/null 2>/dev/null | head -n 10)"
  printf '%s\n' "${TS_HITS:-(none — on by default in Laravel 11+)}"
fi
if [ -d src/api ]; then
  note "Strapi content types (text-like attributes / maxLength set):"
  for f in src/api/*/content-types/*/schema.json src/components/*/*.json; do
    [ -f "$f" ] && printf '%s: text-like=%s maxLength=%s\n' "$f" "$(grep -cE '"type" *: *"(string|text|richtext|email|blocks)"' "$f")" "$(grep -c '"maxLength"' "$f")"
  done | head -n 20
fi
note "DB string columns with an explicit length, and text columns (migrations, Prisma, Drizzle):"
# shellcheck disable=SC2046
g '->string\([^)]*,[[:space:]]*[0-9]+|->(text|mediumText|longText)\(|@db\.VarChar\(|varchar\(' $(existing database/migrations prisma drizzle src/db server/db)
note "request body size limits (app, Strapi body, proxy, PHP):"
# shellcheck disable=SC2086
g 'requestSizeLimiter|maxRequestSizeInBytes|maxUploadFileRequestInBytes|client_max_body_size|bodyLimit|formLimit|jsonLimit|textLimit|post_max_size|maxBodyLength' $CONFIG_FILES $SERVER_DIRS $NGINX_FILES $(existing .htaccess public/.htaccess .user.ini php.ini)
