# AI Copilot

The Copilot answers questions using your synced METRC data. Super admins manage providers at `/admin/llm-providers` (Super Admin, LLM Providers).

## Providers

### OpenRouter (external)

Prompts leave your server, but are anonymized first. Default model: `anthropic/claude-sonnet-4.6` (`OPENROUTER_MODEL`). Add the provider in the UI with your API key, or set `OPENROUTER_API_KEY` before first start.

### Ollama (local)

Data stays on your host. The model must support tool calling; recommended `qwen2.5:14b` (default) or `llama3.1:8b`.

- With the compose profile: `scripts/setup.sh --profiles ollama` (or `ollama` in `COMPOSE_PROFILES`), base URL `http://ollama:11434`. Setup pulls `OLLAMA_MODEL`; to pull another: `docker compose exec ollama ollama pull llama3.1:8b`.
- With Ollama installed on the host: on the host, set `OLLAMA_HOST=0.0.0.0` so containers can reach it, and firewall port 11434 from the outside. Base URL `http://host.docker.internal:11434`. On Linux, add this to the `web` service (for example in a `compose.override.yml`):

```yaml
services:
  web:
    extra_hosts: ["host.docker.internal:host-gateway"]
```

COA parsing uses the default provider's model when `openai/gpt-4o` is not offered, so local-only installs parse COAs with the local model.

Changing a provider's base URL or key service URL clears its stored secret unless you re-enter it.

## Bootstrap from `.env`

On first start, if no providers exist, they are created from `OPENROUTER_API_KEY`, `OPENROUTER_MODEL`, `OLLAMA_BASE_URL`, `OLLAMA_MODEL`, `KEY_SERVICE_URL`/`KEY_SERVICE_API_KEY` and `LLM_DEFAULT_PROVIDER`. After that the database is the source of truth and these are ignored; edit providers in the UI. Set `AGENT_RUNS_ENABLED=true` to enable Copilot agent runs.

## Key service (optional)

Use it when several installs share one OpenRouter key and you want to rotate it centrally; for one install, paste the key in the provider instead.

1. Enable the profile: `scripts/setup.sh --profiles keyservice` (generates `KEY_SERVICE_API_KEY` and `KEYSERVICE_ENCRYPTION_KEY`).
2. Store the key via stdin so it stays out of shell history:
   ```bash
   printf '%s' "$NEW_KEY" | docker compose run --rm -T keyservice node cli.js set-key openrouter -
   ```
3. In `/admin/llm-providers`, edit the OpenRouter provider: key service URL `http://keyservice:3001`, token = `KEY_SERVICE_API_KEY` from `.env`.

The key service is used only through an OpenRouter provider's key service URL. Consumers cache the key for 5 minutes. Rotate by repeating step 2.
