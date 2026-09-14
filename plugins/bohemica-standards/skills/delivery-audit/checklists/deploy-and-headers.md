# Deploy & HTTP headers checklist (DEP)

Applies to any web project. Framework-specific locations are in `../frameworks/<framework>.md`; evidence is in the `collect-evidence.sh` block of the same ID. Header items DEP-08 to DEP-10 share block `DEP-08-10`.

Live-header items (DEP-07 to DEP-12) have two modes:
- With `--url`: the block contains the real response (`curl`). Judge that.
- Without: judge the configuration in the repo and mark live behaviour `not-verified (no --url)`. If the header is set at a proxy that is not in the repo, say so.

Tags as in `security.md`; plus `docker` (Dockerfile/compose present) and `node` (Node runtime: Nuxt, Astro SSR, Strapi, Node API).

---

### DEP-01 README explains how to run, build, configure and deploy
- **Applies to:** all
- **Check:** README or `docs/` covers: prerequisites (runtime version, package manager), local setup, required env variables and their meaning, build command, how production is deployed and rolled back, who owns external services (DNS, hosting, CMS, mail).
- **How:** Block `DEP-01`: headings and keyword line count. If headings look promising, read the README (judgment item). `STACK.has.readme` false is an immediate finding.
- **Severity:** blocker if there is no deploy/env documentation at all; warning if partial
- **Fix:** Add the missing sections; short and accurate beats complete.

### DEP-02 Lockfile committed and used by CI/build
- **Applies to:** all
- **Check:** Exactly one lockfile matching the package manager is committed; Dockerfile and CI install with the frozen variant (`npm ci`, `pnpm install --frozen-lockfile`, `yarn install --immutable`, `composer install --no-dev`).
- **How:** Block `DEP-02`: lockfiles and install commands.
- **Severity:** blocker if no lockfile; warning if CI ignores it or two lockfiles exist
- **Fix:** Commit one lockfile, delete the others, switch install commands.

### DEP-03 Runtime version pinned
- **Applies to:** all
- **Check:** Node (or PHP) major is pinned consistently in `engines`, `.nvmrc`, the Dockerfile base image and CI, and is an active LTS / supported release.
- **How:** Block `DEP-03`: engines, version files, `FROM` lines, CI versions.
- **Severity:** warning (blocker for `node:latest` or an EOL major)
- **Fix:** Pin the same major everywhere.

### DEP-04 Dockerfile follows production basics
- **Applies to:** docker
- **Check:** Multi-stage build; `.dockerignore` excludes `node_modules`, `.git`, `.env`, build output; runtime runs as non-root `USER`; only the built output is copied; `HEALTHCHECK` or orchestrator probe; no secrets in `ENV`/`ARG` layers; persistent data (uploads) on a volume.
- **How:** Block `DEP-04`: Dockerfile head, `.dockerignore`, healthcheck/user/restart hits. Judge the Dockerfile directly from the block.
- **Severity:** warning (blocker if secrets are baked into the image)
- **Fix:** Nuxt pattern: build stage, then `COPY --from=build /app/.output ./.output`, `USER node`, `CMD ["node", ".output/server/index.mjs"]`. Laravel: php-fpm image with `composer install --no-dev` in build stage and `public/` as docroot.

### DEP-05 Build target matches the hosting
- **Applies to:** all
- **Check:** Nuxt `nitro.preset` / Astro `output` + `adapter` / Vite `base` match where it runs; prerendered routes are intentional; deploy scripts run the right build.
- **How:** Block `DEP-05`: config hits and `package.json` scripts, plus CI build commands from `DEP-14`.
- **Severity:** warning
- **Fix:** Set the target explicitly and document it in README.

### DEP-06 Process supervision and restart policy
- **Applies to:** node, laravel
- **Check:** The long-running process is supervised (compose `restart: unless-stopped`, orchestrator, PM2 ecosystem, systemd). Laravel: queue worker and scheduler are supervised and restarted after deploy.
- **How:** Block `DEP-06`: restart/pm2/systemd hits. If deploy is on a PaaS (Vercel, Netlify), mark `n/a`.
- **Severity:** warning
- **Fix:** Add a restart policy; PM2 with `max_memory_restart`; Laravel `queue:restart` in the deploy script.

### DEP-07 Reverse proxy forwards client info and redirects to HTTPS
- **Applies to:** all
- **Check:** Proxy passes `Host`, `X-Forwarded-For`, `X-Forwarded-Proto`; HTTP redirects to HTTPS with 301; Laravel docroot is `public/`; SPA has a history fallback.
- **How:** Block `DEP-07`: proxy directives; with `--url`, the HTTP status line (expect `301` to `https://`). No proxy config in the repo → `not-verified (proxy outside repo)`.
- **Severity:** blocker if HTTP serves the site without redirect; warning if forwarded headers are missing
- **Fix:** `proxy_set_header X-Forwarded-Proto $scheme;` etc. and `return 301 https://$host$request_uri;`.

### DEP-08 HSTS enabled
- **Applies to:** public
- **Check:** `Strict-Transport-Security: max-age=31536000; includeSubDomains` on HTTPS responses.
- **How:** Block `DEP-08-10`: config hits and live headers.
- **Severity:** warning
- **Fix:** Add at the proxy (preferred) or via nuxt-security / a headers middleware.

### DEP-09 Content-Security-Policy present and meaningful
- **Applies to:** public
- **Check:** A CSP exists; `script-src` avoids `'unsafe-inline'`/`'unsafe-eval'` without a documented reason (Nuxt SSR uses nonces via nuxt-security); third-party origins are listed explicitly. Report-only is acceptable for a first release if documented.
- **How:** Block `DEP-08-10`: CSP config and live header. Judge the directive list against the trackers found in `SEC-15`/`WEB-13`.
- **Severity:** warning (info for internal tools)
- **Fix:** Enable nuxt-security with `nonce: true`, or a headers middleware; start in report-only and tighten.

### DEP-10 Baseline security headers
- **Applies to:** public, internal
- **Check:** `X-Content-Type-Options: nosniff`, `X-Frame-Options` or CSP `frame-ancestors`, `Referrer-Policy: strict-origin-when-cross-origin` or stricter, `Permissions-Policy` restricting unused features. `Server`/`X-Powered-By` do not reveal versions.
- **How:** Block `DEP-08-10`.
- **Severity:** warning
- **Fix:** nuxt-security sets them by default; otherwise nginx `add_header ... always;` or a middleware.

### DEP-11 Caching: immutable assets, uncached HTML
- **Applies to:** all
- **Check:** Hashed assets (`/_nuxt/*`, `/assets/*`, `/_astro/*`, `/build/assets/*`) served with `Cache-Control: public, max-age=31536000, immutable`; HTML `no-cache` (or deliberate SWR); API responses not cached by intermediaries unless intended.
- **How:** Block `DEP-11`: routeRules / proxy cache directives; with `--url`, the live asset and HTML `cache-control` lines.
- **Severity:** warning
- **Fix:** Nuxt `routeRules` headers; nginx `location` block with `expires 1y; add_header Cache-Control "public, immutable";` for hashed assets and `no-cache` for `index.html`.

### DEP-12 Compression enabled
- **Applies to:** all
- **Check:** Text responses are gzip or brotli compressed at the proxy/CDN or by the app.
- **How:** Block `DEP-12`: config hits; with `--url`, `content-encoding`.
- **Severity:** warning
- **Fix:** Enable at the proxy; Nitro `compressPublicAssets: true` for prerendered assets.

### DEP-13 Health endpoint exists
- **Applies to:** node, laravel, api
- **Check:** A cheap unauthenticated `GET /health` (Laravel `/up`, Strapi `/_health`) returns 2xx and is used by the container/orchestrator health check.
- **How:** Block `DEP-13`: health route files and healthcheck hits.
- **Severity:** warning (info for static sites, `n/a` for SPA)
- **Fix:** Add the route and reference it from `HEALTHCHECK` / the load balancer.

### DEP-14 CI runs lint, typecheck, build and tests
- **Applies to:** all
- **Check:** Pipeline runs on every push/PR: frozen install, lint, typecheck, build, tests if present; deploy only from the main branch after checks pass.
- **How:** Block `DEP-14`: CI files, steps, `package.json` scripts. `STACK.has.ci` false with `STACK.has.tests` true is a finding on its own.
- **Severity:** warning (blocker if deploy happens with no build verification at all)
- **Fix:** Add a `check` job and gate deploy with `needs:`.

### DEP-15 Error tracking and logging configured
- **Applies to:** all
- **Check:** Server errors are reported where the team sees them (Sentry, GlitchTip, Bugsnag) or at minimum structured logs are shipped; DSN comes from env.
- **How:** Block `DEP-15` and `STACK.has.error_tracking`.
- **Severity:** warning (info for small internal tools and static sites)
- **Fix:** Add the framework Sentry SDK with `SENTRY_DSN` in `.env.example`.

### DEP-16 No environment-specific values hardcoded
- **Applies to:** all
- **Check:** Production URLs, API bases, CMS endpoints, mail settings, feature flags come from env/config, not literals; `site.url` / `APP_URL` is configured per environment.
- **How:** Block `DEP-16`: absolute URL hits after filtering well-known hosts. Ignore hits that are clearly external links in content.
- **Severity:** warning
- **Fix:** Move to config and document in `.env.example`.
