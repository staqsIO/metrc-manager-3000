# Operations

## Update

```bash
git pull --ff-only && scripts/setup.sh --update
```

Run it from the root repo folder (`metrc-formul8-os/metrc-formul8-os`). `setup.sh` rebuilds and restarts the stack itself, so no separate `docker compose up` is needed. `--update` also pulls the root repo and the sibling repositories that are clean git checkouts (it skips any with local changes) and never overwrites existing secrets. Migrations run automatically on start.

## Backup and restore

Back up **`.env`** too: it holds the encryption keys, and without them stored METRC keys are unrecoverable.

```bash
docker compose exec -T postgres pg_dump -U metrc -Fc metrc > backup-$(date +%F).dump

# restore: stop writers first
docker compose stop web cron
docker compose exec -T postgres pg_restore -U metrc -d metrc --clean < backup.dump
docker compose start web cron
```

The key service uses a separate `keyservice` database on the same Postgres; dump it with `-Fc keyservice` if you use that profile.

## Reset an admin password

Run `create-admin` again:

```bash
docker compose run --rm web create-admin --email you@example.com
```

Enter the password at the prompt (twice) or provide `ADMIN_PASSWORD` in the environment; avoid `--password`, which is visible in the process list.

## Reverse proxy and TLS

The app has no built-in rate limiting. Publish it only through a reverse proxy that terminates TLS and rate-limits `/api/auth/*`, and set `APP_URL` to the public https URL. Compose publishes the web port on all interfaces by default, which would let clients bypass the proxy and its rate limit. Set `BIND_ADDRESS=127.0.0.1` in `.env` (then `docker compose up -d`) when the proxy runs on the same host, or firewall the port. Caddy (needs the third-party caddy-ratelimit plugin):

```caddyfile
{
	order rate_limit before reverse_proxy
}

metrc.example.com {
	@auth path /api/auth/*
	rate_limit @auth {
		zone auth {
			key {remote_host}
			events 10
			window 1m
		}
	}
	reverse_proxy localhost:3000
}
```

nginx:

```nginx
limit_req_zone $binary_remote_addr zone=auth:10m rate=10r/m;
server {
  listen 443 ssl;
  server_name metrc.example.com;
  ssl_certificate     /etc/letsencrypt/live/metrc.example.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/metrc.example.com/privkey.pem;
  location /api/auth/ { limit_req zone=auth burst=10 nodelay; proxy_pass http://127.0.0.1:3000; proxy_set_header Host $host; proxy_set_header X-Forwarded-Proto $scheme; }
  location / { proxy_pass http://127.0.0.1:3000; proxy_set_header Host $host; proxy_set_header X-Forwarded-Proto $scheme; }
}
```

Run the stack with `docker compose`; do not start the images with `docker run --env-file`, which skips the compose wiring (database URL, networks, migrations).

## Branding

`BRAND_NAME` and `BRAND_LOGO_URL` are build-time settings. After changing them run `docker compose up -d --build`. `EMAIL_LOGO_URL` is optional.

## Troubleshooting

- **Port in use**: set `PORT` in `.env` (host port) and `docker compose up -d`; update `APP_URL` to match.
- **web unhealthy or not starting**: `docker compose logs migrate web`.
- **Ollama unreachable**: check the provider base URL (`http://ollama:11434` for the profile, `http://host.docker.internal:11434` plus `extra_hosts` for host Ollama, which must run with `OLLAMA_HOST=0.0.0.0` on the host so containers can reach it, with port 11434 firewalled from the outside), and that the model is pulled and supports tool calling.
- **`POSTGRES_PASSWORD` changed after first start**: Postgres keeps the original password. Revert the value in `.env`, or reset the database by removing the volume (`docker compose down -v`, which deletes all data).
- **Compose complains about version or missing variable**: Docker Compose 2.24+ is required; run `scripts/setup.sh` to generate `.env`.
- **Emergency stop of platform features**: set `METRC_PLATFORM_ENABLED=false` and `docker compose up -d`.
