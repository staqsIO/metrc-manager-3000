# Configuration reference

All settings live in `.env` (created by `scripts/setup.sh`). Apply changes with `docker compose up -d`; `BRAND_NAME` and `BRAND_LOGO_URL` need `--build`. Back up `.env`.

## General

| Variable | Required | Default | Description |
|---|---|---|---|
| `COMPOSE_PROFILES` | no | empty | Comma list of optional services started by `docker compose up`: mcp, ollama, cache, keyservice. |
| `GITHUB_ORG` | no | `staqsIO` | GitHub organization setup.sh clones sibling repositories from. |

## Required (setup.sh generates the secrets)

| Variable | Required | Default | Description |
|---|---|---|---|
| `APP_URL` | yes | `http://localhost:3000` | Public URL of the installation (used as NEXTAUTH_URL). Use https behind a proxy. |
| `PORT` | no | `3000` | Host port for the web app; the container always listens on 3000. |
| `BIND_ADDRESS` | no | `0.0.0.0` | Interface the web port is published on. Set `127.0.0.1` when a reverse proxy on the same host fronts the app, so the proxy (and its rate limit) cannot be bypassed. |
| `POSTGRES_PASSWORD` | yes | `generated` | Postgres password. Changing it after first start does not change the existing database. |
| `NEXTAUTH_SECRET` | yes | `generated` | Session signing secret. |
| `METRC_ENCRYPTION_KEY` | yes | `generated` | Encrypts stored facility keys. Never change after first use. |
| `METRC_ENCRYPTION_SALT` | yes | `generated` | Salt for the encryption key. Never change after first use. |
| `CRON_SECRET` | yes | `generated` | Authenticates cron-triggered endpoints. |
| `METRC_PLATFORM_ENABLED` | no | `true` | Kill switch: `false` disables the METRC platform features. |
| `AGENT_RUNS_ENABLED` | no | empty | `1` or `true` enables Copilot agent runs. |

## Sign-in

| Variable | Required | Default | Description |
|---|---|---|---|
| `GOOGLE_CLIENT_ID` | no | empty | Google sign-in client ID. Google sign-in requires a verified Google email and is enabled only when both Google variables are set. An unverified password account that signs in with Google is converted to a Google account (its password is cleared). |
| `GOOGLE_CLIENT_SECRET` | no | empty | Google sign-in client secret. |
| `ALLOWED_EMAIL_DOMAINS` | no | empty | Comma-separated allowed email domains; empty means no restriction. |
| `OPEN_SIGNUP` | no | `false` | Public sign-up is off unless `true`. Password sign-ups never join organizations via domain claims. |
| `AUTO_LOGIN_ISSUER_WHITELIST` | no | empty | Comma-separated token issuers allowed for portal auto-login; empty disables it. |

## METRC integrator (vendor) key

| Variable | Required | Default | Description |
|---|---|---|---|
| `METRC_VENDOR_API_KEY` | no | empty | METRC vendor (integrator) key; read by the platform and the MCP service. Facilities can store their own. |
| `METRC_VENDOR_API_KEY_CO` | no | empty | Colorado vendor key for platform seed scripts. |
| `METRC_USER_API_KEY` | no | empty | METRC user key read by the MCP service. |
| `METRC_USER_API_KEY_CO` | no | empty | Colorado user key for platform seed scripts. |

## AI Copilot bootstrap

| Variable | Required | Default | Description |
|---|---|---|---|
| `OPENROUTER_API_KEY` | no | empty | OpenRouter key; bootstraps a provider on first start, and is passed to the MCP service. |
| `OPENROUTER_MODEL` | no | `anthropic/claude-sonnet-4.6` | Default OpenRouter model (bootstrap). |
| `OLLAMA_BASE_URL` | no | empty | Ollama URL; `http://ollama:11434` with the `ollama` profile (bootstrap). |
| `OLLAMA_MODEL` | no | `qwen2.5:14b` | Ollama model; must support tool calling. |
| `LLM_DEFAULT_PROVIDER` | no | empty | `openrouter` or `ollama`: default provider when both exist (bootstrap). |

## Optional services (set automatically by setup.sh for chosen profiles)

| Variable | Required | Default | Description |
|---|---|---|---|
| `METRC_MCP_URL` | no | empty | MCP service URL; `http://metrc-mcp:8080` with the `mcp` profile. |
| `METRC_MCP_API_KEY` | no | `generated with mcp` | API key protecting the MCP service. |
| `METRC_API_URL` | no | `https://sandbox-api-co.metrc.com` | METRC API base URL used by the MCP service. |
| `MCP_ALLOWED_ORIGINS` | no | empty | Browser origins allowed by the MCP service (comma separated); empty means same-origin only. |
| `OPENROUTER_KEY_URL` | no | empty | Key service endpoint for the MCP `/chat` demo. |
| `OPENROUTER_KEY_TOKEN` | no | empty | Bearer token for that key service endpoint. |
| `METRC_DOCS_MCP_URL` | no | empty | Optional METRC docs MCP integration URL. |
| `METRC_DOCS_MCP_API_KEY` | no | empty | Key for the docs MCP integration. |
| `MULTIAGENT_API_URL` | no | empty | Optional multi-agent API URL. |
| `MULTIAGENT_API_KEY` | no | empty | Key for the multi-agent API. |
| `REDIS_URL` | no | empty | `redis://redis:6379` with the `cache` profile. |
| `KEY_SERVICE_URL` | no | empty | `http://keyservice:3001` with the `keyservice` profile (bootstrap). |
| `KEY_SERVICE_API_KEY` | no | `generated with keyservice` | Bearer token for the key service. |
| `KEYSERVICE_ENCRYPTION_KEY` | no | `generated with keyservice` | Encrypts keys stored by the key service. Never change after storing keys. |
| `KEYSERVICE_ALLOWED_ORIGINS` | no | empty | Browser origins allowed by the key service; empty means none. |

## Email (domain verification)

| Variable | Required | Default | Description |
|---|---|---|---|
| `RESEND_API_KEY` | no | empty | Resend key for emails such as domain verification. |

## Branding

| Variable | Required | Default | Description |
|---|---|---|---|
| `BRAND_NAME` | no | `Formul8` | Product name. Build-time: run `docker compose up -d --build` after changing. |
| `BRAND_LOGO_URL` | no | empty | Logo URL. Build-time: rebuild after changing. |
| `SUPPORT_EMAIL` | no | empty | Support address shown in the app and emails. |
| `EMAIL_FROM` | no | empty | Sender address for emails. |
| `EMAIL_LOGO_URL` | no | `APP_URL/brand/logo.png` | Optional logo used in emails. |

## Sync schedule (cron syntax; empty disables a job)

| Variable | Required | Default | Description |
|---|---|---|---|
| `CRON_SYNC_DAILY` | no | `0 7 * * *` | Daily sync schedule (cron syntax; empty disables). |
| `CRON_SYNC_FULL` | no | `0 8 1 * *` | Full sync schedule. |
| `CRON_SYNC_SALES` | no | `0 * * * *` | Sales sync schedule. |

## Optional

| Variable | Required | Default | Description |
|---|---|---|---|
| `ADMIN_EMAIL` | no | unset | Email for `create-admin` (setup.sh non-interactive). |
| `ADMIN_PASSWORD` | no | unset | Password for `create-admin`; passed via environment, never as an argument. |
| `ADMIN_ORG` | no | unset | Organization name for the first admin. |

`DATABASE_URL` and `NEXTAUTH_URL` are set by `compose.yml` (from `POSTGRES_PASSWORD` and `APP_URL`); do not put them in `.env`. If you set a separate `DASHBOARD_DATABASE_URL`, migrations still run only against `DATABASE_URL`; that setup is unsupported.

The `*_URL` and key values for optional services are filled in by `scripts/setup.sh` when you choose the matching profile. AI provider variables are only read on first start; see [ai-copilot.md](ai-copilot.md).
