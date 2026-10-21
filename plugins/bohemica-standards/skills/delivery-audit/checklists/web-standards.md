# Web standards checklist (WEB)

Applies to public websites on any framework: crawlability, SEO metadata, sharing, i18n, legal basics, accessibility basics, a performance sanity check and AI/GEO readiness (WEB-17 to WEB-22), Lighthouse scores (WEB-23), HTML validity (WEB-24) and form validation (WEB-25). Not a full SEO or accessibility audit. Framework-specific locations are in `../frameworks/<framework>.md`; evidence is in the `collect-evidence.sh` block of the same ID.

For `internal` exposure only WEB-04, WEB-07, WEB-08, WEB-15, WEB-23, WEB-24 and WEB-25 apply. Items needing the live site say so; without `--url` judge the config and mark live behaviour `not-verified (no --url)`.

Tags as in `security.md`; plus `i18n` (`STACK.has.i18n`), `migration` (the project replaces an existing site; if unknown, state the assumption).

---

### WEB-01 `robots.txt` correct per environment
- **Applies to:** public
- **Check:** Production serves a `robots.txt` that allows crawling and references the sitemap; staging/preview is `noindex` (`Disallow: /` plus `X-Robots-Tag: noindex`, or an env-driven `indexable` flag). No leftover `Disallow: /` in production. `robots.txt`, `<meta name="robots">` and `X-Robots-Tag` do not contradict each other (a page allowed in robots.txt but `noindex` in meta, or vice versa, reads as an unreliable source to crawlers).
- **How:** Block `WEB-01`: file content, robots/indexable config, live robots and `X-Robots-Tag`.
- **Severity:** blocker if production is blocked from indexing; warning if staging is indexable or the file is missing
- **Fix:** Env-driven robots (`@nuxtjs/robots` with `NUXT_SITE_ENV`, Astro `astro-robots-txt`, Laravel a route returning per-env content).

### WEB-02 Sitemap generated and referenced
- **Applies to:** public
- **Check:** `sitemap.xml` exists, includes dynamic CMS routes, excludes private/utility pages, is referenced from `robots.txt`.
- **How:** Block `WEB-02` and `STACK.has.sitemap_module`; live sitemap head and status.
- **Severity:** warning (info for very small sites)
- **Fix:** `@nuxtjs/sitemap` with a `sources` route, `@astrojs/sitemap`, `spatie/laravel-sitemap`.

### WEB-03 Canonical URLs and host/slash normalisation
- **Applies to:** public
- **Check:** One canonical host (www or not) and one trailing-slash convention; the other variants 301 to it; pages emit `<link rel="canonical">` with the absolute canonical URL; listing pages canonicalise query variants.
- **How:** Block `WEB-03`: canonical/site URL config, redirect rules, live alt-host and slash-variant statuses.
- **Severity:** warning
- **Fix:** Set `site.url` / `site` / `APP_URL`; add a proxy redirect for the non-canonical host; pick a `trailingSlash` setting.

### WEB-04 `<html lang>` set correctly
- **Applies to:** public, internal
- **Check:** The root `lang` attribute is the site language and changes per locale when i18n is used.
- **How:** The rendered value is the `lang=` field of the per-page line in block `WEB-24` (live pages or build output); compare it with the site language. Block `WEB-04` lists where `lang` is set in the source, which is where the fix goes. Without rendered HTML, judge from block `WEB-04` alone.
- **Severity:** warning
- **Fix:** `app.head.htmlAttrs.lang` (Nuxt), `<html lang>` in `index.html` / layout, `useLocaleHead` for i18n.

### WEB-05 Unique title and description per page
- **Applies to:** public
- **Check:** Every page sets a title and description (from CMS fields where applicable); a title template appends the site name; nothing falls back to a generic default. Titles up to about 60 characters with the core topic first, descriptions 120 to 160 characters.
- **How:** Block `WEB-05`: page files with no title/meta call at all, and title template hits. Open two representative pages (home and one dynamic page) to confirm the values are page-specific.
- **Severity:** warning (blocker if the whole site shares one title)
- **Fix:** Per-page meta calls fed by CMS data.

### WEB-06 Open Graph and Twitter cards
- **Applies to:** public
- **Check:** `og:title`, `og:description`, `og:image` (absolute URL, 1200×630), `og:type`, `og:url`, `twitter:card` present; a site-wide default share image exists.
- **How:** Block `WEB-06`: OG hits and share-image candidates.
- **Severity:** warning
- **Fix:** Defaults in the root layout, per-page overrides; `nuxt-og-image` or a static default image.

### WEB-07 Favicons and web manifest
- **Applies to:** public, internal
- **Check:** `favicon.ico`, an SVG or 32px PNG favicon, `apple-touch-icon`, a `site.webmanifest` with name, theme colour and icons. No default framework icon left in place.
- **How:** Block `WEB-07`: icon files and link hits.
- **Severity:** warning (info for the manifest on non-PWA sites)
- **Fix:** Generate a set and register it in the head.

### WEB-08 Custom error page with correct status
- **Applies to:** public, internal
- **Check:** A branded error page distinguishes 404 from 500, links home, and unknown URLs return a real 404 status (not a 200 "not found" page). Dynamic CMS pages throw 404 for unknown slugs. SPA: a catch-all route exists; a real 404 status is not possible and should be noted as `n/a`.
- **How:** Block `WEB-08`: error page files, 404-throwing code, live status of a nonexistent URL.
- **Severity:** warning (blocker if unknown slugs return 200 on an SSR/CMS site)
- **Fix:** `error.vue` + `createError({ statusCode: 404 })`, `404.astro` + `Response` status, Laravel `errors/404.blade.php` + `abort(404)`.

### WEB-09 Images optimised and accessible
- **Applies to:** public
- **Check:** Content images use the framework image component or a CDN transform with width/height or `sizes`, modern formats, lazy loading below the fold, meaningful `alt` (empty for decorative). No multi-MB originals served from `public/`.
- **How:** Block `WEB-09`: `<img>` without alt, image components in use, large raster files.
- **Severity:** warning
- **Fix:** `@nuxt/image`, `astro:assets`, or CDN transforms; add dimensions and alt text.

### WEB-10 Fonts self-hosted with `font-display`
- **Applies to:** public
- **Check:** Web fonts are self-hosted or served by the framework font module, subset, `font-display: swap|optional`, preloaded when critical. No render-blocking third-party font stylesheet.
- **How:** Block `WEB-10`.
- **Severity:** info (warning if a blocking third-party stylesheet is used)
- **Fix:** `@nuxt/fonts` / `astro:fonts` / `@fontsource`, or WOFF2 files in `public/fonts`.

### WEB-11 Structured data where it adds value
- **Applies to:** public
- **Check:** JSON-LD matching what is visible on the page. Minimum for a public business site: `Organization` (or `LocalBusiness`) on the home page with `name`, `url`, `logo`, a postal `address` and `sameAs` links; `FAQPage` wherever a visible FAQ exists; `Product` with `offers` (and `AggregateRating` when reviews are shown) on product pages; `Article`/`BlogPosting` with `datePublished`, `dateModified` and `author` on articles; `BreadcrumbList` on nested pages. Structured data must not claim things the page does not show. AI engines read this directly instead of guessing from marketing copy.
- **How:** Block `WEB-11`: schema code in source; with `--url`, the number of JSON-LD blocks and their `@type` values on the home page. Judge which types the site needs from the page types in block `WEB-05`.
- **Severity:** warning for a public business site with no `Organization` schema, or a visible FAQ without `FAQPage`; info for the rest
- **Fix:** `nuxt-schema-org` (`defineOrganization`, `defineWebPage`, `defineArticle`), a JSON-LD component in the layout, or CMS-driven schema.

### WEB-12 hreflang and locale routing
- **Applies to:** public, i18n
- **Check:** Each page emits `hreflang` alternates including `x-default`; locale prefixes are consistent; default-locale strategy is deliberate; `lang` follows the locale; sitemap includes all locales.
- **How:** Block `WEB-12`. Skip when `STACK.has.i18n` is false.
- **Severity:** warning
- **Fix:** Set the i18n base URL and use the framework locale-head helper in the layout.

### WEB-13 Cookie consent and privacy basics (EU/GDPR)
- **Applies to:** public
- **Check:** If analytics, marketing pixels, embedded maps/videos or chat widgets exist, a consent mechanism gates them (nothing non-essential fires before consent); a privacy/cookie page exists and is linked from the footer; forms collecting personal data state the purpose.
- **How:** Block `WEB-13`: trackers/embeds, consent mechanism, privacy page files. Trackers without any consent hit is the finding.
- **Severity:** warning (blocker for marketing pixels with no consent at all)
- **Fix:** Consent-gated script loading (`@nuxt/scripts` triggers, a consent library); add the policy page.

### WEB-14 Redirect map for migrated sites
- **Applies to:** public, migration
- **Check:** Old URLs 301 to their new equivalents (routeRules, proxy map, CMS redirects); the list was reviewed against the old sitemap/analytics.
- **How:** Block `WEB-14`: redirect rules, `_redirects`, `vercel.json`. If README does not mention a migration and there are no redirects, report `n/a (assumed greenfield)`.
- **Severity:** warning
- **Fix:** A redirect table in config or the CMS.

### WEB-15 Accessibility basics
- **Applies to:** public, internal
- **Check:** One `<h1>` per page and a logical heading hierarchy (H1 → H2 → H3, no skipped levels); semantic HTML (`<article>`, `<section>`, `<nav>`, lists) rather than nested `<div>`s, which also matters for AI crawlers extracting content; interactive elements are real `<button>`/`<a>`; inputs have labels; focus outline not globally removed without replacement; landmarks (`<main>`, `<nav>`) exist; body text contrast not obviously low.
- **How:** Block `WEB-15`: `outline: none` hits, clickable div/span hits, layouts without `<main>`, pages with more than one `<h1>`. Open one form component to check labels (judgment).
- **Severity:** warning
- **Fix:** Replace clickable divs with buttons, add `:focus-visible` styles, labels and landmarks.

### WEB-16 Performance sanity check
- **Applies to:** public
- **Check:** Client JS entry is reasonable (roughly under 250 kB gzipped for a content site); no heavy libraries (moment, full lodash, jQuery, chart libs) shipped globally; large third-party scripts deferred. Measured scores are in WEB-23.
- **How:** Block `WEB-16`: build output sizes if a build exists, heavy dependencies.
- **Severity:** info (warning if the entry bundle is clearly oversized or a heavy library is global)
- **Fix:** Lazy-load heavy components, replace heavy libraries, move analytics behind consent/idle.

---

## AI / GEO readiness

Generative engines (ChatGPT, Perplexity, Claude, Gemini, Google AI Overviews) fetch pages with their own crawlers, do not execute JavaScript, give up on slow servers, and extract content from clean semantic HTML and structured data. These items check the technical side; content strategy (topic clusters, earned media, share-of-voice monitoring) is out of scope for a delivery audit and belongs to a separate offering. Sources in `knowledge/`: "Jak přežít v éře GEO" (Váš Hosting, 2026) and the aiworthy.com AI Content Readiness scan methodology (crawler access, structured data, content depth, extractability, trust, answer alignment).

### WEB-17 AI crawlers are handled deliberately
- **Applies to:** public
- **Check:** `robots.txt` treats AI crawlers (`GPTBot`, `OAI-SearchBot`, `ChatGPT-User`, `ClaudeBot`, `PerplexityBot`, `Google-Extended`, `Bingbot`) according to the client's decision, and the default for a public marketing site is *allow* at least the search/answer bots (`OAI-SearchBot`, `PerplexityBot`, `ClaudeBot`). Nothing blocks them unintentionally: Cloudflare "AI Crawl Control" (on by default for zones created after July 2025), WAF bot-fight rules, or a hosting firewall returning 403 to bot user agents.
- **How:** Block `WEB-17`: AI user agents in `robots.txt`; with `--url`, status and body size for a `GPTBot` request versus a browser request. A 403/503 or a much smaller body for the bot is the finding. If the client explicitly wants AI training bots blocked, `GPTBot`/`Google-Extended` disallow is fine; note the decision in the report.
- **Severity:** warning (info when the client asked to block AI)
- **Fix:** Explicit `User-agent:` groups in `robots.txt`; allow the bots in the Cloudflare dashboard; exempt known crawler UAs from WAF challenges.

### WEB-18 Entry pages render content without JavaScript
- **Applies to:** public
- **Check:** Key entry pages (home, main category/landing pages, articles) deliver their content in the initial HTML: SSR, hybrid rendering or prerendering. A client-only SPA hands crawlers an empty `<div id="app">`, which is invisible to AI crawlers (they do not run JS) and slow for search engines.
- **How:** `STACK.ssr` is the short answer. Block `WEB-18`: prerender/SSG tooling in a SPA (`vite-ssg`, `vite-plugin-prerender`, `prerender-spa-plugin`); with `--url`, text length and `<h1>` presence in the raw HTML of the home page fetched without JavaScript. An HTML body under ~500 characters of text or no `<h1>` is the finding.
- **Severity:** blocker for a public content/marketing site delivered as a client-only SPA; warning if only some entry pages are client-rendered; `n/a` for `internal`
- **Fix:** Nuxt/Astro SSR or `routeRules` prerender for entry pages; for an existing Vue SPA, `vite-ssg` for static pages or move the marketing pages to Nuxt/Astro.

### WEB-19 Server responds fast and over a modern protocol
- **Applies to:** public
- **Check:** TTFB (time to first byte) under 500 ms for the home page and one content page from a cold request; HTTP/2 at minimum, HTTP/3 advertised (`alt-svc: h3`) where the CDN/proxy supports it. Crawlers deprioritise slow origins and may fetch only part of the site.
- **How:** Block `WEB-19` (live only): `time_starttransfer`, `http_version`, `alt-svc` for `--url`. Without a URL: `not-verified (no --url)`. Static SSG sites on a CDN normally pass; SSR without caching (`routeRules` swr/isr, proxy cache) is the usual cause of slow TTFB.
- **Severity:** warning for TTFB over 500 ms or HTTP/1.1 only; info for missing HTTP/3
- **Fix:** Cache SSR responses (`swr`/`isr` in `routeRules`, nginx `proxy_cache`), prerender static pages, put the site behind a CDN with HTTP/3, check origin sizing.

### WEB-20 `llms.txt` published
- **Applies to:** public
- **Check:** A `/llms.txt` (Markdown summary of the site with links to key pages) exists. No major AI platform officially reads it yet; it is a cheap forward-looking measure, not a requirement.
- **How:** Block `WEB-20`: file in `public/`; with `--url`, live status.
- **Severity:** info
- **Fix:** Add `public/llms.txt` following llmstxt.org: one H1 with the site name, a short blockquote summary, H2 sections with links and one-line descriptions.

### WEB-21 Key content is extractable from the raw HTML
- **Applies to:** public
- **Check:** On entry pages, a real lead paragraph (two or three sentences saying what this is and for whom) follows the `<h1>` directly, before any section break, so the answer sits in the first third of the document. Content behind accordions, tabs and "read more" toggles (FAQ answers above all) is present in the server-rendered HTML and only hidden with CSS, not rendered on click. The page has a `<main>` landmark and the navigation/footer are not most of the text. Images that carry information have descriptive `alt`.
- **How:** Block `WEB-21`: source-side, accordion/FAQ/tab components that use `v-if`/conditional rendering for their body instead of `v-show`/CSS; with `--url`, the first paragraph after `<h1>` on the home page, the count of `<details>`/accordion-like markers, the count of visible FAQ answers in the raw HTML, and the share of words inside `<main>`. Open the FAQ/accordion component if one exists.
- **Severity:** warning (blocker if a public site's FAQ or main content only appears after client-side interaction)
- **Fix:** Render accordion bodies with `v-show` or `<details>`; put a lead paragraph under the `<h1>`; wrap page content in `<main>`.

### WEB-22 Freshness, authorship and trust signals
- **Applies to:** public
- **Check:** Pages expose a freshness signal (`dateModified` in schema or a visible "updated" date on articles and pricing pages); articles have a visible author and the site has an about/team page that identifies the company (legal name, address, IČO) in text and in `Organization` schema; reviews or ratings shown on the site are marked up (`AggregateRating`, `Review`); claims link to sources where relevant. AI engines weight these when deciding whether to cite a page over a competitor's.
- **How:** Block `WEB-22`: `dateModified`/`author`/`AggregateRating` in source; with `--url`, the same in the live home page HTML plus links to about/contact/imprint pages. This is partly a content responsibility of the client: report missing items as `info` with a note "content to be supplied by client" unless the CMS/template makes it impossible to add.
- **Severity:** info (warning when the template has no place for author/date on article pages)
- **Fix:** Add `dateModified` and `author` to the article template and schema; company identity block in the footer; review markup where reviews exist.

---

## Measured quality (live only)

### WEB-23 Lighthouse scores on the live site
- **Applies to:** public, internal
- **Check:** Lighthouse (mobile, default throttling) on the home page: performance ≥ 80, accessibility ≥ 90, best practices ≥ 90, SEO ≥ 90. Lab metrics: LCP ≤ 2.5 s, CLS ≤ 0.1, TBT ≤ 300 ms. Scores are a summary signal; the failing audits underneath are what gets fixed.
- **How:** Block `WEB-23` (live only, skipped in `--quick`): category scores, lab metrics, top performance opportunities, failing accessibility/best-practices/SEO audits. The full JSON report path is printed; open it only if a failing audit needs detail. Without `--url` or without Chrome: `not-verified` with the reason from the block. One run on one page has noise of a few points; treat a score within 5 points of a threshold as borderline, not as a finding.
- **Severity:** blocker for performance below 50 on a public content site; warning for performance below 80, accessibility below 90 or SEO below 90, or LCP/CLS/TBT over the limits; info for best practices below 90
- **Fix:** Follow the listed opportunities: image sizing/format (WEB-09), font loading (WEB-10), render-blocking third-party scripts (SEC-15, WEB-13), unused JS (WEB-16), missing alt/labels/contrast (WEB-15), missing meta (WEB-05), invalid markup (WEB-24).

---

## HTML validity

### WEB-24 Rendered HTML is valid
- **Applies to:** public, internal
- **Check:** Every page starts with `<!DOCTYPE html>` and has `<html lang>` matching the site language, `<meta charset="utf-8">`, a viewport meta tag and a `<title>`. The markup has no errors from html-validate's `standard` and `a11y` presets: no duplicate `id`s, no elements where the content model forbids them (`<div>` inside `<button>` or `<p>`), no stray or misnested end tags, no missing required attributes (`alt`, `lang`), buttons with a `type` and accessible text. The validated HTML is the delivered output (live pages, or build output), not the templates.
- **How:** Block `WEB-24` (runs in `--quick` too): the source line (`live`, `build` or `static`), one line per page with doctype/lang/charset/viewport/title and error counts, then the rules by count with up to two `page:line:column` examples each. Report one finding per rule, not per occurrence: the same error on every page comes from a shared layout or component, so say so and give the count. Rules marked `[warn]` are advisory and go into the finding only as a note. If the source is `build` and the build date is older than the last commit, mention that the output may be stale. Source `static` covers only the HTML shell (a Vite SPA's `index.html`). `(nothing to validate …)` or `(html-validate unavailable …)`: `not-verified` with that reason.
- **Severity:** warning when any page is missing doctype, `lang`, charset or viewport, or when html-validate reports errors (not `[warn]`); info when only `[warn]` rules fire
- **Fix:** Follow the rule documentation at `https://html-validate.org/rules/<rule>.html`. Typical fixes: unique `id`s (generate them with `useId()` in Vue 3.5+, or derive them from a slug plus a suffix), `<span>` instead of `<div>` inside buttons and inline elements, `type="button"` on non-submit buttons, `alt` on every `<img>` (empty for decorative ones), `lang`/charset/viewport in the app head config (WEB-04).

---

## Forms

### WEB-25 Forms validate input and report errors accessibly
- **Applies to:** public, internal
- **Check:** Every form validates before submit, with native constraints (`required`, `type="email|tel|url"`, `pattern`, `min`/`max`, `maxlength`) or a schema-driven library (vee-validate, FormKit, Nuxt UI `UForm` with a zod/valibot schema, Laravel Precognition), and the rules mirror the server rules (SEC-06, SEC-19) so input that passes the client is not rejected later with a generic error. Errors are shown as text next to the field (not by colour alone), tied to it with `aria-invalid` and `aria-describedby`/`aria-errormessage`, and announced (`role="alert"`/`aria-live`) or focus moves to the first invalid field. Server validation errors (422) are mapped back to the fields; entered values survive a failed submit (Laravel `old()`). The submit button shows a pending state and blocks double submission; both success and failure are shown to the user. Fields have the right `type`, `autocomplete` (`name`, `email`, `tel`, `street-address`, `postal-code`) and `inputmode`. `novalidate` only where a JS validator replaces the native one. Labels are covered by WEB-15.
- **How:** Block `WEB-25`: one line per template with forms or fields (keys explained by the `legend:` line: field counts, `req`, `typed`, `ac`, `nv`, `schema`, ARIA error wiring `aria`/`desc`/`live`, `err` mentions), forms whose fields all sit in custom components, then validation libraries and client-side handling of server errors (422 mapping, `@error`, `old()`). A `form` line with text fields and `req=0 schema=no err=0` is a finding without opening it; so is `nv=yes schema=no` with no validation library. Fields inside a wrapper component (`forms/Input.vue`) take their rules from the usage site; judge there. UI libraries (Nuxt UI `UFormField`, Vuetify, Element Plus, Quasar, PrimeVue, FormKit) render messages and `aria-invalid` themselves, so zero ARIA counts there are not a finding. Open at most two form components (the public contact/lead/order form and the most complex form) to confirm error display, server-error mapping, pending state and the success/failure message.
- **Severity:** warning (blocker when a public lead, order or registration form can fail without telling the user, e.g. errors caught and dropped, no failure state); info for missing `autocomplete`/`type`/`inputmode` only
- **Fix:** Use one schema for client and server (zod/valibot shared between the form and the handler, or Laravel Precognition); render the field error under the input with an `id` referenced by `aria-describedby` and set `aria-invalid`; map 422 responses to field errors; disable the submit button while pending and show an explicit success and failure message; add `type`, `autocomplete` and `inputmode` to contact fields.
