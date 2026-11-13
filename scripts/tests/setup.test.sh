#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STUBS="$ROOT/scripts/tests/stubs"
chmod +x "$STUBS"/*
fail() { echo "FAIL: $1"; exit 1; }

new_ws() { # fresh install folder with a copy of the root repo
  WS="$(mktemp -d)"; mkdir "$WS/metrc-manager-3000"
  cp -r "$ROOT/compose.yml" "$ROOT/.env.example" "$ROOT/scripts" "$WS/metrc-manager-3000/"
  export STUB_LOG="$WS/calls.log"; : > "$STUB_LOG"
}
run() { (cd "$WS/metrc-manager-3000" && PATH="$STUBS:$PATH" bash scripts/setup.sh "$@"); }
envv() { grep -E "^$1=" "$WS/metrc-manager-3000/.env" | head -1 | cut -d= -f2-; }

# clones missing siblings over SSH from GITHUB_ORG
new_ws
GITHUB_ORG=acme run --non-interactive >/dev/null
for r in platform client mcp keyservice; do
  grep -q "git clone --depth 1 git@github.com:acme/metrc-manager-3000-$r.git" "$STUB_LOG" || fail "did not clone $r"
done
[ "$(stat -c %a "$WS/metrc-manager-3000/.env")" = 600 ] || fail ".env not mode 600"

# generates secrets
for k in POSTGRES_PASSWORD NEXTAUTH_SECRET METRC_ENCRYPTION_KEY METRC_ENCRYPTION_SALT CRON_SECRET; do
  [ -n "$(envv $k)" ] || fail "$k not generated"
done

# keeps existing secrets
before="$(envv METRC_ENCRYPTION_KEY)"
run --non-interactive >/dev/null
[ "$(envv METRC_ENCRYPTION_KEY)" = "$before" ] || fail "rotated METRC_ENCRYPTION_KEY"

# --https clones over https
new_ws
run --non-interactive --https >/dev/null
grep -q "git clone --depth 1 https://github.com/staqsIO/metrc-manager-3000-platform.git" "$STUB_LOG" || fail "https clone"

# profiles persist and wire service URLs
new_ws
run --non-interactive --profiles mcp,ollama,keyservice >/dev/null
[ "$(envv COMPOSE_PROFILES)" = "mcp,ollama,keyservice" ] || fail "COMPOSE_PROFILES"
[ "$(envv METRC_MCP_URL)" = "http://metrc-mcp:8080" ] || fail "METRC_MCP_URL"
[ "$(envv OLLAMA_BASE_URL)" = "http://ollama:11434" ] || fail "OLLAMA_BASE_URL"
[ "$(envv KEY_SERVICE_URL)" = "http://keyservice:3001" ] || fail "KEY_SERVICE_URL"
[ -n "$(envv KEY_SERVICE_API_KEY)" ] && [ -n "$(envv KEYSERVICE_ENCRYPTION_KEY)" ] || fail "keyservice secrets"
grep -q "ollama pull qwen2.5:14b" "$STUB_LOG" || fail "did not pull ollama model"

# non-interactive without ADMIN_EMAIL prints the command and does not create
new_ws
out="$(run --non-interactive)"
echo "$out" | grep -q "docker compose run --rm web create-admin --email" || fail "no create-admin hint"
grep -q "create-admin --email" "$STUB_LOG" && fail "created admin without email"

# non-interactive with ADMIN_EMAIL creates the admin
new_ws
ADMIN_EMAIL=a@example.com ADMIN_PASSWORD=long-password-1 run --non-interactive >/dev/null
grep -q "create-admin --email a@example.com" "$STUB_LOG" || fail "admin not created"

# admin exists → no create
new_ws
STUB_ADMIN_CHECK=0 ADMIN_EMAIL=a@example.com ADMIN_PASSWORD=long-password-1 run --non-interactive >/dev/null
grep -q "create-admin --email" "$STUB_LOG" && fail "re-created existing admin"

# does not touch dirty sibling on --update
new_ws
mkdir -p "$WS/metrc-manager-3000-platform/.git"; echo " M src/x.ts" > "$WS/metrc-manager-3000-platform/.stub-status"
run --non-interactive --update >/dev/null
grep -q "git -C $WS/metrc-manager-3000-platform pull" "$STUB_LOG" && fail "pulled dirty sibling"

# missing compose v2 → exit 1 before writing .env
new_ws
if STUB_NO_COMPOSE=1 run --non-interactive >/dev/null 2>&1; then fail "should fail without compose"; fi
[ ! -f "$WS/metrc-manager-3000/.env" ] || fail "wrote .env despite missing compose"

# old compose (< 2.24) → exit 1 with a clear message, before writing .env
new_ws
if out="$(STUB_COMPOSE_VERSION=2.23.3 run --non-interactive 2>&1)"; then fail "should fail on compose 2.23"; fi
echo "$out" | grep -q "2.24" || fail "no version message"
[ ! -f "$WS/metrc-manager-3000/.env" ] || fail "wrote .env despite old compose"

# non-interactive with ADMIN_EMAIL but no ADMIN_PASSWORD → hint, no create
new_ws
out="$(ADMIN_EMAIL=a@example.com run --non-interactive)"
echo "$out" | grep -q "ADMIN_PASSWORD" || fail "no password hint"
grep -q "create-admin --email" "$STUB_LOG" && fail "created admin without password"

# non-interactive create passes the password via env, not argv, with -T
new_ws
ADMIN_EMAIL=a@example.com ADMIN_PASSWORD=long-password-1 run --non-interactive >/dev/null
grep -q "run --rm -T -e ADMIN_PASSWORD web create-admin --email a@example.com" "$STUB_LOG" || fail "wrong create-admin invocation"
grep -q "long-password-1" "$STUB_LOG" && fail "password leaked to argv"

# dropping a profile clears its default URL; custom URLs survive; "" clears profiles
new_ws
run --non-interactive --profiles mcp,cache >/dev/null
run --non-interactive --profiles "" >/dev/null
[ -z "$(envv METRC_MCP_URL)" ] || fail "stale METRC_MCP_URL"
[ -z "$(envv REDIS_URL)" ] || fail "stale REDIS_URL"
[ -z "$(envv COMPOSE_PROFILES)" ] || fail "profiles not cleared"
new_ws
run --non-interactive --profiles mcp >/dev/null
sed -i 's|^METRC_MCP_URL=.*|METRC_MCP_URL=http://custom:9|' "$WS/metrc-manager-3000/.env"
run --non-interactive --profiles "" >/dev/null
[ "$(envv METRC_MCP_URL)" = "http://custom:9" ] || fail "custom URL clobbered"

# backslashes and & survive env_set
. "$ROOT/scripts/lib/env.sh"
f="$(mktemp)"; echo "K=old" > "$f"
env_set "$f" K 'a\nb&c'
[ "$(env_get "$f" K)" = 'a\nb&c' ] || fail "env_set mangled value"

# unknown profile warns
new_ws
run --non-interactive --profiles bogus 2>&1 >/dev/null | grep -q "unknown profile" || fail "no unknown-profile warning"

# failed pull does not abort
new_ws
mkdir -p "$WS/metrc-manager-3000-platform/.git"
run --non-interactive --update >/dev/null 2>&1 || fail "update aborted"

# APP_URL env applies non-interactively
new_ws
APP_URL=https://x.example run --non-interactive >/dev/null
[ "$(envv APP_URL)" = "https://x.example" ] || fail "APP_URL"

# --update pulls a clean root repo, skips a dirty one
new_ws
mkdir -p "$WS/metrc-manager-3000/.git"
run --non-interactive --update >/dev/null 2>&1
grep -q "git -C $WS/metrc-manager-3000 pull --ff-only" "$STUB_LOG" || fail "root repo not pulled"
new_ws
mkdir -p "$WS/metrc-manager-3000/.git"; echo " M x" > "$WS/metrc-manager-3000/.stub-status"
run --non-interactive --update >/dev/null 2>&1
grep -q "git -C $WS/metrc-manager-3000 pull" "$STUB_LOG" && fail "pulled dirty root repo"

# health probe uses BIND_ADDRESS when set to a specific address
new_ws
run --non-interactive >/dev/null
grep -q "curl.*http://localhost:3000/api/health" "$STUB_LOG" || fail "default probe host"
new_ws
cp "$WS/metrc-manager-3000/.env.example" "$WS/metrc-manager-3000/.env"
env_set "$WS/metrc-manager-3000/.env" BIND_ADDRESS 127.0.0.1; env_set "$WS/metrc-manager-3000/.env" PORT 3100
run --non-interactive >/dev/null
grep -q "curl.*http://127.0.0.1:3100/api/health" "$STUB_LOG" || fail "bind address probe"

# a fresh install names the compose project metrc-manager-3000
new_ws
run --non-interactive >/dev/null
[ "$(envv COMPOSE_PROJECT_NAME)" = "metrc-manager-3000" ] || fail "fresh install COMPOSE_PROJECT_NAME"

# an install made before the rename keeps the old compose project, so its pgdata volume stays in use
new_ws
grep -v '^COMPOSE_PROJECT_NAME=' "$WS/metrc-manager-3000/.env.example" > "$WS/metrc-manager-3000/.env"
run --non-interactive --update >/dev/null 2>&1
[ -z "$(envv COMPOSE_PROJECT_NAME)" ] || fail "pre-rename install got a new COMPOSE_PROJECT_NAME"
grep -q '^name: metrc-formul8-os$' "$WS/metrc-manager-3000/compose.yml" || fail "compose fallback project name changed"

# sibling folders from before the rename are moved to the new names, not cloned again
new_ws
for r in platform client mcp keyservice; do mkdir -p "$WS/metrc-formul8-os-$r/.git"; done
run --non-interactive --update >/dev/null 2>&1
for r in platform client mcp keyservice; do
  [ -d "$WS/metrc-manager-3000-$r/.git" ] || fail "did not move $r"
  [ ! -e "$WS/metrc-formul8-os-$r" ] || fail "left old $r folder"
done
grep -q "git clone" "$STUB_LOG" && fail "re-cloned a moved sibling"

# the old default brand name is cleared so the new default applies; a custom name survives
new_ws
cp "$WS/metrc-manager-3000/.env.example" "$WS/metrc-manager-3000/.env"
env_set "$WS/metrc-manager-3000/.env" BRAND_NAME Formul8
run --non-interactive >/dev/null
[ -z "$(envv BRAND_NAME)" ] || fail "old default BRAND_NAME kept: $(envv BRAND_NAME)"
env_set "$WS/metrc-manager-3000/.env" BRAND_NAME Acme
run --non-interactive >/dev/null
[ "$(envv BRAND_NAME)" = "Acme" ] || fail "custom BRAND_NAME clobbered"

echo PASS
