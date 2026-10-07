#!/usr/bin/env bash
# Fails when any banned string (scripts/scrub-banned.local.txt) appears in the given trees.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LIST="${SCRUB_BANNED:-$HERE/scrub-banned.local.txt}"
[ $# -ge 1 ] || { echo "usage: scrub-check.sh <dir>..." >&2; exit 2; }

if [ ! -f "$LIST" ]; then
  echo "scrub-check: banned list not found at $LIST (copy scripts/scrub-banned.example.txt to scripts/scrub-banned.local.txt and fill it in)" >&2
  exit 2
fi

PATTERNS="$(mktemp)"; trap 'rm -f "$PATTERNS"' EXIT
grep -v '^\s*#' "$LIST" | grep -v '^\s*$' > "$PATTERNS" || true

if [ ! -s "$PATTERNS" ]; then
  echo "scrub-check: banned list $LIST has no patterns" >&2
  exit 2
fi

status=0
for dir in "$@"; do
  while IFS= read -r hit; do
    file="${hit%%:*}"; rest="${hit#*:}"; line="${rest%%:*}"; text="${rest#*:}"
    while IFS= read -r pat; do
      if printf '%s' "$text" | grep -qiF -- "$pat"; then
        echo "${file#"$dir"/}:$line:$pat"; status=1
      fi
    done < "$PATTERNS"
  done < <(grep -rniIF -f "$PATTERNS" \
      --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=.next \
      --exclude='*.lock' --exclude=pnpm-lock.yaml --exclude=package-lock.json \
      --exclude=scrub-banned.local.txt --exclude=scrub-banned.example.txt "$dir" || true)
done
exit $status
