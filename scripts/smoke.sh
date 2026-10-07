#!/usr/bin/env bash
# Fresh-install smoke test: setup → health → create-admin → credentials sign-in → authenticated requests.
# Usage: scripts/smoke.sh [setup.sh flags, e.g. --https --profiles mcp,keyservice]
# Leaves the stack running unless SMOKE_DOWN=1 (then: docker compose down -v on success).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export ADMIN_EMAIL="${ADMIN_EMAIL:-smoke@example.com}" ADMIN_PASSWORD="${ADMIN_PASSWORD:-smoke-password-1}"

fail() { echo "SMOKE FAIL: $*" >&2; exit 1; }
ok() { echo "ok - $*"; }

bash scripts/setup.sh --non-interactive "$@"
# shellcheck source=lib/env.sh
# shellcheck disable=SC1091
. scripts/lib/env.sh
PORT_V="$(env_get .env PORT)"
BASE="http://localhost:${PORT_V:-3000}"
PROFILES="$(env_get .env COMPOSE_PROFILES)"
has() { [[ ",$PROFILES," == *",$1,"* ]]; }
JAR="$(mktemp)"; trap 'rm -f "$JAR"' EXIT

# migrate ran once and exited cleanly
migrate="$(docker compose ps -a --format '{{.Service}} {{.State}} {{.ExitCode}}' | awk '$1=="migrate"{print $2, $3}')"
[ "$migrate" = "exited 0" ] || fail "migrate is '${migrate:-missing}', expected 'exited 0'"
ok "migrate exited 0"

# Long-running services stay up (catches crash loops that health checks miss)
svc_state() { docker compose ps -a --format '{{.Service}} {{.State}}' | awk -v s="$1" '$1==s{print $2}'; }
want="postgres web cron"; has mcp && want="$want metrc-mcp"; has keyservice && want="$want keyservice"
sleep 5
for s in $want; do
  st="$(svc_state "$s")"; [ "$st" = running ] || fail "$s is '${st:-missing}', expected 'running' (docker compose logs $s)"
  rc="$(docker inspect -f '{{.RestartCount}}' "$(docker compose ps -q "$s")")"
  [ "$rc" = 0 ] || fail "$s restarted $rc times (docker compose logs $s)"
done
ok "running: $want"

curl -fsS "$BASE/api/health" | grep -q '"ok":true' || fail "web /api/health not ok"
ok "web /api/health"

# Optional services: poll briefly, setup only waits for web
wait_for() { # NAME CMD...
  local name="$1"; shift
  for _ in $(seq 1 30); do "$@" >/dev/null 2>&1 && { ok "$name"; return 0; }; sleep 2; done
  fail "$name did not respond"
}
if has mcp; then
  wait_for "metrc-mcp /health" docker compose exec -T metrc-mcp node -e \
    "fetch('http://localhost:8080/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
fi
if has keyservice; then
  wait_for "keyservice /api/health" docker compose exec -T keyservice node -e \
    "fetch('http://localhost:3001/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
fi

# Credentials sign-in (NextAuth provider id: password)
csrf="$(curl -fsS -c "$JAR" -b "$JAR" "$BASE/api/auth/csrf" | sed -nE 's/.*"csrfToken":"([^"]+)".*/\1/p')"
[ -n "$csrf" ] || fail "no csrf token"
curl -fsS -c "$JAR" -b "$JAR" -o /dev/null -X POST "$BASE/api/auth/callback/password" \
  --data-urlencode "csrfToken=$csrf" --data-urlencode "email=$ADMIN_EMAIL" \
  --data-urlencode "password=$ADMIN_PASSWORD" --data-urlencode "json=true" || fail "credentials callback failed"
session="$(curl -fsS -b "$JAR" "$BASE/api/auth/session")"
echo "$session" | grep -q "\"email\":\"$ADMIN_EMAIL\"" || fail "sign-in failed: $session"
echo "$session" | grep -q '"isPlatformAdmin":true' || fail "not super admin: $session"
ok "signed in as super admin $ADMIN_EMAIL"

code="$(curl -s -o /dev/null -w '%{http_code}' -b "$JAR" "$BASE/admin/llm-providers")"
[ "$code" = 200 ] || fail "admin page returned $code"
ok "GET /admin/llm-providers 200"

code="$(curl -s -o /dev/null -w '%{http_code}' -b "$JAR" "$BASE/api/trpc/llmProviders.list")"
[ "$code" = 200 ] || fail "tRPC llmProviders.list returned $code"
ok "GET /api/trpc/llmProviders.list 200"

echo "SMOKE PASS"
if [ "${SMOKE_DOWN:-0}" = 1 ]; then docker compose down -v; fi
