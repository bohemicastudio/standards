# Strapi (v4 / v5, headless CMS = API exposure)

| Concept | Where |
|---|---|
| App config | `config/server.ts`, `config/admin.ts`, `config/middlewares.ts`, `config/database.ts`, `config/plugins.ts`, `config/api.ts` |
| Env / secrets | `env()` helper in `config/*`; `APP_KEYS`, `API_TOKEN_SALT`, `ADMIN_JWT_SECRET`, `TRANSFER_TOKEN_SALT`, `JWT_SECRET`, DB creds; `.env.example` |
| Content types | `src/api/<name>/content-types/<name>/schema.json` |
| Routes | `src/api/<name>/routes/*.ts` (core routers + custom); `config.policies`, `config.middlewares` per route |
| Controllers / services | `src/api/<name>/controllers`, `src/api/<name>/services` |
| Validation | `ctx.request.body` in custom controllers; core routes validate against the schema |
| Auth / authorization | Users & Permissions plugin roles (Public / Authenticated), API tokens (Settings → API Tokens), policies in `src/policies` or `src/api/*/policies` |
| Middleware | `config/middlewares.ts` (`strapi::security` = CSP/headers, `strapi::cors`, `strapi::body` limits); custom in `src/middlewares` |
| Uploads | Upload plugin, provider in `config/plugins.ts` (local `public/uploads` vs S3); size limits in `strapi::body` |
| Rate limiting | not built in for the content API; add `koa-ratelimit` middleware or do it at the proxy |
| Admin panel | `/admin` — must not be publicly reachable without a strong password policy; consider an IP allowlist at the proxy |
| Headers / CORS | `strapi::security` and `strapi::cors` entries in `config/middlewares.ts` |
| Build / deploy | `strapi build` then `strapi start` with `NODE_ENV=production`; `public/uploads` must persist (volume or S3) |
| Health | `GET /_health` (returns 204) |
| Logging | `config/logger.ts` (v4), pino |

Gotchas
- Public role permissions on `find` / `findOne` expose whole collections (SEC-07).
- Default `strapi::cors` origin is `*` (SEC-14).
- `populate=*` from an untrusted client can leak private relations (SEC-07).
- Media in `public/uploads` on a container without a volume is lost on redeploy (DEP-04).
