# Astro (static, hybrid or server)

| Concept | Where |
|---|---|
| App config | `astro.config.mjs` (`site`, `output`, `adapter`, `integrations`, `trailingSlash`, `redirects`, `image`) |
| Env | `import.meta.env.*`; `PUBLIC_*` is client-visible, everything else server-only; `astro:env` schema in config; `.env.example` |
| Pages / routes | `src/pages/**` (`.astro`, `.md`, `.mdx`); dynamic `[slug].astro` with `getStaticPaths` |
| Head / meta | `<head>` in `src/layouts/*.astro`; `astro-seo` or a `Seo.astro` component |
| Layout shell | `src/layouts/**` |
| Server handlers | `src/pages/api/**` (endpoints exporting `GET`/`POST`), only meaningful with `output: 'server'` or `'hybrid'` |
| Middleware | `src/middleware.ts` (`defineMiddleware`) |
| Error page | `src/pages/404.astro`, `src/pages/500.astro`; `return new Response(null, { status: 404 })` in dynamic pages |
| Static files | `public/` |
| Build output | `dist/` (`dist/_astro/*` hashed assets) |
| Headers / caching | hosting/proxy config; static output has no runtime headers of its own |
| Images | `astro:assets` (`<Image>`, `<Picture>`), `image.domains` for remote |
| Fonts | `astro:fonts` (5.x) or `@fontsource/*` |
| Sitemap / robots | `@astrojs/sitemap` (needs `site`), `public/robots.txt` or `astro-robots-txt` |
| i18n | `i18n` in config (`defaultLocale`, `locales`, `routing`) |
| Redirects | `redirects` in config, or host-level |

Gotchas
- Static output (`output: 'static'`) means every server-side item (SEC-06, SEC-07, SEC-09, SEC-11, SEC-12, DEP-13) is out of scope unless there is an SSR adapter.
- `set:html` is the `v-html` equivalent (SEC-08).
- `site` must be set for canonical URLs and sitemap to be absolute (WEB-02, WEB-03).
