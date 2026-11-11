#!/usr/bin/env bash
# lib/common.sh — shared helpers and project paths for checks/*.sh.
# Sourced by collect-evidence.sh after it has parsed arguments and cd'ed into the target.
# Expects: HERE (scripts dir), TARGET, URL, QUICK. Provides: STACK_JSON, FRAMEWORK, PM, NUXT_CONFIG,
#          *_DIRS / *_FILES path lists, block/note/g/gl/show/lsx/html_text/curl_head/curl_status/curl_probe/in_git,
#          template_files/form_scan, nginx_servers.

LIMIT=40                       # max lines per block
EXCL="--exclude-dir=node_modules --exclude-dir=.nuxt --exclude-dir=.output --exclude-dir=dist --exclude-dir=build --exclude-dir=vendor --exclude-dir=.git --exclude-dir=storage --exclude-dir=.astro --exclude-dir=coverage"
FIND_EXCL="-not -path */node_modules/* -not -path */vendor/* -not -path ./.git/* -not -path */.nuxt/* -not -path */.output/* -not -path */dist/*"

# ---------- stack ----------
STACK_JSON="$(bash "$HERE/detect-stack.sh" .)"
FRAMEWORK="$(printf '%s' "$STACK_JSON" | grep -oE '"framework": "[^"]+"' | cut -d'"' -f4)"
PM="$(printf '%s' "$STACK_JSON" | grep -oE '"package_manager": "[^"]+"' | cut -d'"' -f4)"
NUXT_CONFIG="$(printf '%s' "$STACK_JSON" | grep -oE '"config":"[^"]+"' | cut -d'"' -f4)"

# ---------- helpers ----------
existing() { local d; for d in "$@"; do [ -e "$d" ] && printf '%s ' "$d"; done; }
# directories by role (only those that exist are used)
APP_DIRS="$(existing app src pages components layouts composables plugins middleware app.vue error.vue resources/views resources/js public/index.html index.html)"
SERVER_DIRS="$(existing server src/server src/pages/api src/actions src/api app/Livewire app/Http app/Models routes src/routes src/plugins src/middlewares config)"
CONFIG_FILES="$(existing nuxt.config.ts nuxt.config.js nuxt.config.mjs astro.config.mjs astro.config.ts astro.config.js vite.config.ts vite.config.js vite.config.mjs config/app.php config/session.php config/cors.php config/middlewares.js config/middlewares.ts config/server.js config/server.ts)"
CI_FILES="$(existing .github/workflows .gitlab-ci.yml bitbucket-pipelines.yml Dockerfile docker/Dockerfile docker-compose.yml docker-compose.yaml compose.yml compose.yaml .dockerignore ecosystem.config.js ecosystem.config.cjs Procfile)"
NGINX_FILES="$(find . -maxdepth 4 \( -name node_modules -o -name vendor -o -name .git \) -prune -o -type f \( -name 'nginx.conf' -o -name '*.nginx' -o -name 'nginx*.conf' -o -name 'default.conf' -o -name '*.conf.template' -o -path '*/nginx/*.conf' -o -path '*/sites-available/*' -o -path '*/sites-enabled/*' -o -name 'Caddyfile' -o -name 'traefik*.yml' \) -print 2>/dev/null | sort | tr '\n' ' ')"

block() { printf '\n=== %s ===\n' "$1"; }
note()  { printf -- '-- %s\n' "$*"; }
# g PATTERN PATHS... : grep recursively, capped, "(none)" when empty
g() {
  local pat="$1"; shift
  local out
  [ $# -eq 0 ] && { echo "(no matching directories in this project)"; return; }
  # shellcheck disable=SC2086
  out="$(grep -rnIE $EXCL -e "$pat" "$@" 2>/dev/null | head -n $LIMIT)"
  if [ -n "$out" ]; then printf '%s\n' "$out"; else echo "(none)"; fi
}
# gl PATTERN PATHS... : files that do NOT match (for "pages without meta")
gl() {
  local pat="$1"; shift
  [ $# -eq 0 ] && { echo "(no matching directories)"; return; }
  # shellcheck disable=SC2086
  grep -rLIE $EXCL -e "$pat" "$@" 2>/dev/null | head -n $LIMIT
}
show() { # print a file, capped
  if [ -f "$1" ]; then note "$1:"; head -n "${2:-$LIMIT}" "$1"; else echo "(missing: $1)"; fi
}
curl_head() { curl -sSI -L --max-time 15 -A "bohemica-standards-audit" "$1" 2>&1 | tr -d '\r' | head -n 40; }
curl_status() { curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' --max-time 15 -A "bohemica-standards-audit" "$1" 2>&1; }
# curl_probe URL [curl args...] : one line with status, content type and what the body looks like — never the body itself
curl_probe() {
  local url="$1"; shift
  curl -s -k --connect-timeout 5 --max-time 10 -A "bohemica-standards-audit" "$@" -w '\n@@%{http_code}\t%{content_type}\t%{redirect_url}' "$url" 2>/dev/null \
    | PROBE_URL="$url" perl -e '
        my $in = do { local $/; <STDIN> } // "";
        my ($body, $code, $type, $redir) = $in =~ /^(.*)\n@@(\d{3})\t([^\t\n]*)\t([^\n]*)\z/s;
        if (!defined $code) { print "  $ENV{PROBE_URL} → no result (curl failed)\n"; exit }
        my $looks;
        if ($code eq "000") { $looks = "no response (connection closed, refused, timed out or TLS handshake rejected)" }
        elsif ($code =~ /^3/) { $looks = "redirect to " . ($redir || "?") }
        else {
          my $html = $body =~ /<(?:!doctype|html|head|body|title)\b/i;
          my $env  = () = $body =~ /^[ \t]*(?:export[ \t]+)?[A-Za-z_][A-Za-z0-9_]*[ \t]*=/mg;
          $looks = $body =~ /\A\s*(?:ref: refs\/|\[core\])/ ? "GIT METADATA"
                 : $body =~ /<(?:title|h1)>Index of / ? "DIRECTORY LISTING"
                 : $body =~ /Welcome to nginx|Apache2 \w+ Default Page|<h1>It works!/ ? "web server default page"
                 : (!$html && $env) ? "DOTENV ($env KEY= lines)"
                 : (!$html && $body =~ /\A\s*\{/ && $body =~ /"(?:name|require|dependencies|scripts)"\s*:/) ? "JSON MANIFEST"
                 : $html ? "html" : length($body) ? "other" : "empty";
          $looks .= ", " . length($body) . " bytes";
        }
        printf "  %s → %s %s — %s\n", $ENV{PROBE_URL}, $code, $type || "(no content-type)", $looks;'
}
in_git() { command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; }
lsx() { local f found=0; for f in "$@"; do [ -e "$f" ] && { echo "$f"; found=1; }; done; [ $found = 1 ] || echo "(none)"; }
# html_text: stdin HTML -> visible text on one line (drops script/style/noscript/svg, tags, collapses whitespace)
html_text() { perl -0777 -pe 's/<(script|style|noscript|svg|template)\b.*?<\/\1>//gsi; s/<!--.*?-->//gs; s/<[^>]+>/ /g; s/&nbsp;/ /g; s/\s+/ /g' 2>/dev/null; }

# ---------- web server (DEP-18) ----------
# nginx_servers FILES... : one line per nginx `server {}` block in file order (listen, server_name, root, upstream,
#   top-level action, dotfile deny, what it does), then the default server per port and the file-serving blocks
#   that have no full dotfile deny. Files without a server block (Caddyfile, traefik, snippets) are skipped.
nginx_servers() {
  [ $# -eq 0 ] && { echo "(no proxy config in repo)"; return; }
  perl - "$LIMIT" "$@" <<'PERL'
my ($limit, @files) = @ARGV;
my (@rows, @open, %explicit, %first, %seen);
my $ws = sub { my $s = shift; $s =~ s/\s+/ /g; $s =~ s/^ | $//g; $s };
for my $f (@files) {
  open(my $fh, '<', $f) or next; local $/; my $src = <$fh>; close $fh;
  $src =~ s/(^|[ \t])#[^\n]*/$1/mg;                      # comments (line count kept)
  $src =~ s/\$\{(\w+)[^{}]*\}/\$$1/g;                    # envsubst placeholders in *.conf.template
  while ($src =~ /(?<![\w.\$-])server\s*\{/g) {
    my ($at, $from, $i, $depth) = ($-[0], pos($src), pos($src), 1);
    while ($depth > 0 && $i < length $src) { my $c = substr($src, $i++, 1); $depth++ if $c eq '{'; $depth-- if $c eq '}'; }
    my $b = substr($src, $from, $i - $from); pos($src) = $i;
    my $where = "$f:" . (1 + (substr($src, 0, $at) =~ tr/\n//)); $where =~ s#^\./##; $seen{$f}++;
    (my $top = $b) =~ s/\}\s*\z//;
    1 while $top =~ s/\{[^{}]*\}/;/g;                     # nested blocks out → server-level directives only
    my @listen = map { $ws->($_) } $top =~ /(?:^|[;\s])listen\s+([^;]+);/g;
    @listen = ('80 (implied)') unless @listen;
    my ($name) = map { $ws->($_) } $top =~ /(?:^|[;\s])server_name\s+([^;]+);/;
    my (%root, %up, %inc);
    $root{$_}++ for $b =~ /(?:^|[;{\s])(?:root|alias)\s+([^;\s]+)\s*;/g;
    $up{$_}++   for $b =~ /(?:^|[;{\s])(proxy_pass|fastcgi_pass|uwsgi_pass|grpc_pass)\s/g;
    $inc{$_}++  for grep { !/fastcgi|uwsgi_params|scgi_params|proxy_params|mime\.types/ } $b =~ /(?:^|[;{\s])include\s+([^;\s]+)\s*;/g;
    my ($ret) = map { $ws->($_) } $top =~ /(?:^|[;\s])return\s+([^;]+);/;
    ($ret) = map { $ws->($_) . ' (in location /)' } $b =~ /\blocation\s+\/\s*\{\s*return\s+([^;]+);\s*\}/ unless defined $ret;
    my @act = defined $ret ? ("return $ret") : ();
    push @act, 'ssl_reject_handshake on' if $top =~ /ssl_reject_handshake\s+on\s*;/;
    push @act, 'deny all' if $top =~ /(?:^|[;\s])deny\s+all\s*;/;
    my @dot;
    while ($b =~ /\blocation\s+(?:(~\*?|=|\^~)\s+)?("[^"]*"|\S+)\s*\{([^{}]*)\}/g) {
      my ($mod, $pat, $body) = ($1 // '', $2, $3);
      next unless $pat =~ m{[/)]\\\.} || $pat =~ m{\\\.\(?(?:env|git|ht|svn)} || ($mod !~ /~/ && $pat =~ m{^/\.(?!well-known)});
      next unless $body =~ /\bdeny\s+all\b|\breturn\s+4\d\d\b/;
      # full = any path segment starting with a dot; a name list (/\.ht, \.(env|git)) is partial
      push @dot, ($mod ? "$mod " : '') . $pat . ($pat =~ m{[/)]\\\.(?:\(\?!|\.\*|\[\^|\+|\$|"|\z)} ? '' : ' (partial)');
    }
    my $does = "@act" =~ /ssl_reject_handshake|deny all|return (?:4|5)\d\d\b/ ? 'closed'
             : "@act" =~ /return 30\d\b/ ? 'redirect-only'
             : (%root || %up) ? 'serves content' : 'serves the built-in default root';
    $does .= ', AUTOINDEX ON' if $b =~ /autoindex\s+on\s*;/;
    my $default = grep { /\bdefault(?:_server)?\b/ } @listen;
    push @rows, sprintf('%s%s | listen=%s | server_name=%s | root=%s | upstream=%s | action=%s | dotfile-deny=%s%s → %s',
      $where, ($default ? ' [DEFAULT]' : ''), join(', ', @listen), $name // '(none)', join(', ', sort keys %root) || '(none)',
      join('+', sort keys %up) || '(none)', join('; ', @act) || '(none)', join('  ', @dot) || '(none)',
      (!@dot && %inc ? ' | include=' . join(', ', sort keys %inc) : ''), $does);
    push @open, $where if %root && $does =~ /^serves/ && !grep { !/ \(partial\)$/ } @dot;
    for my $l (@listen) {
      my ($t) = split ' ', $l; next if $t =~ /^unix:/;
      (my $p = $t) =~ s/^.*://; $p = 80 unless $p =~ /^(?:\d+|\$\w+)$/;
      $first{$p} //= [$where, $does];
      $explicit{$p} //= [$where, $does] if $l =~ /\bdefault(?:_server)?\b/;
    }
  }
}
if (!@rows) { print "(no nginx server block in the repo config)\n"; exit }
print map { "$_\n" } @rows[0 .. ($#rows < $limit - 1 ? $#rows : $limit - 1)];
print "… ", scalar(@rows) - $limit, " more server blocks\n" if @rows > $limit;
print "default server per port:\n";
for my $p (sort { ($a =~ /^\d+$/ ? $a : 99999) <=> ($b =~ /^\d+$/ ? $b : 99999) or $a cmp $b } keys %first) {
  if ($explicit{$p}) { print "  $p → explicit default_server $explicit{$p}[0] — $explicit{$p}[1]\n" }
  else { print "  $p → IMPLICIT, no default_server: nginx uses the first block for the port, $first{$p}[0] — $first{$p}[1]\n" }
}
print "  (server blocks span ", scalar(keys %seen), " files: which block comes first depends on the include order on the server)\n"
  if keys %seen > 1 && grep { !$explicit{$_} } keys %first;
print "blocks serving files (root/alias) without a full dotfile deny: ", (@open ? join(', ', @open) : '(none)'), "\n";
PERL
}

# ---------- forms (SEC-19, WEB-25) ----------
# template_files: Vue/Astro/Blade/JSX/TSX/Svelte/HTML files under APP_DIRS
template_files() {
  [ -n "$APP_DIRS" ] || return 0
  # shellcheck disable=SC2086
  find $APP_DIRS -type f \( -name '*.vue' -o -name '*.astro' -o -name '*.blade.php' -o -name '*.html' -o -name '*.jsx' -o -name '*.tsx' -o -name '*.svelte' \) \
    -not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/.nuxt/*' -not -path '*/.output/*' -not -path '*/dist/*' 2>/dev/null | sed 's#^\./##' | sort -u
}
# form_scan fields|forms FILES... : parse form-field tags (native and common UI-library components)
#   fields → totals (length limit, v-model.trim) and the text-like fields without a length limit (textareas first)
#   forms  → one line per template with fields: validation, trim and error-wiring counts
form_scan() {
  local mode="$1"; shift
  [ $# -eq 0 ] && { echo "(no template files)"; return; }
  perl - "$mode" "$LIMIT" "$@" <<'PERL'
my ($mode, $limit, @files) = @ARGV;
my $field = qr/input|textarea|(?:[A-Z][A-Za-z]*)?(?:Input|Textarea|TextArea|TextField)|[a-z]+-(?:input|textarea|text-area|text-field)|FormKit/;
my $nontext = qr/^(?:hidden|checkbox|radio|submit|button|reset|file|image|range|color|date|datetime-local|month|week|time|number|select|form|group|list|toggle|switch)$/i;
my $skip = qr/^(?:hidden|submit|button|reset|image|form|group|list)$/i;
my ($total, $limited, $trimmed, $nfiles, @open, @forms, @bare) = (0, 0, 0, 0);
for my $f (@files) {
  open(my $fh, '<', $f) or next; local $/; my $src = <$fh>; close $fh;
  $src =~ s/(<!--.*?-->|<style\b.*?<\/style>)/"\n" x ($1 =~ tr|\n||)/gse;
  my %c = map { $_ => 0 } qw(fields text limited trim required typed autocomplete);
  while ($src =~ /<($field)\b((?:[^>"']|"[^"]*"|'[^']*')*)>/g) {
    my ($tag, $attr, $at) = ($1, $2, $-[0]);
    my ($type) = $attr =~ /(?:^|\s)type\s*=\s*["']?([\w-]+)/;
    $type //= $tag =~ /textarea|text-?area/i ? 'textarea' : 'text';
    next if $type =~ $skip;
    $c{fields}++;
    $c{required}++     if $attr =~ /(?:^|[\s:])(?:required|aria-required)\b|validation\s*=\s*["'][^"']*\brequired/;
    $c{typed}++        if $type =~ /^(?:email|tel|url|number|date)$/i;
    $c{autocomplete}++ if $attr =~ /(?:^|[\s:])autocomplete\s*=/i;
    next if $type =~ $nontext;
    $c{text}++;
    $c{trim}++ if $attr =~ /(?:v|x)-model(?::[\w-]+)?\.(?:\w+\.)*trim\b/;
    if ($attr =~ /(?:^|[\s:])(?:maxlength|maxLength|max-length|counter)\b|validation\s*=\s*["'][^"']*\blength\b/) { $c{limited}++; next; }
    my $line = 1 + (substr($src, 0, $at) =~ tr/\n//);
    my ($name) = $attr =~ /(?:^|\s)(?:name|v-model(?::\w+)?|wire:model(?:\.\w+)*|x-model|id)\s*=\s*["']([^"']+)/;
    push @open, [($type eq 'textarea' ? 0 : 1), "$f:$line <$tag" . ($type =~ /^(?:text|textarea)$/ ? '' : " type=$type") . '>' . (defined $name ? " $name" : '')];
  }
  my $form = ($src =~ /<(?:form|UForm|VForm|v-form|el-form|q-form|Form)\b/ || $src =~ /<FormKit\b[^>]*type=["']form/) ? 'yes' : 'no';
  next unless $c{fields} || $form eq 'yes';
  if (!$c{fields}) { push @bare, $f; next; }
  $nfiles++ if $c{text}; $total += $c{text}; $limited += $c{limited}; $trimmed += $c{trim};
  my $n = sub { my $re = shift; my @m = $src =~ /$re/g; scalar @m };
  my $schema = $src =~ /:schema\s*=|validation-schema|validationSchema|useForm\(|useVuelidate|:rules\s*=|\srules\s*=|validation\s*=|[zv]\.object\(|yup\.object|useFormKit/ ? 'yes' : 'no';
  push @forms, [($form eq 'yes' ? 0 : 1), sprintf('%s — %s fields=%d (text %d, limited %d, trim %d) req=%d typed=%d ac=%d nv=%s schema=%s aria=%d desc=%d live=%d err=%d',
    $f, ($form eq 'yes' ? 'form' : 'no-form'), $c{fields}, $c{text}, $c{limited}, $c{trim}, $c{required}, $c{typed}, $c{autocomplete},
    ($src =~ /\bnovalidate\b/i ? 'yes' : 'no'), $schema, $n->(qr/aria-invalid/), $n->(qr/aria-(?:describedby|errormessage)/),
    $n->(qr/role\s*=\s*["']alert|aria-live/), $n->(qr/error/i))];
}
if ($mode eq 'fields') {
  print "text-like fields: $total in $nfiles files; with a length limit (maxlength/counter/FormKit length): $limited; with v-model.trim: $trimmed\n";
  print "fields without a length limit (textareas first):\n";
  my @l = map { $_->[1] } sort { $a->[0] <=> $b->[0] } @open;
  print @l ? join('', map { "  $_\n" } @l[0 .. ($#l < $limit - 1 ? $#l : $limit - 1)]) : "  (none)\n";
  print "  … ", scalar(@l) - $limit, " more\n" if @l > $limit;
} else {
  my @l = map { $_->[1] } sort { $a->[0] <=> $b->[0] } @forms;
  print "legend: limited=maxlength/counter trim=v-model.trim req=required typed=email|tel|url|number|date ac=autocomplete nv=novalidate aria=aria-invalid desc=aria-describedby|errormessage live=role=alert|aria-live err=\"error\" mentions\n" if @l;
  print @l ? join('', map { "$_\n" } @l[0 .. ($#l < $limit - 1 ? $#l : $limit - 1)]) : "(no forms or form fields in templates)\n";
  print "… ", scalar(@l) - $limit, " more files\n" if @l > $limit;
  printf "<form> without recognised fields (fields in custom components): %d — %s%s\n", scalar @bare, join(', ', @bare[0 .. ($#bare < 9 ? $#bare : 9)]), (@bare > 10 ? ', …' : '') if @bare;
}
PERL
}
