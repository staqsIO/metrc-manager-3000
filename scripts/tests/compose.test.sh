#!/usr/bin/env bash
# Validates compose.yml renders for each profile combination (no containers started).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cp .env.example "$T/.env"
sed -i 's/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=test/' "$T/.env"
fail() { echo "FAIL: $1"; exit 1; }

services() { docker compose --env-file "$T/.env" "$@" config --services | sort | tr '\n' ' '; }

[ "$(services)" = "cron migrate postgres web " ] || fail "default services: $(services)"
all="$(services --profile mcp --profile ollama --profile cache --profile keyservice)"
[ "$all" = "cron keyservice metrc-mcp migrate ollama postgres redis web " ] || fail "all profiles: $all"
docker compose --env-file "$T/.env" config | grep -q 'postgresql://metrc:test@postgres:5432/metrc' || fail "DATABASE_URL not interpolated"
mcp_env="$(docker compose --env-file "$T/.env" --profile mcp config --format json | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin)["services"]["metrc-mcp"]["environment"]))')"
echo "$mcp_env" | grep -qE '^(NEXTAUTH_SECRET|METRC_ENCRYPTION_KEY|METRC_ENCRYPTION_SALT)$' && fail "metrc-mcp leaks platform secrets"
echo "$mcp_env" | grep -q '^MCP_API_KEY$' || fail "metrc-mcp missing MCP_API_KEY"
bind="$(BIND_ADDRESS=127.0.0.1 docker compose --env-file "$T/.env" config --format json | python3 -c 'import json,sys; print(json.load(sys.stdin)["services"]["web"]["ports"][0]["host_ip"])')"
[ "$bind" = "127.0.0.1" ] || fail "BIND_ADDRESS not applied: $bind"
echo PASS
