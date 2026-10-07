#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $1"; exit 1; }

# Create temporary banned list
BANNED="$T/banned.txt"
echo "acme cannabis" > "$BANNED"

mkdir -p "$T/clean/src" "$T/dirty/src" "$T/ignored/node_modules/x" "$T/ignored/.git"
echo 'export const ok = 1' > "$T/clean/src/a.ts"
echo '// per Acme Cannabis meeting' > "$T/dirty/src/b.ts"
echo 'acme cannabis' > "$T/ignored/node_modules/x/c.js"
echo 'acme cannabis' > "$T/ignored/.git/HEAD"
echo 'acme cannabi' > "$T/clean/src/c.ts"

# Test 1: clean tree passes
SCRUB_BANNED="$BANNED" "$HERE/scrub-check.sh" "$T/clean" >/dev/null || fail "clean tree reported dirty"

# Test 2: dirty tree fails with correct format
if out=$(SCRUB_BANNED="$BANNED" "$HERE/scrub-check.sh" "$T/dirty" 2>&1); then fail "dirty tree passed"; fi
echo "$out" | grep -q "src/b.ts:1:acme cannabis" || fail "missing file:line:pattern, got: $out"

# Test 3: excluded directories are skipped
SCRUB_BANNED="$BANNED" "$HERE/scrub-check.sh" "$T/ignored" >/dev/null || fail "scanned node_modules or .git"

# Test 4: missing banned list exits with code 2
exit_code=0
SCRUB_BANNED="$T/nonexistent.txt" "$HERE/scrub-check.sh" "$T/clean" >/dev/null 2>&1 || exit_code=$?
[ "$exit_code" -eq 2 ] || fail "expected exit code 2 for missing banned list, got $exit_code"

# Test 5: banned list with only comments/blank lines exits with code 2
EMPTY_BANNED="$T/empty.txt"
echo "# only a comment" > "$EMPTY_BANNED"
echo "" >> "$EMPTY_BANNED"
exit_code=0
SCRUB_BANNED="$EMPTY_BANNED" "$HERE/scrub-check.sh" "$T/clean" >/dev/null 2>&1 || exit_code=$?
[ "$exit_code" -eq 2 ] || fail "expected exit code 2 for empty banned list, got $exit_code"

echo "PASS"
