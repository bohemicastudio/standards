---
name: delivery-audit
description: Audit a delivered web project (Nuxt, Vue/Vite SPA, Astro, Laravel, Strapi) for handover / go-live readiness against Bohemica delivery standards — security, deploy & HTTP headers, web standards (robots, sitemap, meta, OG, GDPR, a11y basics, forms) — and write a structured AUDIT.md. Use when asked to audit a project, check delivery readiness, review before handover or go-live, or "run the standards check". Supports --quick for a blockers-only pass.
argument-hint: "[path] [--public|--internal|--api] [--url https://live-site.example] [--quick]  (no arguments → interactive setup)"
---

# Delivery audit

You audit one delivered project and produce `AUDIT.md` in its root. You are strict about evidence: every finding cites a file and line or a command output line. You never invent findings to look thorough, and you never mark something as passed that you did not check.

Arguments received: `$ARGUMENTS`

## 0. Interactive setup (only when invoked with no arguments)

If `$ARGUMENTS` is empty, collect the run configuration in **one** `AskUserQuestion` call with these four questions, then continue as if the answers had been passed as flags. Do not run anything before the dialog.

1. **Target** (header `Target`): option 1 "Current directory — `<absolute cwd>`" (Recommended); option 2 "Another folder — I will pick it with @ in the next message" — description: "the normal prompt has path autocomplete, this dialog does not"; option 3 "A subfolder of this project (monorepo app)" — description: "you will be asked which one".
2. **Exposure** (header `Exposure`): "Public website" — marketing site, e-shop, portal anyone can reach; "Internal tool" — behind login, admin, intranet; "API only" — no UI; "Let the audit infer it" — from sitemap/SEO modules, auth middleware, routes.
3. **Live URL** (header `Live URL`): "No live URL — skip live checks" (Recommended when unsure); "Enter the production URL" — description: "enables header, robots, sitemap, 404, AI-crawler and Lighthouse checks; type it via Other".
4. **Mode** (header `Mode`): "Full audit" (Recommended) — every item, opens files for judgment calls, Lighthouse when a URL is given; "Quick" — blockers and script-decided items only, a couple of minutes.

If the user picked "Another folder", **end your turn** with one short line: "Reply with the project folder — type `@` to pick it (e.g. `@../client-project`)." Do not call any tool before the reply arrives. When the reply comes, strip a leading `@` and continue with the answers already collected. Do the same for "A subfolder" ("Reply with the app folder, e.g. `@apps/web`"). If the user picked "Enter the production URL" without typing one, ask for that single value in a second `AskUserQuestion`. If `AskUserQuestion` is unavailable (non-interactive session), skip the dialog and proceed with defaults: cwd, exposure inferred, no URL, full mode.

When `$ARGUMENTS` is non-empty, skip this step entirely.

## 1. Resolve the target and mode

- Path: first non-flag argument, else the current working directory (or the setup answer). Strip a leading `@` (the user may have picked the folder with the `@` file picker) and any trailing slash. Use an absolute path from here on.
- `--public` / `--internal` / `--api` set exposure. `--url <https://...>` enables live checks. `--quick` selects quick mode (see step 5). Anything else: ignore with a note.
- Monorepo (see `detect.md`, "Monorepos"): pick the deliverable app folder.

## 2. Collect evidence (one command)

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/collect-evidence.sh" "<target>" [--url <url>] [--quick]
```

This runs stack detection and every deterministic check for all items in one go (about 3 seconds locally, longer with `npm audit` or `--url`). The output starts with `=== STACK ===` (JSON, goes verbatim into the report) followed by one `=== <ITEM-ID> ===` block per checklist item. **Do not rerun the commands inside the blocks by hand and do not grep the project yourself for things the blocks already cover.** Rerun the script only if it failed outright.

If the script errors, fall back to `bash "${CLAUDE_SKILL_DIR}/scripts/detect-stack.sh" "<target>"` and say in the report that evidence collection was manual.

## 3. Resolve exposure and scope

Read `${CLAUDE_SKILL_DIR}/detect.md`. Apply the exposure resolution order: flag or setup answer → unambiguous inference from `STACK` → ask the user exactly one question. Then build the active tag set from the "Active tags" table. Apart from the setup dialog in step 0 and this one fallback question, do not ask anything during the audit.

## 4. Load references

- `${CLAUDE_SKILL_DIR}/frameworks/<framework>.md` if it exists (Nuxt → `nuxt.md`, vue-vite → `vue-spa.md`, astro, laravel, strapi).
- The checklists selected by the "Checklists to load" table in `detect.md` from `${CLAUDE_SKILL_DIR}/checklists/`.

Note planned-but-missing checklists for the "Not covered" section.

## 5. Evaluate items

Go through each loaded checklist in order. For each item:

1. **Scope:** skip silently if none of its **Applies to** tags is active. If the tag is active but the concept does not exist in this project, record `n/a` with one line of reason.
2. **Evidence:** read the block named in the item's **How**. Most items are decided from the block alone.
3. **Judgment:** where **How** says to open files (README, a handler, two representative pages, a form component), open only those, capped as stated. Use the framework locator to know where things live.
4. **Classify:** `pass`, `finding` with the item's severity (adjust only as the item says), `n/a`, or `not-verified` (tool missing, no `--url`, build output absent, script error line). Never guess.
5. **Record findings:** location as `relative/path:line` (or the evidence line from the block), one-sentence evidence, the fix from the checklist adapted to this project.

**Quick mode (`--quick`):** evaluate only items whose severity is `blocker` and items decided purely from their evidence block (no file opening). Everything else is recorded as `skipped (quick)`. Do not open project files in quick mode except to confirm a suspected blocker. Target: a couple of minutes.

Working rules:
- Do not modify the audited project. Only `AUDIT.md` is written.
- Do not run the app, install dependencies, or build. `npm audit` / `composer audit` run inside the script already.
- Do not read `node_modules`, `.output`, `.nuxt`, `dist`, `vendor`.
- Stay within the checklists. Something serious outside them goes under "Other observations", same evidence standard, at most five items.
- Never report a leaked secret's value; report the path and the key name only.

## 6. Write `AUDIT.md`

Overwrite `<target>/AUDIT.md` with exactly this structure (English, GitHub-flavoured Markdown):

~~~markdown
# Delivery audit — <project name from package.json/composer.json or folder>

- **Date:** YYYY-MM-DD
- **Mode:** full | quick
- **Audited path:** <absolute path>
- **Exposure:** public | internal | api (source: flag | inferred from … | asked)
- **Live URL:** <url or "not provided — live checks skipped">
- **Framework locator:** frameworks/nuxt.md | none
- **Checklists:** security, deploy-and-headers, web-standards
- **Plugin:** bohemica-standards <version from plugin.json> / delivery-audit

## Detected stack

```json
<STACK block verbatim>
```

## Summary

| Blockers | Warnings | Info | Passed | N/A | Not verified | Skipped (quick) |
|---|---|---|---|---|---|---|
| n | n | n | n | n | n | n |

<One paragraph: is this deliverable now? Name each blocker in one sentence.>

## Blockers

### SEC-01 No secrets committed to git
- **Location:** `.env:1`; block SEC-01 lists `.env` as tracked
- **Evidence:** `.env` is tracked and contains keys `DATABASE_URL`, `SMTP_PASSWORD`.
- **Fix:** Remove from git, add to `.gitignore`, rotate both credentials, keep `.env.example`.

## Warnings

(same item format)

## Info

(same item format)

## Passed

SEC-02, SEC-04, DEP-02, … (IDs only, comma-separated)

## N/A

- DEP-13 — static Astro site, no server process.

## Not verified

- DEP-08 HSTS — no `--url` given; no HSTS in repo config, set at the proxy?
- SEC-04 — `pnpm audit` failed: broken lockfile.

## Skipped (quick)

WEB-05, WEB-09, … (IDs only; section present only in quick mode)

## Not covered

- `api.md` (planned) — exposure is `api`, no checklist exists yet.

## Other observations

(optional, max five, same evidence standard)
~~~

Sort findings within a section by checklist ID. Use item titles from the checklists verbatim so reports are comparable across projects.

## 7. Report back to the user

Print at most five lines: mode, counts, the blockers by ID and title, and the path to `AUDIT.md`. Do not paste the whole report into the conversation.
