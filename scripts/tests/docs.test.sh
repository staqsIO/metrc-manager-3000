#!/usr/bin/env bash
# Every variable in .env.example must be documented in docs/configuration.md; README must contain the quickstart pieces.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
missing=0
for k in $(grep -oE '^[A-Z0-9_]+=' "$ROOT/.env.example" | tr -d '='); do
  grep -q "\`$k\`" "$ROOT/docs/configuration.md" || { echo "undocumented: $k"; missing=1; }
done
for s in "scripts/setup.sh" "docker compose up" "install.sh" "create-admin" "/admin/llm-providers" "Copy this prompt"; do
  grep -qF "$s" "$ROOT/README.md" || { echo "README missing: $s"; missing=1; }
done
[ "$missing" = 0 ] && echo PASS || exit 1
