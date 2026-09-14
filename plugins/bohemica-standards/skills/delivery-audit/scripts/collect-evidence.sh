#!/usr/bin/env bash
# collect-evidence.sh — gather evidence for every deterministic checklist item in ONE run.
#
# Usage:  bash collect-evidence.sh [target-dir] [--url https://live-site] [--quick] [--only 10,40]
# Output: stack JSON (from detect-stack.sh) followed by one block per checklist item:
#           === SEC-01 ===
#           <command output, capped>  or  (none)
#         Claude reads the blocks and judges; it does not need to rerun the commands.
# Flags:  --url    enable live checks with curl (headers, robots, sitemap, 404 status)
#         --quick  skip slow optional tools (lighthouse); npm/composer audit still runs
#         --only   run only the check groups whose filename starts with these prefixes (debugging)
# Layout: lib/common.sh   helpers, project paths, stack JSON
#         checks/NN-*.sh  one file per checklist, sourced in filename order; each is a list of `block` calls
#         Add a checklist → add checks/NN-name.sh. Add an item → add a `block <ID>` to the matching file.
# Deps:   bash, grep, find, perl, git (optional), node (optional), curl (only with --url).
#         Never modifies the target. Never prints secret values.

set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET="."; URL=""; QUICK=0; ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --url) URL="${2:-}"; shift 2 ;;
    --url=*) URL="${1#--url=}"; shift ;;
    --quick) QUICK=1; shift ;;
    --only) ONLY="${2:-}"; shift 2 ;;
    --only=*) ONLY="${1#--only=}"; shift ;;
    --public|--internal|--api) shift ;;   # exposure flags are for the skill, ignore here
    *) TARGET="$1"; shift ;;
  esac
done
[ -d "$TARGET" ] || { echo "target directory not found: $TARGET"; exit 0; }
cd "$TARGET" || exit 0
URL="${URL%/}"

# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"

echo "### bohemica-standards evidence — $(date +%Y-%m-%d) — framework=$FRAMEWORK quick=$QUICK url=${URL:-none}"
echo "### paths: app=[$APP_DIRS] server=[$SERVER_DIRS] config=[$CONFIG_FILES] ci=[$CI_FILES] proxy=[$NGINX_FILES]"
echo
echo "=== STACK ==="
printf '%s\n' "$STACK_JSON"

for check in "$HERE"/checks/*.sh; do
  name="$(basename "$check")"
  if [ -n "$ONLY" ]; then
    case ",$ONLY," in *",${name%%-*},"*) ;; *) continue ;; esac
  fi
  # shellcheck disable=SC1090
  . "$check"
done

echo
echo "=== END ==="
