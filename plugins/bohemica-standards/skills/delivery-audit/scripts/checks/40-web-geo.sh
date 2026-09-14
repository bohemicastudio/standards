#!/usr/bin/env bash
# checks/40-web-geo.sh — evidence blocks for the Ai / Geo Readiness checklist.
# Sourced by collect-evidence.sh; helpers and paths come from lib/common.sh.

block WEB-17
note "AI crawler rules in robots.txt:"
ROBOTS="$(for f in public/robots.txt static/robots.txt robots.txt; do [ -f "$f" ] && { echo "$f"; break; }; done)"
if [ -n "$ROBOTS" ]; then
  grep -niE -B1 -A3 'GPTBot|OAI-SearchBot|ChatGPT-User|ClaudeBot|anthropic-ai|PerplexityBot|Google-Extended|Bingbot|CCBot|Applebot' "$ROBOTS" | head -n 30 || echo "(no AI-specific user-agent groups — default rules apply to all bots)"
else
  echo "(no robots.txt in repo)"
fi
# shellcheck disable=SC2086
g 'GPTBot|ClaudeBot|PerplexityBot|Google-Extended|ai.*crawl|bot_management|challenge' $CONFIG_FILES $NGINX_FILES 2>/dev/null
if [ -n "$URL" ]; then
  note "live: browser UA vs GPTBot UA (status, bytes):"
  printf 'browser: '; curl -s -o /dev/null -w '%{http_code} %{size_download}\n' --max-time 20 -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36" "$URL/" 2>&1
  printf 'GPTBot:  '; curl -s -o /dev/null -w '%{http_code} %{size_download}\n' --max-time 20 -L -A "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko); compatible; GPTBot/1.2; +https://openai.com/gptbot" "$URL/" 2>&1
  printf 'ClaudeBot: '; curl -s -o /dev/null -w '%{http_code} %{size_download}\n' --max-time 20 -L -A "Mozilla/5.0 (compatible; ClaudeBot/1.0; +claudebot@anthropic.com)" "$URL/" 2>&1
  note "live robots.txt AI groups:"; curl -s --max-time 15 -A "bohemica-standards-audit" "$URL/robots.txt" | grep -niE -A3 'GPTBot|OAI-SearchBot|ClaudeBot|PerplexityBot|Google-Extended' | head -n 20 || echo "(none)"
fi

block WEB-18
note "ssr from stack: $(printf '%s' "$STACK_JSON" | grep -oE '"ssr": [a-z]+' | cut -d' ' -f2)"
note "prerender / SSG tooling:"
# shellcheck disable=SC2086
g 'vite-ssg|vite-plugin-prerender|prerender-spa-plugin|prerender\s*:|ssr\s*:|output\s*:' package.json $CONFIG_FILES 2>/dev/null
if [ -n "$URL" ]; then
  HTML="$(curl -s --max-time 20 -L -A "Mozilla/5.0 (compatible; ClaudeBot/1.0; +claudebot@anthropic.com)" "$URL/" 2>/dev/null)"
  TEXT="$(printf '%s' "$HTML" | html_text)"
  TEXT_LEN="$(printf '%s' "$TEXT" | wc -c | tr -d ' ')"
  WORDS="$(printf '%s' "$TEXT" | wc -w | tr -d ' ')"
  H1="$(printf '%s' "$HTML" | grep -oE '<h1[^>]*>[^<]{0,120}' | head -n 1)"
  note "live home page without JS: html_bytes=$(printf '%s' "$HTML" | wc -c | tr -d ' ') text_chars=$TEXT_LEN words=$WORDS h1=${H1:-'(none)'}"
  printf '%s' "$HTML" | grep -oE '<div id="(app|__nuxt|root)"[^>]*>' | head -n 1 | sed 's/^/app root: /'
fi

block WEB-19
if [ -n "$URL" ]; then
  CURL_FEAT="$(curl --version | grep -oE 'HTTP2|HTTP3' | tr '\n' ' ')"
  note "local curl supports: ${CURL_FEAT:-HTTP/1.1 only — the http= version below says nothing about the server; rely on alt-svc}"
  note "TTFB / protocol (home, 2 requests):"
  for i in 1 2; do curl -s -o /dev/null -w 'status=%{http_code} http=%{http_version} ttfb=%{time_starttransfer}s total=%{time_total}s\n' --max-time 20 -L -A "Mozilla/5.0 (compatible; bohemica-standards-audit)" "$URL/" 2>&1; done
  note "alt-svc / server:"; curl_head "$URL/" | grep -iE '^(alt-svc|server|via|cf-cache-status|x-cache|x-vercel-cache|x-nitro-prerender|age):' || echo "(none)"
else
  echo "(live only — no --url)"
fi

block WEB-20
lsx public/llms.txt static/llms.txt llms.txt public/llms-full.txt
if [ -n "$URL" ]; then note "live /llms.txt:"; curl_status "$URL/llms.txt"; fi

block WEB-21
note "accordion / FAQ / tab components rendering body conditionally (v-if) vs CSS-hidden (v-show, <details>):"
# shellcheck disable=SC2086
grep -rnIE $EXCL -e '<(details|Accordion|Faq|FAQ|Collapse|Disclosure|Tab)' $APP_DIRS 2>/dev/null | head -n 15 || true
# shellcheck disable=SC2086
grep -rnIE $EXCL -e 'v-if="(open|isOpen|expanded|active|show|visible)' $APP_DIRS 2>/dev/null | head -n 15 || true
echo "(end)"
if [ -n "$URL" ]; then
  [ -z "${LIVE_HTML:-}" ] && LIVE_HTML="$(curl -s --max-time 20 -L -A "Mozilla/5.0 (compatible; ClaudeBot/1.0; +claudebot@anthropic.com)" "$URL/" 2>/dev/null)"
  ONE="$(printf '%s' "$LIVE_HTML" | tr '\n' ' ')"
  note "live: first paragraph after <h1>:"
  printf '%s' "$ONE" | sed -E 's/.*<h1[^>]*>//' | grep -oE '<p[^>]*>[^<]{0,300}' | head -n 1 | sed -E 's/<p[^>]*>//' || echo "(no <p> after h1)"
  note "live: <main> present: $(printf '%s' "$ONE" | grep -c '<main' ) · <details>: $(printf '%s' "$ONE" | grep -o '<details' | wc -l | tr -d ' ') · aria-expanded elements: $(printf '%s' "$ONE" | grep -o 'aria-expanded' | wc -l | tr -d ' ') · hidden blocks (hidden attr/display:none): $(printf '%s' "$ONE" | grep -oE ' hidden[ >]|display:\s*none' | wc -l | tr -d ' ')"
  note "live: question sentences in visible text and the text that follows (FAQ answers present in raw HTML?):"
  printf '%s' "$LIVE_HTML" | html_text | perl -ne 'while (/([^.?!]{12,140}\?)\s*(.{0,110})/g) { print "  Q: $1\n     next: $2\n"; last if ++$n >= 8 }' 2>/dev/null || echo "(perl unavailable)"
  note "live: FAQPage Q/A pairs in JSON-LD: $(printf '%s' "$LIVE_HTML" | grep -o '"@type":"Answer"' | wc -l | tr -d ' ')"
fi

block WEB-22
# shellcheck disable=SC2086
g 'dateModified|datePublished|"author"|author\s*:|AggregateRating|aggregateRating|<time\b|Aktualizováno|Updated on|last-?updated' $APP_DIRS $CONFIG_FILES 2>/dev/null
if [ -n "$URL" ]; then
  [ -z "${LIVE_HTML:-}" ] && LIVE_HTML="$(curl -s --max-time 20 -L -A "Mozilla/5.0 (compatible; ClaudeBot/1.0; +claudebot@anthropic.com)" "$URL/" 2>/dev/null)"
  note "live: freshness/author/rating markers: $(printf '%s' "$LIVE_HTML" | grep -oE 'dateModified|datePublished|"author"|aggregateRating|<time\b|rel="author"' | sort | uniq -c | tr '\n' ';' )"
  note "live: identity / trust links:"; printf '%s' "$LIVE_HTML" | grep -oiE 'href="[^"]*(o-nas|about|kontakt|contact|impressum|obchodni-podminky|terms|reklamace|refund|recenze|reviews|ico|IČO)[^"]*"' | sort -u | head -n 10 || echo "(none)"
  note "live: IČO / address in text: $(printf '%s' "$LIVE_HTML" | grep -oE 'IČO?:?\s*[0-9]{8}|IČ:?\s*[0-9]{8}' | head -n 1)"
fi
