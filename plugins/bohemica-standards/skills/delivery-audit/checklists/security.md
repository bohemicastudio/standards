# Security checklist (SEC)

Applies to any web project. Framework-specific file locations are in `../frameworks/<framework>.md`; the evidence for each item is in the block of the same ID in the `collect-evidence.sh` output.

Item format: **Applies to** (tags), **Check** (what good looks like), **How** (which evidence block to read and what to judge), **Severity**, **Fix**.
Report a finding only with evidence: a `path:line` or a command output line. If the evidence block is empty and you cannot verify otherwise, mark the item `not-verified` with the reason.

Tags: `all`, `server` (project has server-side handlers in the repo: Nuxt SSR, Astro SSR, Laravel, Strapi, Node API), `spa` (client-only), `public`, `internal`, `api`, `nuxt`, `laravel`, `strapi`, `astro`, `vue-spa`.

Severity: **blocker** must be fixed before handover; **warning** should be fixed, acceptable with a documented follow-up; **info** improvement.

---

### SEC-01 No secrets committed to git
- **Applies to:** all
- **Check:** No `.env` (other than `.env.example`), private keys, service-account files or hardcoded API keys exist in the working tree or git history.
- **How:** Block `SEC-01`: tracked env/key files, files ever added to history, gitleaks output or pattern-grep hits (shown as `file:line`, never open them to quote the value). `STACK.has.env_committed` is the short answer for `.env`.
- **Severity:** blocker
- **Fix:** Remove the file, add it to `.gitignore`, rotate every exposed secret (history rewrite does not un-leak a key), keep only `.env.example`.

### SEC-02 `.env.example` documents every required variable
- **Applies to:** all
- **Check:** `.env.example` exists and lists every variable the app reads, with placeholders and a short comment on purpose.
- **How:** Block `SEC-02`: compare the example keys with env reads in source (and the `runtimeConfig` block for Nuxt, `config/*.php` for Laravel). Missing keys or a missing example file are the finding.
- **Severity:** warning
- **Fix:** Add the missing keys with a comment describing purpose and where to obtain the value.

### SEC-03 Secrets never reach the client bundle
- **Applies to:** all
- **Check:** Nothing sensitive is exposed through client-visible configuration: Nuxt `runtimeConfig.public` / `NUXT_PUBLIC_*`, Vite `VITE_*`, Astro `PUBLIC_*`, Laravel Mix `MIX_*`. In an SPA every env var is public.
- **How:** Block `SEC-03`: any public-prefixed variable named like a secret is a finding; then check `runtimeConfig.public` contents in block `SEC-02` for keys, tokens, DB URLs. Locator: "Env / secrets".
- **Severity:** blocker
- **Fix:** Move the value server-side (private `runtimeConfig`, Laravel config, a separate API) and proxy third-party calls through a server route.

### SEC-04 No known-vulnerable production dependencies
- **Applies to:** all
- **Check:** No high/critical advisories in production dependencies.
- **How:** Block `SEC-04`: audit output. If the tool errored (no lockfile, registry unreachable, broken lockfile), mark `not-verified` with the error line.
- **Severity:** blocker for critical in a server-side dependency; otherwise warning
- **Fix:** Update the package; if no fix exists, document the risk and pin an override.

### SEC-05 Framework version is supported
- **Applies to:** all
- **Check:** The framework is on a maintained major: Nuxt 3.x latest minor or 4.x (Nuxt 2 is EOL), Vue 3, Vite 5+, Astro 4+, Laravel 11+ (10 in security-fix only), Strapi 5 (4 is maintenance), Node on an active LTS, PHP 8.2+.
- **How:** Block `SEC-05`: version constraints from `package.json` / `composer.json` / `.nvmrc`.
- **Severity:** blocker for an EOL major; warning if more than one minor behind
- **Fix:** Upgrade and re-run tests.

### SEC-06 Server handlers validate input
- **Applies to:** server
- **Check:** Every handler that reads request input validates the shape before use: Nuxt `readValidatedBody`/zod/valibot, Laravel FormRequest or `$request->validate()`, Astro/Node explicit schema. Laravel additionally: no `Model::create($request->all())` on unguarded models.
- **How:** Block `SEC-06`: list of input reads versus validators present. Open the handlers that read input but show no validator nearby (at most the first five) and confirm. Locator: "Validation".
- **Severity:** blocker when unvalidated input reaches a DB query, file path, shell or outgoing HTTP call; otherwise warning
- **Fix:** Add schema validation at the top of the handler and return 400/422 on failure.

### SEC-07 Private handlers check authentication and authorization
- **Applies to:** server
- **Check:** Every handler that mutates state or returns non-public data verifies the session/token, and checks the user may act on that resource (ownership, role), not just that they are logged in. Strapi: Public role has no `find`/`findOne` on private collections, and `populate` cannot pull private relations.
- **How:** Block `SEC-07`: handler list, middleware list, auth-check hits. For each mutating handler (method suffix `.post/.put/.patch/.delete`, `POST` export, Laravel non-GET route) with no global server middleware and no auth hit, open it. Locator: "Auth / authorization".
- **Severity:** blocker
- **Fix:** Add a server middleware rejecting unauthenticated requests on protected prefixes, plus per-handler ownership checks.

### SEC-08 Raw HTML rendering only with sanitized content
- **Applies to:** all
- **Check:** `v-html`, `innerHTML`, Blade `{!! !!}`, Astro `set:html` are used only with trusted CMS content sanitized server-side, or through DOMPurify / `sanitize-html`.
- **How:** Block `SEC-08`: each hit; trace where the bound value comes from (CMS field, user input, static string).
- **Severity:** blocker if the value can contain user input; warning for unsanitized CMS content
- **Fix:** Sanitize before rendering, or render as text.

### SEC-09 No server-side request forgery
- **Applies to:** server
- **Check:** Server code never fetches a URL, host or path fragment supplied by the request without an allowlist (image proxies, "fetch by URL" features, webhooks).
- **How:** Block `SEC-09`: outgoing fetch calls in server code. Open those whose URL argument is not a literal or config value.
- **Severity:** blocker
- **Fix:** Allowlist hosts, reject private IP ranges, or remove the feature.

### SEC-10 Cookies are `httpOnly`, `secure`, `sameSite`
- **Applies to:** server
- **Check:** Session/auth cookies set by the server use `httpOnly: true`, `secure: true` in production, `sameSite: lax|strict`. Laravel: `config/session.php` `secure`, `http_only`, `same_site`. Tokens are never stored in client-readable cookies or `localStorage` when an httpOnly alternative exists.
- **How:** Block `SEC-10`: cookie calls and session config hits. Read the options object for each auth cookie.
- **Severity:** blocker for auth cookies missing `httpOnly` or `secure`; warning for `sameSite` unset
- **Fix:** Set the flags explicitly.

### SEC-11 Rate limiting on auth, forms and public write endpoints
- **Applies to:** server
- **Check:** Login, registration, password reset, contact forms and unauthenticated POST routes are rate-limited at the app (nuxt-security `rateLimiter`, Laravel `throttle`, koa-ratelimit) or the proxy (`limit_req`).
- **How:** Block `SEC-11`: any rate-limit configuration. Cross-check with public POST handlers from block `SEC-07`.
- **Severity:** warning (blocker if a login endpoint exists with no limiting at any layer)
- **Fix:** Enable the framework rate limiter or nginx `limit_req_zone` on the affected paths; add a captcha/Turnstile to public forms.

### SEC-12 File uploads validated and stored safely
- **Applies to:** server
- **Check:** Uploads restrict MIME type and size, generate the stored filename (no user-controlled path), store outside the web root or in object storage, never execute.
- **How:** Block `SEC-12`: upload handling hits. Open the handler and check type/size/name handling. Locator: "Uploads".
- **Severity:** blocker if the path or extension is user-controlled; warning if size/type unchecked
- **Fix:** Validate size and magic bytes, random filename, S3-compatible storage.

### SEC-13 Production does not leak stack traces or debug tooling
- **Applies to:** all
- **Check:** Production runs with `NODE_ENV=production` / `APP_DEBUG=false`; devtools/debug flags are off or dev-only; the error page does not print `error.stack` or `error.message` from server errors; handlers do not return raw error objects.
- **How:** Block `SEC-13`: config flags, env/CI values, error-page hits. Nuxt: `devtools`, `debug`; Laravel: `APP_DEBUG` in `.env.example` and deploy config; SPA: not applicable beyond sourcemaps (SEC-17).
- **Severity:** warning (blocker if stack traces with file paths are shown to end users, or Laravel `APP_DEBUG=true` in a production env file)
- **Fix:** Gate devtools on environment; return `createError({ statusCode, statusMessage })` / `abort()` without internals.

### SEC-14 CORS is restrictive
- **Applies to:** server
- **Check:** APIs consumed cross-origin allow only known origins; never `*` together with credentials. Strapi default is `*` and must be narrowed.
- **How:** Block `SEC-14`: CORS configuration hits. Locator: "CORS".
- **Severity:** blocker for `*` with credentials; warning for `*` on authenticated APIs
- **Fix:** Explicit origin allowlist.

### SEC-15 Third-party scripts loaded deliberately
- **Applies to:** public
- **Check:** GTM, analytics, chat, maps are loaded through a managed mechanism (`@nuxt/scripts`, a consent-gated plugin, a documented tag in the head layout), not pasted ad hoc; no third-party script carries a private key; CDN scripts pin a version or use SRI.
- **How:** Block `SEC-15`: script tags and known tracker hits with locations. Locator: "Third-party scripts".
- **Severity:** warning
- **Fix:** Move to a managed loader with consent triggers; remove unused tags.

### SEC-16 No registry or CI tokens committed
- **Applies to:** all
- **Check:** `.npmrc`, `.yarnrc.yml`, `auth.json`, CI config and Dockerfile contain no literal tokens; secrets come from CI variables and are not baked into image layers.
- **How:** Block `SEC-16`: tracked auth files and token-pattern hits (`file:line`).
- **Severity:** blocker
- **Fix:** Remove and rotate; inject via CI secrets or build-time mounts.

### SEC-17 Client sourcemaps disabled in production
- **Applies to:** all
- **Check:** Client sourcemaps are off, or hidden and uploaded only to the error tracker. Nuxt `sourcemap.client`, Vite `build.sourcemap`, Laravel Vite config.
- **How:** Block `SEC-17`: sourcemap settings and any `.map` files in build output.
- **Severity:** info (warning if server code is bundled into client maps or the app is `internal` with business logic in the bundle)
- **Fix:** `sourcemap: { client: false }` / `build.sourcemap: 'hidden'` with tracker upload.

### SEC-18 Admin, preview, debug and internal routes protected
- **Applies to:** all
- **Check:** `/admin`, `/preview`, CMS preview endpoints, `/_debug`, Laravel Telescope/Horizon/Nova/debugbar, Strapi `/admin` are behind auth or disabled in production. Route middleware exists and is applied.
- **How:** Block `SEC-18`: middleware files, pages using middleware, admin/preview/debug route hits. For each such route, confirm a guard in block `SEC-07` middleware or in the page meta. Locator: "Route middleware", "Admin panel".
- **Severity:** blocker
- **Fix:** Global auth middleware with an allowlist of public routes, or remove the routes from the production build.
