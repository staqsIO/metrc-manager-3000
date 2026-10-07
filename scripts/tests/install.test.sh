#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STUBS="$(mktemp -d)"; T="$(mktemp -d)"; trap 'rm -rf "$STUBS" "$T"' EXIT
export STUB_LOG="$T/log"; : > "$STUB_LOG"
cat > "$STUBS/git" <<'EOF'
#!/usr/bin/env bash
echo "git $*" >> "$STUB_LOG"
dest="${@: -1}"; mkdir -p "$dest/scripts"
printf '#!/usr/bin/env bash\necho "setup $*" >> "$STUB_LOG"\n' > "$dest/scripts/setup.sh"
EOF
chmod +x "$STUBS/git"

# Test 1: HTTPS (default) with args
(cd "$T" && PATH="$STUBS:$PATH" METRC_OS_DIR="$T/inst" bash "$ROOT/scripts/install.sh" --non-interactive --profiles mcp)
grep -q "git clone --depth 1 https://github.com/staqsIO/metrc-formul8-os.git $T/inst/metrc-formul8-os" "$STUB_LOG" || { echo "FAIL clone"; cat "$STUB_LOG"; exit 1; }
grep -q "setup --non-interactive --profiles mcp --https" "$STUB_LOG" || { echo "FAIL setup args"; cat "$STUB_LOG"; exit 1; }

# Test 2: SSH mode uses git@ URL and no --https
STUB_LOG2="$T/log2"; : > "$STUB_LOG2"
export STUB_LOG="$STUB_LOG2"
(cd "$T" && PATH="$STUBS:$PATH" METRC_OS_DIR="$T/inst2" bash "$ROOT/scripts/install.sh" --ssh --non-interactive)
grep -q "git clone --depth 1 git@github.com:staqsIO/metrc-formul8-os.git $T/inst2/metrc-formul8-os" "$STUB_LOG2" || { echo "FAIL ssh clone"; cat "$STUB_LOG2"; exit 1; }
grep -q "setup --non-interactive" "$STUB_LOG2" || { echo "FAIL ssh setup args"; cat "$STUB_LOG2"; exit 1; }
grep -q -- "--https" "$STUB_LOG2" && { echo "FAIL ssh should not have --https"; cat "$STUB_LOG2"; exit 1; }

# Test 3: Second run with same METRC_OS_DIR does not re-clone
STUB_LOG3="$T/log3"; : > "$STUB_LOG3"
export STUB_LOG="$STUB_LOG3"
(cd "$T" && PATH="$STUBS:$PATH" METRC_OS_DIR="$T/inst" bash "$ROOT/scripts/install.sh" --non-interactive --profiles other)
grep -q "git clone" "$STUB_LOG3" && { echo "FAIL should not re-clone"; cat "$STUB_LOG3"; exit 1; }
grep -q "setup --non-interactive --profiles other --https" "$STUB_LOG3" || { echo "FAIL second run setup args"; cat "$STUB_LOG3"; exit 1; }

echo PASS
