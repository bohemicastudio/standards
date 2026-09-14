# Laravel (10 / 11 / 12)

| Concept | Where |
|---|---|
| App config | `config/*.php` (`app.php`, `session.php`, `cors.php`, `filesystems.php`, `logging.php`), `.env.example` |
| Env / secrets | `.env` via `env()` **only inside `config/`**; `config()` elsewhere; `APP_KEY`, `APP_DEBUG`, `APP_URL` |
| Routes | `routes/web.php`, `routes/api.php`, `routes/console.php`; middleware groups in `bootstrap/app.php` (11+) or `app/Http/Kernel.php` (10) |
| Controllers | `app/Http/Controllers/**` |
| Validation | `app/Http/Requests/*` (FormRequest) or `$request->validate()` |
| Auth / authorization | `auth` / `auth:sanctum` middleware on routes, `app/Policies/**`, `Gate`, `$this->authorize()` |
| Views / head | `resources/views/**.blade.php` (`layouts/app.blade.php` for `<head>`), `{!! !!}` = unescaped output |
| Frontend assets | Vite via `vite.config.js`, `resources/js`, `resources/css`; built into `public/build/` |
| Error pages | `resources/views/errors/{404,500,503}.blade.php`; `abort(404)` |
| Static files | `public/` (also `public/storage` symlink from `storage:link`) |
| Uploads | `Storage::disk()`, `$request->file()->store()`; `config/filesystems.php` |
| Rate limiting | `RateLimiter::for()` in `AppServiceProvider` / `bootstrap/app.php`, `throttle:` middleware |
| Cookies / session | `config/session.php` (`secure`, `http_only`, `same_site`), `SESSION_DRIVER` |
| CORS | `config/cors.php` (`allowed_origins`) |
| Headers | reverse proxy, or a middleware (e.g. `spatie/laravel-csp`, custom `SecurityHeaders`) |
| Logging / errors | `config/logging.php`, `sentry/sentry-laravel`, `bootstrap/app.php` exception handling |
| Background work | queue worker (`php artisan queue:work`, Horizon), scheduler (`schedule:run` cron) |
| Deploy steps | `composer install --no-dev --optimize-autoloader`, `php artisan migrate --force`, `config:cache`, `route:cache`, `view:cache`, `storage:link` |
| Health | `/up` route (11+), or a custom `/health` |
| Tests | `tests/`, PHPUnit or Pest |

Gotchas
- `APP_DEBUG=true` in production shows full stack traces and env values (SEC-13, blocker).
- Debug tools (`telescope`, `horizon`, `debugbar`, `nova`) must be gated or disabled in production (SEC-18).
- Mass assignment: models with `$guarded = []` plus `Model::create($request->all())` (SEC-06).
- The web server must point at `public/`, never at the project root (DEP-07).
- The `php artisan optimize` family must run at deploy, and the queue worker must restart after deploy (`queue:restart`).
