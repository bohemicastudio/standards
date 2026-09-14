#!/usr/bin/env bash
# checks/50-lighthouse.sh — Lighthouse (mobile) run for WEB-23. Live only, skipped in --quick.
# Sourced by collect-evidence.sh; helpers and paths come from lib/common.sh.
#
# Resolution order for the CLI: `lighthouse` on PATH → project-local via `npx --no-install`
# → one-off download via `npx -y lighthouse@12` (needs network, ~40 MB the first time).
# Chrome/Chromium must be installed; CHROME_PATH is honoured, common Windows/macOS paths are probed.
# Full JSON report is written to $TMPDIR (never into the audited project); its path is printed.

block WEB-23
if [ -z "$URL" ]; then
  echo "(live only — no --url)"
elif [ "$QUICK" = 1 ]; then
  echo "(skipped: quick mode)"
else
  LH_CMD=""
  if command -v lighthouse >/dev/null 2>&1; then
    LH_CMD="lighthouse"
  elif npx --no-install lighthouse --version >/dev/null 2>&1; then
    LH_CMD="npx --no-install lighthouse"
  elif command -v npx >/dev/null 2>&1; then
    LH_CMD="npx -y lighthouse@12"
    note "lighthouse not installed — using one-off download via npx (slower the first time)"
  fi

  if [ -z "${CHROME_PATH:-}" ]; then
    for p in "/c/Program Files/Google/Chrome/Application/chrome.exe" \
             "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
             "${LOCALAPPDATA:-}/Google/Chrome/Application/chrome.exe" \
             "/c/Program Files/Microsoft/Edge/Application/msedge.exe" \
             "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
             "/usr/bin/google-chrome" "/usr/bin/chromium" "/usr/bin/chromium-browser"; do
      [ -f "$p" ] && { CHROME_PATH="$p"; export CHROME_PATH; break; }
    done
  fi

  if [ -z "$LH_CMD" ]; then
    echo "(lighthouse unavailable: no lighthouse binary and no npx)"
  elif [ -z "${CHROME_PATH:-}" ] && ! command -v google-chrome >/dev/null 2>&1 && ! command -v chromium >/dev/null 2>&1; then
    echo "(lighthouse unavailable: Chrome/Chromium not found — set CHROME_PATH)"
  else
    LH_HOST="$(printf '%s' "$URL" | sed -E 's#https?://##; s#[^A-Za-z0-9.-].*##')"
    LH_OUT="${TMPDIR:-${TEMP:-/tmp}}/bohemica-lighthouse-${LH_HOST}.json"
    note "command: $LH_CMD (mobile, default throttling) → $LH_OUT"
    # shellcheck disable=SC2086
    $LH_CMD "$URL/" --quiet --output=json --output-path="$LH_OUT" \
      --only-categories=performance,accessibility,best-practices,seo \
      --chrome-flags="--headless=new --no-sandbox --disable-gpu" >/dev/null 2>"${LH_OUT}.err" || true
    if [ -s "$LH_OUT" ] && command -v node >/dev/null 2>&1; then
      node - "$LH_OUT" <<'NODE'
const fs = require('fs');
const r = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const a = r.audits || {}, c = r.categories || {};
const pct = k => c[k] && c[k].score != null ? Math.round(c[k].score * 100) : 'n/a';
const dv = k => a[k] && a[k].displayValue ? a[k].displayValue.replace(/\s+/g, ' ') : 'n/a';
console.log(`scores: performance=${pct('performance')} accessibility=${pct('accessibility')} best-practices=${pct('best-practices')} seo=${pct('seo')}`);
console.log(`lab metrics: LCP=${dv('largest-contentful-paint')} CLS=${dv('cumulative-layout-shift')} TBT=${dv('total-blocking-time')} FCP=${dv('first-contentful-paint')} SI=${dv('speed-index')}`);
console.log(`final url: ${r.finalDisplayedUrl || r.finalUrl || ''} · lighthouse ${r.lighthouseVersion} · form factor ${r.configSettings && r.configSettings.formFactor}`);
const failing = cat => (c[cat] ? c[cat].auditRefs : [])
  .map(ref => a[ref.id]).filter(x => x && x.score != null && x.score < 0.9 && x.scoreDisplayMode !== 'informative')
  .sort((x, y) => (x.score - y.score));
const line = x => `  - ${x.id}: ${(x.title || '').replace(/\s+/g, ' ')}${x.displayValue ? ' — ' + x.displayValue : ''}`;
const opp = failing('performance').filter(x => x.details && (x.details.type === 'opportunity' || x.details.overallSavingsMs)).slice(0, 6);
console.log('top performance opportunities:'); console.log(opp.length ? opp.map(line).join('\n') : '  (none)');
for (const cat of ['accessibility', 'best-practices', 'seo']) {
  const f = failing(cat).slice(0, 6);
  console.log(`failing ${cat} audits:`); console.log(f.length ? f.map(line).join('\n') : '  (none)');
}
NODE
    else
      echo "(lighthouse run failed)"; tail -n 5 "${LH_OUT}.err" 2>/dev/null
    fi
  fi
fi
