#!/usr/bin/env bash
# Builds a single-commit 'public' branch (no private history) from main, scans the exact
# tree that would be pushed, and only with --push (plus PUBLISH_CONFIRMED=yes) pushes it as main.
# Never touches the working tree or the checked-out branch: the commit is built from a
# temporary index and a temporary ref; refs/heads/public moves only after every check passes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$(cd "${1:?usage: publish.sh <repo-dir> [--push]}" && pwd)"; PUSH="${2:-}"
NAME="$(basename "$DIR")"; ORG="${GITHUB_ORG:-staqsIO}"
GITLEAKS_IMAGE="ghcr.io/gitleaks/gitleaks:v8.30.1"
TARGET="git@github.com:$ORG/$NAME.git"

[ -z "$PUSH" ] || [ "$PUSH" = "--push" ] || { echo "unknown argument: $PUSH" >&2; exit 2; }
if [ "$PUSH" = "--push" ]; then
  [ "${PUBLISH_CONFIRMED:-}" = "yes" ] || { echo "refusing --push: set PUBLISH_CONFIRMED=yes after explicit approval" >&2; exit 3; }
  # Scan-bypass knobs are for tests only; never allowed on the push path
  [ -z "${PUBLISH_SKIP_GITLEAKS+x}" ] || { echo "refusing --push: PUBLISH_SKIP_GITLEAKS is set" >&2; exit 3; }
  [ -z "${SCRUB_BANNED+x}" ] || { echo "refusing --push: SCRUB_BANNED is set (the default banned list must be used)" >&2; exit 3; }
  [ -s "$ROOT/scripts/scrub-banned.local.txt" ] || { echo "refusing --push: scripts/scrub-banned.local.txt missing or empty" >&2; exit 3; }
fi

cd "$DIR"
START_BRANCH="$(git symbolic-ref -q --short HEAD || true)"
[ -n "$START_BRANCH" ] || { echo "$NAME: detached HEAD" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "$NAME has uncommitted changes" >&2; exit 1; }
git rev-parse --verify -q main >/dev/null || { echo "$NAME has no main branch" >&2; exit 1; }
if [ "$PUSH" = "--push" ]; then
  existing="$(git remote get-url public 2>/dev/null || true)"
  if [ -n "$existing" ] && [ "$existing" != "$TARGET" ]; then
    echo "$NAME: remote 'public' points at '$existing', expected '$TARGET'; aborting" >&2; exit 4
  fi
fi

WORK="$(mktemp -d)"
TMPREF="refs/publish-tmp/$$"
cleanup() {
  rm -rf "$WORK"
  git update-ref -d "$TMPREF" 2>/dev/null || true
  if [ "$(git symbolic-ref -q --short HEAD || true)" != "$START_BRANCH" ]; then
    git checkout -q -f "$START_BRANCH" || true
  fi
}
trap cleanup EXIT

export GIT_INDEX_FILE="$WORK/index"
git read-tree main
# Internal planning docs never ship (they name the data the scrub hunts for)
git rm -rq --cached --ignore-unmatch -- docs/specs docs/superpowers
# Drop .gitleaksignore when none of its entries' paths remain in the tree
if git ls-files --error-unmatch .gitleaksignore >/dev/null 2>&1; then
  keep=0
  while IFS= read -r entry; do
    case "$entry" in ''|'#'*) continue ;; esac
    p="${entry%%:*}"; p="${p#/repo/}"; p="${p#/}"
    if [ -n "$(git ls-files -- "$p")" ]; then keep=1; fi
  done < <(git show main:.gitleaksignore)
  [ "$keep" = 1 ] || git rm -q --cached -- .gitleaksignore
fi
TREE_ID="$(git write-tree)"
# Export the index itself (not git archive, which honours export-ignore/export-subst)
EXPORT="$WORK/export"; mkdir "$EXPORT"
git checkout-index -a --prefix="$EXPORT/"
unset GIT_INDEX_FILE

COMMIT="$(printf 'Initial public release\n\nCo-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>\n' | git commit-tree "$TREE_ID")"
git update-ref "$TMPREF" "$COMMIT"

[ "$(git rev-list --count "$TMPREF")" = 1 ] || { echo "public commit has history" >&2; exit 1; }
LISTING="$(git ls-tree -r --name-only "$TMPREF")"
if printf '%s\n' "$LISTING" | grep -Ev '(^|/)\.env\.example$' \
   | grep -Eq '^(docs/specs/|docs/superpowers/|\.superpowers/)|(^|/)\.env(\..*)?$|(^|/)scrub-banned\.local\.txt$|(^|/)\.gitleaks\.toml$'; then
  echo "$NAME: forbidden path in public tree" >&2; exit 1
fi
EXPORTED="$(find "$EXPORT" -type f -o -type l | wc -l)"
[ "$EXPORTED" = "$(printf '%s\n' "$LISTING" | wc -l)" ] || { echo "$NAME: exported file count differs from public tree" >&2; exit 1; }

"$ROOT/scripts/scrub-check.sh" "$EXPORT"
if [ "${PUBLISH_SKIP_GITLEAKS:-}" != "1" ]; then
  docker run --rm -v "$EXPORT:/repo:ro" "$GITLEAKS_IMAGE" dir /repo --no-banner --redact
fi

# All checks passed: only now does refs/heads/public move
git update-ref refs/heads/public "$COMMIT"

if [ "$PUSH" = "--push" ]; then
  git remote get-url public >/dev/null 2>&1 || git remote add public "$TARGET"
  echo "$NAME: pushing refs/heads/public to $TARGET (main)"
  git push public refs/heads/public:refs/heads/main
fi
echo "$NAME: public branch ready${PUSH:+ and pushed}"
