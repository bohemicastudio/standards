# Bohemica standards

Claude Code plugin marketplace for Bohemica Studio. Contains the `bohemica-standards` plugin, which audits a delivered web project against our delivery standards and writes an `AUDIT.md` into the project.

Current scope (v0.1): security, deploy & HTTP headers, web standards including AI/GEO readiness and Lighthouse scores. Checklists are framework-neutral; framework locators exist for Nuxt, Vue/Vite SPA, Astro, Laravel and Strapi. Nuxt SSR is the most exercised path.

## Install

Inside Claude Code:

```
/plugin marketplace add bohemicastudio/standards
/plugin install bohemica-standards@bohemica
```

Source: https://github.com/bohemicastudio/standards. For a private repo, Claude Code uses your existing git credentials.

## Usage

```
/bohemica-standards:delivery-audit
/bohemica-standards:delivery-audit ./apps/web --public --url https://www.example.cz
/bohemica-standards:delivery-audit --internal --quick
```

- No arguments at all: the skill opens a short interactive dialog (target, exposure, live URL, full or quick) and then runs.
- `path` — project folder (default: current directory; in a monorepo point at the app).
- `--public` / `--internal` / `--api` — who will see it. If omitted and not obvious, the skill asks one question.
- `--url` — live site; enables header, robots, sitemap, 404 and AI-crawler checks with `curl`, plus a Lighthouse run (needs Chrome; the CLI is downloaded via `npx` if not installed).
- `--quick` — blockers and script-decided items only, no file reading, no Lighthouse. A couple of minutes instead of ten.

Output: `AUDIT.md` in the audited project with a summary table, findings grouped by severity (each with location, evidence, fix), passed IDs, n/a, not-verified items with their reason, and skipped items in quick mode.

## Local development

Run Claude Code with the plugin loaded straight from this checkout (the path points at the plugin folder, not the repo root):

```
claude --plugin-dir ./plugins/bohemica-standards
```

Nothing needs to be committed or pushed: the plugin is read from the working tree. Checklists, `detect.md`, framework locators and scripts are read fresh on every skill invocation. After editing `SKILL.md` frontmatter, `plugin.json` or hooks, run `/reload-plugins` inside the session.

Validate the manifest:

```
claude plugin validate ./plugins/bohemica-standards
```

Run the scripts on any project without Claude:

```
bash plugins/bohemica-standards/skills/delivery-audit/scripts/detect-stack.sh /path/to/project
bash plugins/bohemica-standards/skills/delivery-audit/scripts/collect-evidence.sh /path/to/project --quick
bash plugins/bohemica-standards/skills/delivery-audit/scripts/collect-evidence.sh /path/to/project --url https://www.example.cz --only 40,50
```

`--only` runs selected check groups by their filename prefix (see `scripts/checks/`), useful when tuning one group.

Requirements: bash, grep, find, perl (Git Bash on Windows has all of them), `git`, `node` and `curl`. Lighthouse needs Chrome or Edge installed; the CLI itself is downloaded through `npx` on first use if not installed.

## How it works

```
plugins/bohemica-standards/
├── .claude-plugin/plugin.json
└── skills/delivery-audit/
    ├── SKILL.md                  # procedure: collect evidence → exposure → scope → evaluate → AUDIT.md
    ├── detect.md                 # stack signals, exposure inference, active tags, which files to load
    ├── checklists/               # by concern, framework-neutral
    │   ├── security.md           # SEC-01 … SEC-18
    │   ├── deploy-and-headers.md # DEP-01 … DEP-16
    │   └── web-standards.md      # WEB-01 … WEB-23
    ├── frameworks/               # where each concept lives per framework
    │   └── nuxt.md, vue-spa.md, astro.md, laravel.md, strapi.md
    └── scripts/
        ├── detect-stack.sh       # deterministic stack detection → JSON
        ├── collect-evidence.sh   # one run, one evidence block per checklist item (orchestrator)
        ├── lib/common.sh         # helpers, project paths, stack JSON
        └── checks/               # one file per checklist, sourced in order
            ├── 10-security.sh, 20-deploy.sh, 30-web.sh, 40-web-geo.sh, 50-lighthouse.sh
```

Principles:

- **Deterministic things are scripts, not the model.** `collect-evidence.sh` runs every grep, `git ls-files`, `npm audit` and `curl` once and prints a block per item. Claude reads blocks; it does not re-grep the project. This is what keeps a run at a few minutes instead of a hundred tool calls.
- **The model does judgment.** "Does the README explain deployment?", "Is this handler validating input?", "Does the CSP make sense for this site?"
- **Evidence or it did not happen.** Every finding has a `path:line` or an evidence line. Unverifiable items are marked `not-verified`, never guessed.
- **Checklists by concern, locators by framework.** Adding a framework does not add a checklist.

## Writing checklist items

Each item is a human-usable checklist entry first. If it works for a person, it works for Claude.

```markdown
### SEC-07 Private handlers check authentication and authorization
- **Applies to:** server
- **Check:** what "good" looks like
- **How:** which evidence block to read and what to judge; which files to open, capped
- **Severity:** blocker | warning | info
- **Fix:** concrete remediation
```

IDs are stable and never reused. Tags: `all`, `server`, `spa`, `public`, `internal`, `api`, `node`, `docker`, `i18n`, `migration`, and framework tags `nuxt`, `vue-spa`, `astro`, `laravel`, `strapi`. When you add an item, add a matching `block <ID>` to the checklist's file in `scripts/checks/`; a new checklist gets a new `checks/NN-name.sh`.

Adding a framework: one `elif` in `detect-stack.sh`, paths in `scripts/lib/common.sh`, one row in `detect.md`, one file in `frameworks/`.

## Sources

`knowledge/` holds the documents the checklists cite (GEO e-book, aiworthy.com scan reports). It is reference material for maintainers, not part of the plugin, and may contain client data; keep it out of public forks.

## Contributing

Issues and pull requests are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) first: it explains what kind of items fit, the item format, how to add an evidence block, the self-check to run before a PR, and why per-framework checklists are not accepted. One concern per PR, English, no client data.

## Roadmap

- Checklists: `api.md` (Laravel API, Strapi, Node), `database-orm.md`, `performance.md`
- Scripts: `check-headers.sh` (expected-header diff for a list of URLs)
- Agents: parallel security / deploy / web reviewers for large projects
- Hooks: block committing `.env`, optionally run `--quick` before `git push`

## License

MIT — see [LICENSE](LICENSE).
