#!/usr/bin/env bash
# Installs and starts METRC Manager 3000. Safe to re-run: never overwrites existing secrets.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WS="$(cd "$ROOT/.." && pwd)"
ENV_FILE="$ROOT/.env"
# shellcheck source=lib/env.sh
# shellcheck disable=SC1091
. "$ROOT/scripts/lib/env.sh"

REPOS=(metrc-manager-3000-platform metrc-manager-3000-client metrc-manager-3000-mcp metrc-manager-3000-keyservice)
INTERACTIVE=1; UPDATE=0; HTTPS=0; START=1; PROFILES=""; PROFILES_SET=0

usage() { echo "Usage: scripts/setup.sh [--non-interactive] [--update] [--https] [--profiles mcp,ollama,cache,keyservice] [--no-start]"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --non-interactive) INTERACTIVE=0 ;;
    --update) UPDATE=1 ;;
    --https) HTTPS=1 ;;
    --no-start) START=0 ;;
    --profiles) PROFILES="${2:-}"; PROFILES_SET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
  shift
done
[ -t 0 ] || INTERACTIVE=0

say()  { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
ask()  { # VAR PROMPT DEFAULT
  local __v="$1" prompt="$2" def="${3:-}" reply
  if [ "$INTERACTIVE" = 1 ]; then read -r -p "$prompt${def:+ [$def]}: " reply; printf -v "$__v" '%s' "${reply:-$def}";
  else printf -v "$__v" '%s' "$def"; fi
}
ask_secret() { # VAR PROMPT
  local __v="$1" reply=""
  if [ "$INTERACTIVE" = 1 ]; then read -r -s -p "$2: " reply; echo; fi
  printf -v "$__v" '%s' "$reply"
}
rand() { openssl rand -hex "$1"; }

# 1. Prerequisites — checked before anything is written
command -v git >/dev/null || die "git is required"
command -v docker >/dev/null || die "Docker is required: https://docs.docker.com/get-docker/"
cv="$(docker compose version --short 2>/dev/null || true)"
[ -n "$cv" ] || die "Docker Compose v2 is required (the 'docker compose' command)"
cv="$(printf '%s' "$cv" | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)"
if [ -z "$cv" ] || [ "${cv%%.*}" -lt 2 ] || { [ "${cv%%.*}" -eq 2 ] && [ "${cv#*.}" -lt 24 ]; }; then
  die "Docker Compose 2.24 or newer is required (found ${cv:-unknown}); upgrade: https://docs.docker.com/compose/install/"
fi
command -v curl >/dev/null || die "curl is required"
command -v openssl >/dev/null || die "openssl is required"

# 2. Siblings
GITHUB_ORG="${GITHUB_ORG:-$(env_get "$ENV_FILE" GITHUB_ORG)}"; GITHUB_ORG="${GITHUB_ORG:-staqsIO}"
if [ "$UPDATE" = 1 ]; then
  if [ ! -e "$ROOT/.git" ]; then warn "root repo is not a git repository; skipping update"
  elif [ -n "$(git -C "$ROOT" status --porcelain)" ]; then warn "root repo has local changes; skipping update"
  else say "Updating root repo"; git -C "$ROOT" pull --ff-only || warn "root repo: update failed; continuing"; fi
fi
for repo in "${REPOS[@]}"; do
  dir="$WS/$repo"
  # Installs made before the rename have metrc-formul8-os-* folders; move them rather than clone again.
  old="$WS/metrc-formul8-os-${repo#metrc-manager-3000-}"
  if [ ! -e "$dir" ] && [ -d "$old" ]; then say "Moving ${old##*/} to $repo"; mv "$old" "$dir"; fi
  if [ ! -d "$dir" ]; then
    if [ "$HTTPS" = 1 ]; then url="https://github.com/$GITHUB_ORG/$repo.git"; else url="git@github.com:$GITHUB_ORG/$repo.git"; fi
    say "Cloning $repo"
    if ! git clone --depth 1 "$url" "$dir"; then
      [ "$HTTPS" = 1 ] && die "clone of $repo failed"
      die "clone of $repo failed. SSH clone failed - use --https or configure GitHub SSH keys"
    fi
  elif [ "$UPDATE" = 1 ]; then
    if [ ! -d "$dir/.git" ]; then warn "$repo is not a git repository; skipping update"
    elif [ -n "$(git -C "$dir" status --porcelain)" ]; then warn "$repo has local changes; skipping update"
    else say "Updating $repo"; git -C "$dir" pull --ff-only || warn "$repo: update failed; continuing"; fi
  fi
done

# 3. .env with generated secrets
if [ ! -f "$ENV_FILE" ]; then
  (umask 077; cp "$ROOT/.env.example" "$ENV_FILE")
  say "Created .env"
fi
chmod 600 "$ENV_FILE"
env_set "$ENV_FILE" GITHUB_ORG "$GITHUB_ORG"
env_set_if_empty "$ENV_FILE" POSTGRES_PASSWORD "$(rand 24)"
env_set_if_empty "$ENV_FILE" NEXTAUTH_SECRET "$(rand 32)"
env_set_if_empty "$ENV_FILE" METRC_ENCRYPTION_KEY "$(rand 32)"
env_set_if_empty "$ENV_FILE" METRC_ENCRYPTION_SALT "$(rand 16)"
env_set_if_empty "$ENV_FILE" CRON_SECRET "$(rand 32)"

# 4. Profiles and the settings they imply
[ "$PROFILES_SET" = 1 ] || PROFILES="$(env_get "$ENV_FILE" COMPOSE_PROFILES)"
if [ "$INTERACTIVE" = 1 ] && [ "$PROFILES_SET" = 0 ] && [ -z "$PROFILES" ]; then
  ask PROFILES "Optional services (comma list of mcp, ollama, cache, keyservice; empty for none)" ""
fi
PROFILES="$(echo "$PROFILES" | tr -d ' ')"
env_set "$ENV_FILE" COMPOSE_PROFILES "$PROFILES"
has() { [[ ",$PROFILES," == *",$1,"* ]]; }
for p in ${PROFILES//,/ }; do
  case "$p" in mcp|ollama|cache|keyservice) ;; *) warn "unknown profile '$p' (valid: mcp, ollama, cache, keyservice)" ;; esac
done
# Reset managed URLs of dropped profiles, only when they still hold our own default
reset_default() { [ "$(env_get "$ENV_FILE" "$1")" != "$2" ] || env_set "$ENV_FILE" "$1" ""; }
has mcp || reset_default METRC_MCP_URL "http://metrc-mcp:8080"
has ollama || reset_default OLLAMA_BASE_URL "http://ollama:11434"
has cache || reset_default REDIS_URL "redis://redis:6379"
has keyservice || reset_default KEY_SERVICE_URL "http://keyservice:3001"
# Before the rename .env.example set BRAND_NAME=Formul8; clear it so the new default applies.
reset_default BRAND_NAME "Formul8"
if has mcp; then env_set "$ENV_FILE" METRC_MCP_URL "http://metrc-mcp:8080"; env_set_if_empty "$ENV_FILE" METRC_MCP_API_KEY "$(rand 24)"; fi
if has ollama; then env_set_if_empty "$ENV_FILE" OLLAMA_BASE_URL "http://ollama:11434"; fi
if has cache; then env_set "$ENV_FILE" REDIS_URL "redis://redis:6379"; fi
if has keyservice; then
  env_set "$ENV_FILE" KEY_SERVICE_URL "http://keyservice:3001"
  env_set_if_empty "$ENV_FILE" KEY_SERVICE_API_KEY "$(rand 32)"
  env_set_if_empty "$ENV_FILE" KEYSERVICE_ENCRYPTION_KEY "$(rand 32)"
fi

# 5. Optional questions (interactive only; skipped when already set)
if [ "$INTERACTIVE" = 1 ]; then
  ask v "Public URL of this installation" "${APP_URL:-$(env_get "$ENV_FILE" APP_URL)}"; env_set "$ENV_FILE" APP_URL "$v"
  if [ -z "$(env_get "$ENV_FILE" OPENROUTER_API_KEY)" ]; then
    ask_secret v "OpenRouter API key for the AI Copilot (Enter to skip)"; [ -z "$v" ] || env_set "$ENV_FILE" OPENROUTER_API_KEY "$v"
  fi
  if [ -z "$(env_get "$ENV_FILE" METRC_VENDOR_API_KEY)" ]; then
    ask_secret v "METRC vendor (integrator) API key (Enter to skip)"; [ -z "$v" ] || env_set "$ENV_FILE" METRC_VENDOR_API_KEY "$v"
  fi
elif [ -n "${OPENROUTER_API_KEY:-}" ]; then
  env_set_if_empty "$ENV_FILE" OPENROUTER_API_KEY "$OPENROUTER_API_KEY"
fi
[ "$INTERACTIVE" = 1 ] || [ -z "${APP_URL:-}" ] || env_set "$ENV_FILE" APP_URL "$APP_URL"

[ "$START" = 1 ] || { say "Configuration written to .env (not starting: --no-start)"; exit 0; }

# 6. Start
cd "$ROOT"
say "Building and starting containers (first build takes a few minutes)"
docker compose up -d --build
APP_URL_V="$(env_get "$ENV_FILE" APP_URL)"; PORT_V="$(env_get "$ENV_FILE" PORT)"
BIND_V="$(env_get "$ENV_FILE" BIND_ADDRESS)"
case "$BIND_V" in ""|0.0.0.0) PROBE_HOST=localhost ;; *) PROBE_HOST="$BIND_V" ;; esac
HEALTH="http://${PROBE_HOST}:${PORT_V:-3000}/api/health"
say "Waiting for $HEALTH"
for _ in $(seq 1 90); do curl -fsS "$HEALTH" >/dev/null 2>&1 && break; sleep 2; done
curl -fsS "$HEALTH" >/dev/null 2>&1 || die "web did not become healthy; see: docker compose logs web migrate"

if has ollama; then
  model="${OLLAMA_MODEL:-$(env_get "$ENV_FILE" OLLAMA_MODEL)}"; model="${model:-qwen2.5:14b}"
  say "Pulling Ollama model $model (large download)"
  docker compose exec -T ollama ollama pull "$model" || warn "model pull failed; run: docker compose exec ollama ollama pull $model"
fi

# 7. First super admin
set +e; docker compose run --rm -T web create-admin --check >/dev/null 2>&1; check=$?; set -e
if [ "$check" != 0 ] && [ "$check" != 3 ]; then warn "could not check for a super admin (exit $check)"; fi
if [ "$check" = 3 ]; then
  email="${ADMIN_EMAIL:-}"
  [ -n "$email" ] || ask email "Super admin email" ""
  if [ -z "$email" ]; then
    say "No super admin yet. Create one with:"
    echo "    docker compose run --rm web create-admin --email you@example.com"
  elif [ -n "${ADMIN_PASSWORD:-}" ]; then
    # Non-interactive: the password travels via the environment, never argv
    docker compose run --rm -T -e ADMIN_PASSWORD web create-admin --email "$email"
    ADMIN_CREATED="$email"
  elif [ "$INTERACTIVE" = 1 ]; then
    # The container's own TTY prompt asks for the password (twice)
    docker compose run --rm web create-admin --email "$email"
    ADMIN_CREATED="$email"
  else
    say "No super admin yet. Set ADMIN_PASSWORD, or run interactively:"
    echo "    docker compose run --rm web create-admin --email $email"
  fi
fi

say "METRC Manager 3000 is running at ${APP_URL_V:-http://localhost:3000}"
[ -z "${ADMIN_CREATED:-}" ] || echo "    Sign in as ${ADMIN_CREATED}"
echo "    Configure AI providers: ${APP_URL_V:-http://localhost:3000}/admin/llm-providers"
echo "    Logs: docker compose logs -f web    Stop: docker compose down"
