#!/usr/bin/env bash
# Tests scripts/publish.sh against a temp repo (gitleaks skipped; no remote is ever contacted).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; PUB="$HERE/../publish.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

R="$T/demo-repo"; mkdir -p "$R/docs/specs" "$R/docs/superpowers" "$R/src"
cd "$R"; git init -q -b main; git config user.email t@example.com; git config user.name t
echo spec > docs/specs/x.md; echo plan > docs/superpowers/y.md; echo ok > src/a.txt
echo "# fp" > .gitleaksignore; echo "/repo/docs/superpowers/y.md:generic-api-key:3" >> .gitleaksignore
echo .env.example-ish > .env.example
git add -A; git commit -qm one; echo more >> src/a.txt; git commit -qam two
printf 'nothing-banned-here-zzz\n' > "$T/banned.txt"
export SCRUB_BANNED="$T/banned.txt" PUBLISH_SKIP_GITLEAKS=1

out="$(bash "$PUB" "$R")"; echo "$out"
echo "$out" | grep -q "public branch ready" || fail "no ready line"
[ "$(git rev-list --count public)" = 1 ] || fail "public commit count"
files="$(git ls-tree -r public --name-only)"
echo "$files" | grep -q '^src/a.txt$' || fail "normal file missing"
echo "$files" | grep -q '^\.env\.example$' || fail ".env.example missing"
! echo "$files" | grep -Eq 'docs/specs|docs/superpowers' || fail "internal docs present"
! echo "$files" | grep -q '^\.gitleaksignore$' || fail ".gitleaksignore present"
[ "$(git symbolic-ref --short HEAD)" = main ] || fail "branch not restored"
[ -z "$(git status --porcelain)" ] || fail "tree dirty"
[ -f docs/specs/x.md ] || fail "main working tree lost docs"

# .gitleaksignore kept when an entry still points at a shipped file
echo "src/a.txt:generic-api-key:1" >> .gitleaksignore; git commit -qam keep
bash "$PUB" "$R" >/dev/null
git ls-tree -r public --name-only | grep -q '^\.gitleaksignore$' || fail ".gitleaksignore wrongly dropped"

# --push without confirmation must fail and never add a remote
set +e; bash "$PUB" "$R" --push 2>"$T/err"; rc=$?; set -e
[ "$rc" -ne 0 ] || fail "--push without confirmation succeeded"
grep -q PUBLISH_CONFIRMED "$T/err" || fail "no confirmation message"
[ -z "$(git remote)" ] || fail "remote was added"

# --push guards: scan-bypass env vars and remote mismatch abort before any git work or network
set +e
PUBLISH_CONFIRMED=yes bash "$PUB" "$R" --push 2>"$T/err"; rc=$?   # SCRUB_BANNED + SKIP_GITLEAKS exported above
set -e
[ "$rc" -ne 0 ] || fail "--push with bypass env succeeded"
grep -q "refusing --push" "$T/err" || fail "no bypass refusal message"
[ -z "$(git remote)" ] || fail "remote added on refused push"
if [ -s "$HERE/../scrub-banned.local.txt" ]; then
  git init -q --bare "$T/bare.git"; git remote add public "$T/bare.git"
  set +e
  env -u SCRUB_BANNED -u PUBLISH_SKIP_GITLEAKS PUBLISH_CONFIRMED=yes bash "$PUB" "$R" --push 2>"$T/err"; rc=$?
  set -e
  [ "$rc" -ne 0 ] || fail "remote mismatch did not abort"
  grep -q "expected" "$T/err" || fail "no mismatch message"
  [ -z "$(git -C "$T/bare.git" for-each-ref)" ] || fail "bare remote received refs"
  git remote remove public
else
  echo "note: no local banned list; remote-mismatch test skipped"
fi

# a scrub hit leaves refs/heads/public unchanged and no temp refs
prev="$(git rev-parse refs/heads/public)"
# a forbidden banned string aborts and still leaves main clean
echo "nothing-banned-here-zzz" > src/b.txt; git add -A; git commit -qm bad
set +e; bash "$PUB" "$R" >/dev/null 2>&1; rc=$?; set -e
[ "$rc" -ne 0 ] || fail "scrub hit did not abort"
[ "$(git symbolic-ref --short HEAD)" = main ] && [ -z "$(git status --porcelain)" ] || fail "not restored after failure"
[ "$(git rev-parse refs/heads/public)" = "$prev" ] || fail "public moved despite scrub hit"
[ -z "$(git for-each-ref refs/publish-tmp)" ] || fail "temp ref leaked"

# forbidden paths abort and never create public
R2="$T/r2"; git init -q -b main "$R2"; cd "$R2"; git config user.email t@e.com; git config user.name t
echo x > .env.local; echo y > .env.example; git add -A; git commit -qm a
set +e; bash "$PUB" "$R2" >/dev/null 2>&1; rc=$?; set -e
[ "$rc" -ne 0 ] || fail ".env.local not blocked"
git rev-parse -q --verify refs/heads/public >/dev/null && fail "public created despite forbidden path"
git rm -q --cached .env.local; git commit -qm b; echo t > .gitleaks.toml; git add -A; git commit -qm c
set +e; bash "$PUB" "$R2" >/dev/null 2>&1; rc=$?; set -e
[ "$rc" -ne 0 ] || fail ".gitleaks.toml not blocked"
echo "publish.test: PASS"
