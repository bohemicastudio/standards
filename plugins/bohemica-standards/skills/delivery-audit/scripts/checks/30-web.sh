#!/usr/bin/env bash
# checks/30-web.sh — evidence blocks for the Web Standards checklist.
# Sourced by collect-evidence.sh; helpers and paths come from lib/common.sh.

block WEB-01
for f in public/robots.txt static/robots.txt robots.txt; do [ -f "$f" ] && { show "$f" 20; break; }; done
# shellcheck disable=SC2086
g 'robots|indexable|noindex|X-Robots-Tag|SITE_ENV|site\s*:\s*\{' $CONFIG_FILES $NGINX_FILES $APP_DIRS 2>/dev/null
if [ -n "$URL" ]; then note "live robots.txt:"; curl -s --max-time 15 -A "bohemica-standards-audit" "$URL/robots.txt" | head -n 15; note "live X-Robots-Tag:"; curl_head "$URL" | grep -i x-robots-tag || echo "(no header)"; fi

block WEB-02
# shellcheck disable=SC2086
g 'sitemap' package.json $CONFIG_FILES routes 2>/dev/null
lsx server/api/__sitemap__* server/routes/sitemap* src/pages/sitemap* public/sitemap*
if [ -n "$URL" ]; then note "live sitemap.xml:"; curl -s --max-time 15 -A "bohemica-standards-audit" "$URL/sitemap.xml" | head -n 12; note "status:"; curl_status "$URL/sitemap.xml"; fi

block WEB-03
# shellcheck disable=SC2086
g 'canonical|site\s*:\s*\{|siteUrl|site\.url|trailingSlash|APP_URL|SITE_URL' $CONFIG_FILES $APP_DIRS .env.example 2>/dev/null
# shellcheck disable=SC2086
g 'redirect|rewrite|server_name' $NGINX_FILES $CONFIG_FILES 2>/dev/null
if [ -n "$URL" ]; then
  HOST="${URL#https://}"; HOST="${HOST#http://}"
  case "$HOST" in www.*) ALT="https://${HOST#www.}" ;; *) ALT="https://www.$HOST" ;; esac
  note "live alt host $ALT:"; curl_status "$ALT/"
  note "live trailing slash variants:"; curl_status "$URL/"; curl_status "$URL"
fi

block WEB-04
# shellcheck disable=SC2086
g 'htmlAttrs|<html[^>]*lang|lang\s*:|useLocaleHead' $CONFIG_FILES $APP_DIRS 2>/dev/null

block WEB-05
note "page files without any title/meta call:"
PAGE_DIRS="$(existing pages app/pages src/pages resources/views)"
# shellcheck disable=SC2086
[ -n "$PAGE_DIRS" ] && gl 'useSeoMeta|useHead|useServerSeoMeta|definePageMeta\(\{[^}]*title|<title|<Head|<SEO|<Seo|@section\(.title|<Title' $PAGE_DIRS --include='*.vue' --include='*.astro' --include='*.php' || echo "(no page directories)"
note "title template / defaults:"
# shellcheck disable=SC2086
g 'titleTemplate|title\s*:|<title' $CONFIG_FILES app.vue src/layouts src/components layouts 2>/dev/null

block WEB-06
# shellcheck disable=SC2086
g 'ogImage|og:image|ogTitle|twitterCard|twitter:card|defineOgImage|property="og:' $CONFIG_FILES $APP_DIRS 2>/dev/null
note "share image candidates in public/:"
ls public/ 2>/dev/null | grep -iE 'og|share|social' || echo "(none)"

block WEB-07
note "icons in public/:"
ls public/ 2>/dev/null | grep -iE 'favicon|apple-touch|icon|manifest|webmanifest' || echo "(none)"
# shellcheck disable=SC2086
g 'apple-touch-icon|rel="icon"|rel: .icon|manifest' $CONFIG_FILES $APP_DIRS 2>/dev/null

block WEB-08
ls error.vue app/error.vue src/pages/404.astro src/pages/500.astro resources/views/errors/*.blade.php 2>/dev/null || echo "(no custom error page file found)"
# shellcheck disable=SC2086
g 'createError\(|abort\(404|Astro\.redirect|status: 404|return new Response\(null, \{ status: 404' pages app/pages src/pages composables $SERVER_DIRS 2>/dev/null
if [ -n "$URL" ]; then note "live 404 status:"; curl_status "$URL/this-page-does-not-exist-bohemica-audit"; fi

block WEB-09
note "<img> without alt:"
# shellcheck disable=SC2086
grep -rnIE $EXCL -e '<img\b' $APP_DIRS 2>/dev/null | grep -vE 'alt=|:alt=' | head -n 20 || true
echo "(end)"
note "image components in use:"
# shellcheck disable=SC2086
g '<NuxtImg|<NuxtPicture|<Image\b|<Picture\b|astro:assets|@nuxt/image|vite-imagetools' $APP_DIRS package.json 2>/dev/null
note "large raster images in public/ (>500k):"
find public static src/assets -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' \) -size +500k 2>/dev/null | head -n 15 || true
echo "(end)"

block WEB-10
# shellcheck disable=SC2086
g 'fonts\.googleapis|fonts\.gstatic|@font-face|font-display|@nuxt/fonts|@fontsource|astro:fonts|bunny\.net' $CONFIG_FILES $APP_DIRS assets src/styles 2>/dev/null

block WEB-11
# shellcheck disable=SC2086
g 'application/ld\+json|useSchemaOrg|defineArticle|defineOrganization|defineWebSite|schema-org|@type' $CONFIG_FILES $APP_DIRS 2>/dev/null
if [ -n "$URL" ]; then
  LIVE_HTML="$(curl -s --max-time 20 -L -A "Mozilla/5.0 (compatible; ClaudeBot/1.0; +claudebot@anthropic.com)" "$URL/" 2>/dev/null)"
  note "live home page JSON-LD blocks: $(printf '%s' "$LIVE_HTML" | grep -oi 'application/ld+json' | wc -l | tr -d ' ')"
  note "live @type values:"; printf '%s' "$LIVE_HTML" | grep -oE '"@type"\s*:\s*"[A-Za-z]+"' | sort | uniq -c | sort -rn | head -n 15 || echo "(none)"
  note "live schema fields of interest:"; printf '%s' "$LIVE_HTML" | grep -oE '"(address|postalCode|aggregateRating|dateModified|datePublished|author|sameAs|logo)"' | sort | uniq -c | head -n 10 || echo "(none)"
fi

block WEB-12
# shellcheck disable=SC2086
g 'i18n|hreflang|useLocaleHead|defaultLocale|locales\s*:' $CONFIG_FILES $APP_DIRS package.json 2>/dev/null

block WEB-13
note "trackers / embeds:"
# shellcheck disable=SC2086
g 'gtag|googletagmanager|fbq\(|facebook\.net|hotjar|clarity|smartlook|youtube\.com/embed|youtube-nocookie|maps\.google|google\.com/maps|leadhub|ecomail|mailchimp' $APP_DIRS $CONFIG_FILES 2>/dev/null
note "consent mechanism:"
# shellcheck disable=SC2086
g 'consent|cookieconsent|cookie-consent|CookieBanner|cookiebot|useScriptTriggerConsent|gdpr' $APP_DIRS $CONFIG_FILES package.json 2>/dev/null
note "privacy/cookie page:"
find . $FIND_EXCL -type f \( -iname '*privacy*' -o -iname '*cookie*' -o -iname '*gdpr*' -o -iname '*ochrana*' -o -iname '*osobn*' \) 2>/dev/null | head -n 10 || true
echo "(end)"

block WEB-14
# shellcheck disable=SC2086
g 'redirect|statusCode: 301|rewrite \^|return 301|Redirect::|->redirect' $CONFIG_FILES $NGINX_FILES routes $SERVER_DIRS 2>/dev/null
[ -f public/_redirects ] && show public/_redirects 20
[ -f vercel.json ] && grep -n redirect vercel.json

block WEB-15
note "focus outline removed:"
# shellcheck disable=SC2086
g 'outline\s*:\s*(none|0)' $APP_DIRS assets src/styles src/assets 2>/dev/null
note "clickable divs/spans:"
# shellcheck disable=SC2086
g '<(div|span)[^>]*@click|<(div|span)[^>]*onclick' $APP_DIRS 2>/dev/null
note "layouts without <main>:"
# shellcheck disable=SC2086
gl '<main|<NuxtLayout|<slot' layouts app/layouts src/layouts --include='*.vue' --include='*.astro' 2>/dev/null
echo "(end)"
note "h1 count per page file (first 20):"
# shellcheck disable=SC2086
[ -n "$PAGE_DIRS" ] && grep -rcIE $EXCL -e '<h1\b' $PAGE_DIRS 2>/dev/null | grep -vE ':1$' | head -n 20 || true
echo "(end)"

block WEB-16
note "build output size:"
for d in .output/public/_nuxt dist/assets dist/_astro public/build/assets; do
  [ -d "$d" ] && { du -sh "$d" 2>/dev/null; ls -S "$d"/*.js 2>/dev/null | head -n 5 | xargs -I{} sh -c 'printf "%8s  %s\n" "$(du -k "{}" | cut -f1)k" "{}"'; }
done
note "heavy dependencies:"
[ -f package.json ] && grep -nE '"(moment|lodash|jquery|chart\.js|three|gsap|swiper|@fortawesome/fontawesome-free|bootstrap|core-js|axios|firebase|@mui/material|antd)"' package.json || echo "(none of the usual suspects)"
echo "(Lighthouse: see block WEB-23)"

block WEB-25
note "templates with forms or fields (forms first):"
# shellcheck disable=SC2046
form_scan forms $(template_files)
note "validation / form libraries (package.json):"
[ -f package.json ] && grep -nE '"(vee-validate|@vee-validate/[^"]+|@vuelidate/[^"]+|vuelidate|zod|valibot|yup|joi|@formkit/[^"]+|@tanstack/[a-z]+-form|react-hook-form|formik|laravel-precognition[^"]*|@nuxt/ui|@nuxt/ui-pro|vuetify|element-plus|quasar|primevue|naive-ui)"' package.json || echo "(none)"
note "client handling of server validation errors (422 / field errors):"
# shellcheck disable=SC2086
g '(status|statusCode|code)\s*[!=]==?\s*422|case\s+422|setErrors\(|setFieldError|data\??\.errors|_data\??\.errors|\$errors->|@error\(|old\(' $APP_DIRS
