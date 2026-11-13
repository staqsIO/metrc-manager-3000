# METRC Manager 3000

Open-source, self-hosted METRC compliance and inventory platform by Staqs, Waev Tech and UMB Advisors (formerly Metrc-Formul8-OS):
dashboards for packages, plants, harvests, transfers, lab tests and sales;
compliance rules and audit readiness; analytics; and an AI Copilot that runs
on OpenRouter or a local Ollama model.

## Quickstart

Requirements: Docker with Compose v2.24 or newer, git, curl, openssl, 4 GB RAM (16 GB+ to run Ollama models locally).

```bash
curl -fsSL https://raw.githubusercontent.com/staqsIO/metrc-manager-3000/main/scripts/install.sh | bash
```

The installer creates `./metrc-manager-3000/metrc-manager-3000`; run later `docker compose` commands from that folder. On a remote server you must set `APP_URL` to the public URL (setup prompts for it; non-interactive: `APP_URL=https://your.domain scripts/setup.sh --non-interactive`), otherwise sign-in redirects to localhost.

The installer clones over HTTPS; pass `--ssh` (`... | bash -s -- --ssh`, or `scripts/install.sh --ssh`) to clone over SSH instead. Or, with SSH access to GitHub:

```bash
mkdir metrc-manager-3000 && cd metrc-manager-3000
git clone git@github.com:staqsIO/metrc-manager-3000.git
cd metrc-manager-3000 && scripts/setup.sh
```

The script clones the other repositories next to this one, writes `.env` with
generated secrets, runs `docker compose up -d --build`, and creates your super
admin account (it prompts for the password twice). Open http://localhost:3000
and sign in.

`scripts/setup.sh` flags: `--non-interactive`, `--update`, `--https`,
`--profiles mcp,ollama`, `--no-start`. For unattended installs set
`ADMIN_EMAIL` and `ADMIN_PASSWORD` in the environment (never pass the password
as an argument; it would show in the process list). To create an admin later:

```bash
docker compose run --rm web create-admin --email you@example.com
```

There is no public sign-up unless you set `OPEN_SIGNUP=true`.

Afterwards the stack is plain Docker Compose (always use `docker compose`, not `docker run --env-file`; the services depend on each other and on compose.yml wiring):

```bash
docker compose up -d        # start (optional services come from COMPOSE_PROFILES in .env)
docker compose logs -f web  # logs
docker compose down         # stop (data stays in the pgdata volume)
```

### Setting up with a coding agent

Copy this prompt into Claude Code, Cursor, or another coding agent opened in an empty folder:

> Install METRC Manager 3000 here. Run
> `curl -fsSL https://raw.githubusercontent.com/staqsIO/metrc-manager-3000/main/scripts/install.sh | bash -s -- --non-interactive`
> and show me its output. Never print or echo secret values from `.env` or from
> my answers; write them to `.env` without displaying them, and do not edit the
> generated secrets. Then ask me, one at a time, for the optional values I want
> to set: public URL (`APP_URL`), OpenRouter API key or Ollama, METRC vendor
> key, Google sign-in. Write them to `metrc-manager-3000/metrc-manager-3000/.env`
> and run `docker compose up -d` in that folder. For Ollama, instead run
> `scripts/setup.sh --non-interactive --profiles ollama` from
> `metrc-manager-3000/metrc-manager-3000`. The first build can take about 10-15
> minutes: run long commands in the background or with a long timeout, and
> re-run if interrupted (setup is idempotent). Then STOP and tell me to run,
> in my own terminal from `metrc-manager-3000/metrc-manager-3000`:
> `docker compose run --rm web create-admin --email you@example.com`
> (it prompts me for the password twice). Do not run create-admin yourself:
> your shell has no TTY.

The script does the installation; the agent only collects your answers. A `--non-interactive` install skips admin creation unless `ADMIN_EMAIL` and `ADMIN_PASSWORD` are set in the environment, which is why you create the admin yourself in a terminal.

## What's inside

| Repository | What it is |
|---|---|
| [metrc-manager-3000](https://github.com/staqsIO/metrc-manager-3000) | This repo: compose stack, setup scripts, docs |
| [metrc-manager-3000-platform](https://github.com/staqsIO/metrc-manager-3000-platform) | Next.js web app and sync jobs |
| [metrc-manager-3000-client](https://github.com/staqsIO/metrc-manager-3000-client) | TypeScript METRC API client |
| [metrc-manager-3000-mcp](https://github.com/staqsIO/metrc-manager-3000-mcp) | Optional MCP server exposing METRC tools |
| [metrc-manager-3000-keyservice](https://github.com/staqsIO/metrc-manager-3000-keyservice) | Optional central OpenRouter key service |

## Optional services

| Profile | Adds | Enable |
|---|---|---|
| `mcp` | METRC MCP server | `scripts/setup.sh --profiles mcp` |
| `ollama` | Local LLM runtime (model pulled by setup) | `scripts/setup.sh --profiles ollama` |
| `cache` | Redis cache | `scripts/setup.sh --profiles cache` |
| `keyservice` | Shared OpenRouter key service | `scripts/setup.sh --profiles keyservice` |

Combine with commas (`--profiles mcp,ollama`), or edit `COMPOSE_PROFILES` in `.env` and run `docker compose up -d`.

## First steps after install

1. Sign in with the super admin account.
2. Open Super Admin, LLM Providers (`/admin/llm-providers`) and add OpenRouter or Ollama. See [docs/ai-copilot.md](docs/ai-copilot.md).
3. Open **Facilities** in the sidebar (`/facilities`), choose **Add Facility**, and enter the facility with its METRC user key. See [docs/metrc-keys.md](docs/metrc-keys.md).
4. The first sync runs on the cron schedule; trigger one now with `docker compose run --rm web sync --facility=<license>`.

Before exposing the stack to the internet, put it behind a TLS reverse proxy
that rate-limits `/api/auth/*`; the app has no built-in rate limiting
(example in [docs/operations.md](docs/operations.md)). Back up `.env`: the
encryption keys in it cannot be recovered.

## Documentation

- [Configuration reference](docs/configuration.md)
- [METRC keys](docs/metrc-keys.md)
- [AI Copilot](docs/ai-copilot.md)
- [Operations: updates, backups, reverse proxy, troubleshooting](docs/operations.md)
- [Architecture](docs/architecture.md)
- [Security policy](SECURITY.md)
- [Contributing](CONTRIBUTING.md)

## Contributors

METRC Manager 3000 is created by three organizations:

<table>
<tr>
  <td align="center"><a href="https://github.com/staqsIO"><img src="https://github.com/staqsIO.png" width="64" alt="Staqs"/></a><br/><a href="https://github.com/staqsIO"><b>Staqs</b></a><br/><a href="https://staqs.io">staqs.io</a></td>
  <td align="center"><a href="https://github.com/waevtech"><img src="https://github.com/waevtech.png" width="64" alt="Waev Tech"/></a><br/><a href="https://github.com/waevtech"><b>Waev Tech</b></a><br/><a href="https://waevtech.com/">waevtech.com</a></td>
  <td align="center"><a href="https://github.com/UMB-Advisors"><img src="https://github.com/UMB-Advisors.png" width="64" alt="UMB Advisors"/></a><br/><a href="https://github.com/UMB-Advisors"><b>UMB Advisors</b></a><br/><a href="https://umbadvisors.com">umbadvisors.com</a></td>
</tr>
</table>

See [AUTHORS](AUTHORS) and [CITATION.cff](CITATION.cff).

## License

MIT. See [LICENSE](LICENSE).
