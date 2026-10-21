# Nuxt 3 / 4 (SSR or hybrid)

| Concept | Where |
|---|---|
| App config | `nuxt.config.ts` (`app.head`, `runtimeConfig`, `routeRules`, `nitro`, `modules`, `site`) |
| Env / secrets | `runtimeConfig` (private) vs `runtimeConfig.public`; env vars `NUXT_*` / `NUXT_PUBLIC_*`; `.env.example` |
| Pages / routes | `pages/**` (Nuxt 3) or `app/pages/**` (Nuxt 4); `definePageMeta` |
| Head / meta | `app.head` in config, `useHead` / `useSeoMeta` in `app.vue`, layouts, pages |
| Layout shell | `app.vue`, `layouts/*.vue` |
| Server handlers | `server/api/**`, `server/routes/**` (h3: `readBody`, `getQuery`, `readValidatedBody`) |
| Forms | components with `<form>` / `<UForm>` (Nuxt UI, `:schema` + `UFormField`), FormKit, vee-validate `useForm`; share the zod/valibot schema with `server/api/**` via `shared/` (Nuxt 4) or `utils/` |
| Server middleware | `server/middleware/*.ts` (runs on every request) |
| Route middleware (client+SSR) | `middleware/*.ts`, `*.global.ts` for all pages |
| Error page | `error.vue`; throw `createError({ statusCode })` for 404 |
| Static files | `public/` (robots.txt, favicons, share image) |
| Build output | `.output/` (`.output/public/_nuxt` = hashed client assets, `.output/server/index.mjs` = entry) |
| Headers | `routeRules['/**'].headers`, `nuxt-security` module, or reverse proxy |
| Caching | `routeRules` (`swr`, `isr`, `prerender`, `headers`), Nitro sets immutable cache on `/_nuxt/**` |
| Images | `@nuxt/image` (`<NuxtImg>`, `<NuxtPicture>`) |
| Fonts | `@nuxt/fonts` or `public/fonts` + `@font-face` in `assets/` |
| SEO modules | `@nuxtjs/seo` bundle: `@nuxtjs/sitemap`, `@nuxtjs/robots`, `nuxt-schema-org`, `nuxt-og-image`; needs `site.url` |
| i18n | `@nuxtjs/i18n` (`strategy`, `baseUrl`, `useLocaleHead`) |
| Third-party scripts | `@nuxt/scripts` (`useScript`, consent triggers) |
| Cookies | `setCookie(event, ...)` server-side; `useCookie` client (never for secrets) |
| Deploy | Nitro preset (`node-server` default); start `node .output/server/index.mjs`; `NITRO_PORT`, `NITRO_HOST` |

Gotchas
- Nuxt 4 moved app code under `app/` (`app/pages`, `app/components`, `app/app.vue`). Evidence blocks cover both layouts.
- `ssr: false` in config turns the whole app into an SPA; web-standards items then behave like `vue-spa.md`.
- Anything in `runtimeConfig.public` is serialised into the HTML payload.
- `nuxt-security` v2 sets HSTS, CSP (with nonces), X-Frame-Options, rate limiter and more by default; check it is not globally disabled with `security: false`.
