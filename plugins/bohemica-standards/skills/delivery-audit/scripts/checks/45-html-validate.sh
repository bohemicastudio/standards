#!/usr/bin/env bash
# checks/45-html-validate.sh — html-validate run on rendered HTML for WEB-24. Runs in --quick too.
# Sourced by collect-evidence.sh; helpers and paths come from lib/common.sh.
#
# What is validated (first source that exists): live pages (--url: home + up to 4 sitemap URLs)
# → build output with a root index.html (.output/public, dist, build) → static HTML in the repo (index.html, public/).
# Templates (.vue/.astro/Blade) are never validated directly.
# Resolution order for the CLI: `html-validate` on PATH → project-local node_modules/.bin
# → one-off download via `npx -y html-validate@10` (Node ≥ 20) or `@9` (older Node).
# Config is scripts/html-validate.json (standard + a11y presets); project configs are ignored.
# Pages, a copy of the config and the JSON report go to $TMPDIR, never into the audited project.
# html-validate runs from that temp dir because it mis-resolves an absolute --config path on Windows.

block WEB-24
HV_FILES=()      # absolute paths to validate
HV_LABELS=""     # one label per file, same order
HV_SOURCE=""
HV_SKIP='/(google[0-9a-f]+|yandex_[0-9a-f]+)\.html$'   # search-console verification stubs

if [ -n "$URL" ]; then
  HV_HOST="$(printf '%s' "$URL" | sed -E 's#https?://##; s#[^A-Za-z0-9.-].*##')"
  HV_DIR="${TMPDIR:-${TEMP:-/tmp}}/bohemica-html-validate-$HV_HOST"
  rm -rf "$HV_DIR"; mkdir -p "$HV_DIR"
  hv_locs() { curl -s --max-time 15 -L -A "bohemica-standards-audit" "$1" 2>/dev/null | grep -oE '<loc>[^<]+</loc>' | sed -E 's#</?loc>##g; s#&amp;#\&#g'; }
  HV_SM="$(curl -s --max-time 15 -A "bohemica-standards-audit" "$URL/robots.txt" 2>/dev/null | tr -d '\r' | grep -iE '^sitemap:' | head -n 1 | sed -E 's#^[Ss]itemap:[[:space:]]*##')"
  HV_SM="${HV_SM:-$URL/sitemap.xml}"
  HV_LOCS="$(hv_locs "$HV_SM")"
  # sitemap index: follow the first child sitemap
  HV_FIRST="$(printf '%s\n' "$HV_LOCS" | head -n 1)"
  case "$HV_FIRST" in *.xml|*.xml\?*) HV_LOCS="$(hv_locs "$HV_FIRST")" ;; esac
  HV_BARE="${HV_HOST#www.}"
  HV_URLS="$(printf '%s\n' "$URL/"; printf '%s\n' "$HV_LOCS" | grep -E "^https?://(www\.)?${HV_BARE//./\\.}(/|$)" | grep -vxF -e "$URL" -e "$URL/" | head -n 4)"
  hv_i=0
  while IFS= read -r hv_u; do
    [ -n "$hv_u" ] || continue
    hv_i=$((hv_i + 1)); hv_f="$HV_DIR/page-$hv_i.html"
    hv_res="$(curl -s -L --max-time 20 -A "Mozilla/5.0 (compatible; bohemica-standards-audit)" -o "$hv_f" -w '%{http_code} %{content_type}' "$hv_u" 2>/dev/null)"
    case "$hv_res" in
      200\ *html*) HV_FILES+=("$hv_f"); HV_LABELS="$HV_LABELS/${hv_u#*://*/}"$'\n' ;;
      *) note "skipped $hv_u: ${hv_res:-no response}" ;;
    esac
  done <<< "$HV_URLS"
  HV_SOURCE="live ($HV_HOST; sitemap $HV_SM with $(printf '%s\n' "$HV_LOCS" | grep -c .) URLs)"
else
  HV_DIR="${TMPDIR:-${TEMP:-/tmp}}/bohemica-html-validate-local-$(basename "$PWD")"
  rm -rf "$HV_DIR"; mkdir -p "$HV_DIR"
  hv_pick() { # dirs… → up to 10 html files, shallowest first
    find "$@" -name '*.html' -not -path '*/node_modules/*' 2>/dev/null | grep -vE "$HV_SKIP" \
      | awk -F/ '{ print NF "\t" $0 }' | sort -s -n -k1,1 | cut -f2- | head -n 10
  }
  HV_LIST=""
  for hv_d in .output/public dist build; do
    [ -f "$hv_d/index.html" ] || continue   # a site build has a root index.html; `build/` may hold anything else

    HV_LIST="$(hv_pick "$hv_d")"
    [ -n "$HV_LIST" ] || continue
    HV_BUILT="$(perl -MPOSIX -e 'print strftime("%Y-%m-%d %H:%M", localtime((stat shift)[9]))' "$(printf '%s\n' "$HV_LIST" | head -n 1)" 2>/dev/null)"
    HV_COMMIT="$(in_git && git log -1 --format='%cd' --date=format:'%Y-%m-%d %H:%M' 2>/dev/null)"
    HV_SOURCE="build ($hv_d, built ${HV_BUILT:-?}, last commit ${HV_COMMIT:-n/a})"
    break
  done
  if [ -z "$HV_SOURCE" ]; then
    HV_LIST="$( { [ -f index.html ] && echo index.html; [ -d public ] && hv_pick public; } )"
    [ -n "$HV_LIST" ] && HV_SOURCE="static (source HTML in the repo, not rendered output)"
  fi
  while IFS= read -r hv_f; do
    [ -n "$hv_f" ] || continue
    HV_FILES+=("$PWD/$hv_f"); HV_LABELS="$HV_LABELS$hv_f"$'\n'
  done <<< "$HV_LIST"
fi

if [ ${#HV_FILES[@]} -eq 0 ]; then
  if [ -n "$URL" ]; then echo "(nothing to validate: no HTML page could be fetched from $URL)"
  else echo "(nothing to validate: no --url, no build output, no static HTML)"; fi
elif ! command -v node >/dev/null 2>&1; then
  echo "(html-validate unavailable: node not found)"
else
  HV_CMD=""
  if command -v html-validate >/dev/null 2>&1; then
    HV_CMD="html-validate"
  elif [ -x node_modules/.bin/html-validate ]; then
    HV_CMD="$PWD/node_modules/.bin/html-validate"
  elif command -v npx >/dev/null 2>&1; then
    if [ "$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)" -ge 20 ]; then HV_CMD="npx -y html-validate@10"; else HV_CMD="npx -y html-validate@9"; fi
  fi
  if [ -z "$HV_CMD" ]; then
    echo "(html-validate unavailable: no html-validate binary and no npx)"
  else
    note "source: $HV_SOURCE"
    note "command: $HV_CMD (config: scripts/html-validate.json — standard + a11y presets)"
    cp "$HERE/html-validate.json" "$HV_DIR/html-validate.json"
    printf '%s' "$HV_LABELS" > "$HV_DIR/labels.txt"
    # shellcheck disable=SC2086
    ( cd "$HV_DIR" && $HV_CMD --config html-validate.json --formatter json "${HV_FILES[@]}" > report.json 2> report.err )
    node - "$HV_DIR" "${HV_FILES[@]}" <<'NODE'
const fs = require('fs'), path = require('path');
const [dir, ...files] = process.argv.slice(2);
const read = f => { try { return fs.readFileSync(f, 'utf8'); } catch (e) { return ''; } };
const raw = read(path.join(dir, 'report.json')).trim();
let report;
try { report = JSON.parse(raw); } catch (e) {
  const err = (raw + '\n' + read(path.join(dir, 'report.err'))).trim().split('\n').slice(0, 4).join(' / ');
  console.log(`(html-validate run failed: ${err || 'no output'})`); process.exit(0);
}
const labels = read(path.join(dir, 'labels.txt')).split('\n');
const norm = p => path.resolve(p).toLowerCase();
const byFile = new Map(report.map(r => [norm(r.filePath), r]));
const cut = (s, n) => { s = String(s).replace(/\s+/g, ' ').trim(); return s.length > n ? s.slice(0, n - 1) + '…' : s; };
let errors = 0, warnings = 0; const rules = new Map();
console.log('per page (basics · html-validate):');
files.forEach((file, i) => {
  const label = labels[i] || file, html = read(file);
  const m = re => (html.match(re) || [])[1];
  const doctype = /^\s*(?:﻿)?(?:<!--[\s\S]*?-->\s*)*<!doctype html\b/i.test(html) ? 'yes' : 'NO';
  const lang = m(/<html\b[^>]*?\slang\s*=\s*["']?([^"'\s>]*)/i);
  const charset = m(/<meta\b[^>]*?\bcharset\s*=\s*["']?([\w-]+)/i);
  const viewport = /<meta\b[^>]*?\bname\s*=\s*["']?viewport\b/i.test(html) ? 'yes' : 'NO';
  const title = m(/<title\b[^>]*>([^<]*)<\/title>/i);
  const r = byFile.get(norm(file)) || { messages: [], errorCount: 0, warningCount: 0 };
  errors += r.errorCount; warnings += r.warningCount;
  for (const msg of r.messages) {
    const k = msg.ruleId || '(parser)';
    if (!rules.has(k)) rules.set(k, { count: 0, pages: new Set(), examples: [], warn: msg.severity === 1 });
    const e = rules.get(k); e.count++; e.pages.add(label);
    if (e.examples.length < 2 && !e.examples.some(x => x.startsWith(label + ':'))) e.examples.push(`${label}:${msg.line}:${msg.column} ${cut(msg.message, 90)}`);
  }
  console.log(`  ${label} — doctype=${doctype} lang=${lang === undefined ? 'MISSING' : (lang || 'EMPTY')} charset=${charset || 'MISSING'} viewport=${viewport} title=${title === undefined ? 'MISSING' : JSON.stringify(cut(title, 50))} · ${r.errorCount} errors, ${r.warningCount} warnings`);
});
console.log(`total: ${files.length} pages, ${errors} errors, ${warnings} warnings`);
const top = [...rules.entries()].sort((a, b) => b[1].count - a[1].count);
console.log('by rule (count, pages, examples):');
if (!top.length) console.log('  (none)');
for (const [id, e] of top.slice(0, 15)) console.log(`  ${id}${e.warn ? ' [warn]' : ''} ×${e.count} on ${e.pages.size}/${files.length} — ${e.examples.join(' | ')}`);
if (top.length > 15) console.log(`  … ${top.length - 15} more rules: ${top.slice(15).map(([id, e]) => `${id} ×${e.count}`).join(', ')}`);
NODE
  fi
fi
