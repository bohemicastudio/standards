# Contributing

Thanks for helping make delivered websites better. This repo is small and opinionated; the rules below keep it that way.

## What we welcome

- **New checklist items** backed by a reason: a real incident, a documented standard, a measurable effect. Say where the item comes from.
- **Fixes to false positives and false negatives**: an evidence block that matches the wrong thing, a pattern that misses a common framework idiom. Include the snippet that fooled it.
- **Framework locators** (`frameworks/<name>.md`) for stacks we do not cover yet, and path additions in `scripts/lib/common.sh` so the evidence blocks see that framework's files.
- **Better How sections**: a sharper command, a smaller set of files to open. Anything that lets the model decide from the evidence block without reading the project.

## What we do not merge

- Per-framework checklists. Checklists are organised by concern (security, deploy, web); the framework only changes where to look. Use tags and locators instead.
- Content-strategy or marketing items (topic clusters, link building, share-of-voice). The audit checks what the delivery team controls.
- Items without a deterministic evidence block or a bounded judgment step ("read the whole project and see if…" is not an item).
- Anything that makes the audit write to the audited project other than `AUDIT.md`, run its build, or install its dependencies.

## Anatomy of an item

Every item has a stable ID (`SEC-`, `DEP-`, `WEB-` plus a number that is never reused), tags in **Applies to**, and four sections:

```markdown
### WEB-21 Key content is extractable from the raw HTML
- **Applies to:** public
- **Check:** what "good" looks like, in one paragraph a human reviewer could apply by hand
- **How:** which evidence block to read and what to judge; if files must be opened, which ones and how many at most
- **Severity:** blocker | warning | info — with the condition that changes it, if any
- **Fix:** the concrete remediation, framework-neutral, with framework specifics in parentheses
```

Tags: `all`, `server`, `spa`, `public`, `internal`, `api`, `node`, `docker`, `i18n`, `migration`, and framework tags `nuxt`, `vue-spa`, `astro`, `laravel`, `strapi`. `detect.md` says when each tag is active.

Severity means: **blocker** must be fixed before handover; **warning** should be fixed, acceptable with a documented follow-up; **info** improvement.

## Adding an item, step by step

1. Add the item at the end of the right checklist in `plugins/bohemica-standards/skills/delivery-audit/checklists/`. Next free number.
2. Add a `block <ID>` with the same ID to the matching file in `scripts/checks/` (`10-security.sh`, `20-deploy.sh`, `30-web.sh`, `40-web-geo.sh`, `45-html-validate.sh`, `50-lighthouse.sh`). Use the helpers from `scripts/lib/common.sh` (`g`, `gl`, `show`, `lsx`, `html_text`, `curl_head`, `curl_status`). Cap output; never print secret values.
3. If the block needs the live site, guard it with `[ -n "$URL" ]`; if it is slow, also `[ "$QUICK" = 0 ]`.
4. Run the self-check below and paste the relevant block output into the PR.
5. Update the ID range in `README.md` if you extended it.

A new checklist gets a new file in `checklists/`, a new `scripts/checks/NN-name.sh`, and a row in the "Checklists to load" table in `detect.md`.

## Adding a framework

1. One `elif` in `scripts/detect-stack.sh`.
2. Its source, server, config and page directories added to the `*_DIRS` / `*_FILES` lists in `scripts/lib/common.sh`.
3. A row in the "Active tags" table in `detect.md`.
4. `frameworks/<name>.md` copied from `nuxt.md`: concept → where it lives, plus gotchas.

Do not add a checklist. If the framework has a concern no existing item covers, add an item with the new tag.

## Self-check before a PR

```bash
# syntax
for f in plugins/bohemica-standards/skills/delivery-audit/scripts/*.sh plugins/bohemica-standards/skills/delivery-audit/scripts/*/*.sh; do bash -n "$f" || echo "FAIL $f"; done

# manifest
claude plugin validate ./plugins/bohemica-standards

# every item has a block (DEP-08/09/10 share DEP-08-10, so blocks = items - 2)
grep -hoE '^### (SEC|DEP|WEB)-[0-9]+' plugins/bohemica-standards/skills/delivery-audit/checklists/*.md | wc -l
grep -h '^block ' plugins/bohemica-standards/skills/delivery-audit/scripts/checks/*.sh | wc -l

# run on a real project, offline and live
bash plugins/bohemica-standards/skills/delivery-audit/scripts/collect-evidence.sh /path/to/project --quick
bash plugins/bohemica-standards/skills/delivery-audit/scripts/collect-evidence.sh /path/to/project --url https://... --only 30,40
```

Then run the skill itself on at least one real project with `claude --plugin-dir ./plugins/bohemica-standards` and check that the model decides your item from the block without extra grepping. If it reaches for its own commands, the How section is not specific enough.

Scripts must run under Git Bash on Windows as well as Linux and macOS: no `jq`, no GNU-only flags without a fallback, `perl` allowed, `node` optional.

## Pull requests

- One concern per PR: one item, one fix, one framework. Small PRs get merged; bundles get parked.
- Title in the form `WEB-24: FAQ answers rendered server-side` or `fix(SEC-06): stop matching readBody in comments`.
- Describe the false positive / negative or the source that motivated the change, and include the block output from a real run.
- No client data. Evidence snippets in a PR must come from public sites, fixtures, or be anonymised. Nothing from `knowledge/` goes into commits.
- English in everything that ships in the plugin. Czech is fine in issues and discussion.

## Versioning and releases

`plugin.json` and `marketplace.json` carry the version. Bump the patch for fixes, the minor for new items or frameworks. Users only receive an update when the version changes, so every merged change to the plugin folder needs a bump before it is useful to anyone.

## Reporting problems

Open an issue with: the framework and version, the item ID, the evidence block output, what the model concluded, and what it should have concluded. That is enough to reproduce most misfires.
