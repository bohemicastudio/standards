# Vue 3 + Vite SPA (client-only, usually behind login)

| Concept | Where |
|---|---|
| App config | `vite.config.ts` (`base`, `build.sourcemap`, `server.proxy`); `src/main.ts` |
| Env | `import.meta.env.VITE_*` — **everything is public**, baked into the bundle at build time; `.env.example` |
| Routes | `src/router/**` (vue-router); route guards `router.beforeEach` |
| Head / meta | `index.html` (`<title>`, `<meta>`, `<link rel="icon">`); `@unhead/vue` or `@vueuse/head` if per-route |
| Layout shell | `src/App.vue`, `src/layouts/**` |
| Forms | `src/components/**`, `src/views/**`; vee-validate / Vuelidate / FormKit or UI-library rules (Vuetify `:rules`, Element Plus `el-form`); length and validation rules must match the API project |
| Server handlers | none in the repo; the API is a separate project (audit it separately with exposure `api`) |
| Auth | token storage in `src/stores/**`, `src/composables/useAuth*`, axios/ofetch interceptors |
| Error page | a catch-all route (`path: '/:pathMatch(.*)*'`); the server returns the SPA for unknown paths, so a real 404 status is impossible without SSR |
| Static files | `public/` |
| Build output | `dist/` (`dist/assets/*` hashed) |
| Headers / caching | reverse proxy or hosting config only (nginx, `_headers`, `vercel.json`); `dist/index.html` must be `no-cache`, `dist/assets/**` immutable |
| History fallback | nginx `try_files $uri $uri/ /index.html;` or equivalent |
| Images / fonts | plain `<img>`; `vite-imagetools` or CDN; fonts in `public/fonts` or `@fontsource/*` |
| Third-party scripts | `index.html` or `src/main.ts` |

Gotchas
- No secret belongs in a SPA. Any `VITE_*` variable named like a secret is a finding (SEC-03).
- Tokens in `localStorage` are readable by any XSS; prefer httpOnly cookies set by the API when feasible (SEC-10 applies to the API project).
- With exposure `internal`, most of `web-standards.md` is out of scope; still check WEB-04, WEB-07, WEB-08 (fallback route), WEB-15, WEB-24, WEB-25.
- Sourcemaps: `build.sourcemap: true` ships original source (SEC-17).
