# Bohemica Standards

Delivery audit for web projects. One skill, `delivery-audit`, checks a project you are about to hand over or put live against 62 checklist items and writes the result to `AUDIT.md` in that project: what blocks the handover, what should be fixed, what passed, and what could not be verified.

Framework locators exist for Nuxt, Vue/Vite SPA, Astro, Laravel and Strapi. Other stacks get the same checks without a locator.

## What it checks

| Checklist | Items | Covers |
|---|---|---|
| Security | SEC-01 … SEC-19 | secrets in git, vulnerable dependencies, input validation, authentication on handlers, cookies, rate limiting, uploads, CORS, debug output, form input limits |
| Deploy & HTTP headers | DEP-01 … DEP-18 | README and lockfile, runtime version, Docker basics, HTTPS redirect, HSTS, CSP, caching, compression, CI, error tracking, dependency updates, default server block and dotfile exposure |
| Web standards | WEB-01 … WEB-25 | robots, sitemap, canonical URLs, titles and Open Graph, error pages, images, fonts, cookie consent, accessibility basics, AI-crawler access, HTML validity, Lighthouse scores, forms |

Every finding cites a file and line, or a line of command output. An item that cannot be checked is reported as not verified with the reason; it is never guessed.

## Install

In Claude Code 2.1.275 or later:

```
/plugin install bohemica-standards --marketplace bohemicastudio/standards
```

On older versions, add the marketplace first with `/plugin marketplace add bohemicastudio/standards`, then run `/plugin install bohemica-standards@bohemica`.

## Use it

Run the skill from the project folder in Claude Code:

```
/bohemica-standards:delivery-audit
/bohemica-standards:delivery-audit ./apps/web --public --url https://www.example.com
/bohemica-standards:delivery-audit --internal --quick
```

Or ask in plain words:

- "Audit this project before handover."
- "Run the delivery audit on ./apps/web. It is a public site, live at https://www.example.com."
- "Quick standards check of this internal tool, blockers only."

Arguments:

- No arguments: a short dialog asks for the target folder, who will see the project, the live URL and full or quick mode.
- `path`: the project folder. The default is the current directory; in a monorepo, point it at the app.
- `--public`, `--internal` or `--api`: who will see the project. This decides which items apply.
- `--url`: the live site. It turns on the checks that need real responses (see below).
- `--quick`: blockers and script-decided items only, a couple of minutes instead of about ten.

The result is `AUDIT.md` in the audited project: the detected stack, a summary table, findings by severity (each with location, evidence and fix), then the passed, not applicable and not verified items.

## Where it runs

Claude Code (terminal, IDE extensions, the Code tab of the desktop app), with the project on disk. That is where it was built and tested.

It needs bash, grep, find and perl, which Git Bash provides on Windows, and git. Node, curl and Chrome or Edge are optional; without them the items that depend on them are reported as not verified.

In Cowork the skill loads, but it can only work when the session runs on your computer and has the project folder. That setup has not been tested. In a chat on claude.ai the skill cannot reach your project, so it says so and stops.

## What it runs, sends and fetches

The skill runs one bundled bash script, `skills/delivery-audit/scripts/collect-evidence.sh`, which reads the project and prints evidence for Claude to judge. Nothing is sent to Bohemica Studio. There is no telemetry, no account and no API key.

On your machine:

- It reads project files with grep, find, perl and git (`git ls-files`, `git log`). It runs `gitleaks` if that is installed.
- It writes one file into the project, `AUDIT.md`. Temporary files (fetched pages, the html-validate report, the Lighthouse report) go to the system temp folder.
- It does not install the project's dependencies, build the project or start it. It does not change Claude Code settings or permissions.
- It never prints a secret's value. Hits are reported as file and line.

Network, on every run:

- A dependency audit with the project's own package manager: `npm audit`, `pnpm audit`, `yarn npm audit`, `bun audit` or `composer audit`. This sends the dependency names and versions from the lockfile to the package registry the project is configured for.
- If the GitHub CLI is installed and logged in, and `origin` is a GitHub repository: read-only GitHub API calls through `gh` that ask whether that repository has vulnerability alerts and automated security fixes turned on. Skipped with `--quick`.
- If there is HTML to validate (build output, static pages, or pages fetched with `--url`) and `html-validate` is not installed: `npx` downloads `html-validate@10.17.0` from the npm registry (`9.7.1` on Node older than 20) and runs it on local copies of the pages.

Network, only with `--url`. Requests go to the site you name, with `curl`; redirects are followed:

- Response headers, `robots.txt`, `sitemap.xml` (and the sitemap that `robots.txt` points to), `llms.txt`, an address that should return 404, the `www` or non-`www` variant of the host, and one script or stylesheet that the home page references.
- The home page, also with the user-agent strings of a desktop browser, GPTBot and ClaudeBot, to see whether the site answers AI crawlers differently.
- The home page and up to four pages from the sitemap, saved to the temp folder for HTML validation.
- `/.env`, `/.git/config`, `/composer.json` and `/package.json`, then `/` and `/.env` on the server's IP address, to check that none of them is served. Only the status, the content type and a classification are printed, never the response body. Certificate checks are off for these requests, because a certificate does not match a bare IP.
- Lighthouse, unless `--quick` is set: it opens the home page in headless Chrome or Edge (flags `--headless=new --no-sandbox --disable-gpu`), and the browser loads whatever the page loads. If Lighthouse is not installed, `npx` downloads `lighthouse@12.8.2` from the npm registry.

Audit only sites you own or are allowed to test.

## Troubleshooting

- A tool is reported as unavailable (`html-validate`, `lighthouse`, `gh`, Chrome): the item is listed as not verified with the reason. Install the tool, or set `CHROME_PATH`, and run again.
- `npm audit` fails because there is no lockfile or the registry is private: SEC-04 is listed as not verified with the error line.
- Monorepo: point the skill at the app folder. One app is audited per run.
- Windows: run Claude Code where Git Bash is available. The scripts need bash and perl.
- To see the raw evidence without Claude, run `bash skills/delivery-audit/scripts/collect-evidence.sh /path/to/project --quick` from the plugin folder.

## Support, source and license

Questions and bug reports: https://github.com/bohemicastudio/standards/issues

Source, checklist format and contribution guide: https://github.com/bohemicastudio/standards

MIT license, see [LICENSE](LICENSE).
