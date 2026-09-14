# Detection and checklist selection

Two independent axes plus exposure decide which checklist items run. Checklists are organised by concern (security, deploy, web standards), not by framework; the framework only changes *where to look* (see `frameworks/<name>.md`) and which **Applies to** tags are active.

## Axis 1 — what it is (from `scripts/detect-stack.sh`, included at the top of the evidence output as `=== STACK ===`)

| Signal | Field / value |
|---|---|
| `nuxt` dependency + `nuxt.config.*` | `framework: nuxt`, `ssr` from config (`ssr: false` → false, otherwise true) |
| `vue` + `vite`, no nuxt | `framework: vue-vite`, `ssr: false` (SPA, typically behind login) |
| `astro` dependency | `framework: astro`, `ssr` true when `output: 'server'` or `'hybrid'` |
| `@strapi/strapi` | `framework: strapi` (headless CMS, API exposure) |
| `composer.json` with `laravel/framework` | `framework: laravel`, `db: eloquent` |
| `@nestjs/core` / `fastify` / `express` | `framework: nest|fastify|express` (API) |
| `prisma`, `drizzle-orm`, `typeorm`, `mongoose`, `doctrine/orm` | `db` |
| `Dockerfile`, `docker-compose*`, nginx conf, `.github/workflows`, `.gitlab-ci.yml`, `vercel.json`, `netlify.toml`, `ecosystem.config.*` | `deploy[]`, `has.ci` |
| `.env` tracked by git (not `.example`) | `has.env_committed: true` → SEC-01 is already a finding |
| `@nuxtjs/sitemap` / `@nuxtjs/seo` / `@astrojs/sitemap` | `has.sitemap_module` (also a strong "public" signal) |
| `nuxt-security` | `has.nuxt_security_module` |
| `@nuxtjs/i18n` / `vue-i18n` | `has.i18n` → WEB-12 applies |
| `@sentry/*` / `sentry/sentry-laravel` | `has.error_tracking` |

Monorepos: if the root has `pnpm-workspace.yaml`, `workspaces` in `package.json`, or `apps/`/`packages/`, pick the deliverable app folder (ask if more than one candidate, as part of the single allowed question) and run the scripts there. Audit one app per run.

## Axis 2 — who will see it (exposure)

Values: `public` (marketing site, e-shop, portal anyone can reach), `internal` (tool behind login, admin, intranet), `api` (no UI, consumed by other systems).

Resolution order:
1. Explicit flag in `$ARGUMENTS`: `--public`, `--internal`, `--api`.
2. Inference, only when unambiguous:
   - `has.sitemap_module` true, or `robots.txt` allowing crawl, or OG/SEO meta across pages → `public`
   - `framework` is `strapi`, `nest`, `fastify`, `express`, or a Nuxt/Laravel project with no pages/views but with server routes → `api`
   - a global auth middleware (Nuxt `*.global.*`, Laravel `auth` on the whole web group, vue-router `beforeEach` guard) **and** no sitemap/SEO tooling → `internal`
   - `vue-vite` SPA → usually `internal`; confirm there is no SEO tooling
3. Otherwise ask the user **one** question: "Is this a public website, an internal tool behind login, or an API without UI?" Apart from the optional setup dialog (SKILL.md step 0, only when the skill was invoked with no arguments), this is the only question the audit asks. State other assumptions in the report instead.

Record the final value and how it was determined (flag / inferred from X / asked) in the AUDIT.md header.

## Active tags — which items are in scope

Every item carries **Applies to** tags. An item is in scope when at least one of its tags is active. Build the active set from the stack and exposure:

| Condition | Active tags |
|---|---|
| always | `all` |
| exposure = public | `public` |
| exposure = internal | `internal` |
| exposure = api | `api`, `server` |
| framework = nuxt (ssr true) | `nuxt`, `server`, `node` |
| framework = nuxt (ssr false) | `nuxt`, `spa`, `node` (treat like vue-spa for web items) |
| framework = vue-vite | `vue-spa`, `spa` |
| framework = astro (ssr true) | `astro`, `server`, `node` |
| framework = astro (ssr false) | `astro`, `spa` |
| framework = laravel | `laravel`, `server` |
| framework = strapi | `strapi`, `server`, `node` |
| framework = express / fastify / nest | `server`, `node` |
| deploy contains docker | `docker` |
| has.i18n | `i18n` |
| project replaces an existing site (README, redirects, or user says so) | `migration` |

Out-of-scope items are not reported at all (they are neither passed nor skipped). Items where the tag is active but the concept does not exist (e.g. DEP-13 health endpoint on a static Astro site) are reported as `n/a` with one line of reason.

## Checklists to load

| Condition | Files |
|---|---|
| always | `checklists/security.md`, `checklists/deploy-and-headers.md` |
| exposure = public or internal | `checklists/web-standards.md` |
| exposure = api | `checklists/api.md` *(planned — list under "Not covered")* |
| db ≠ null | `checklists/database-orm.md` *(planned)* |
| exposure = public | `checklists/performance.md` *(planned — WEB-16 is the sanity check for now)* |

Framework locator to load: `frameworks/<framework>.md` when it exists (`nuxt`, `vue-spa` for `vue-vite`, `astro`, `laravel`, `strapi`). For other frameworks proceed with the generic evidence blocks and note "no locator for <framework>" in the report.

## Adding a new stack later

1. Add the detection signal to `scripts/detect-stack.sh` (one `elif`) and any framework-specific paths to the `*_DIRS` lists in `scripts/lib/common.sh`.
2. Add one row to "Active tags" above.
3. Write `frameworks/<name>.md` (copy `nuxt.md`).
4. Only if the stack has concerns not covered by existing items, add items to the concern checklists with the new tag. Do not create per-framework checklists.
