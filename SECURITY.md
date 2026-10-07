# Security policy

## Reporting a vulnerability

Please report vulnerabilities privately using GitHub private vulnerability
reporting: open the Security tab of this repository (or the affected sibling
repository) and choose "Report a vulnerability". Do not open public issues for
security problems. We will acknowledge reports promptly and keep you updated
until a fix is released.

## Supported versions

Only the latest `main` of each repository is supported.

## Handling secrets

- `.env` holds generated secrets and API keys. It is created with mode 600 and is git-ignored; never commit it.
- `METRC_ENCRYPTION_KEY`, `METRC_ENCRYPTION_SALT` and `KEYSERVICE_ENCRYPTION_KEY` must never change after first use, or stored keys become unreadable. Back up `.env`.
- Pass admin passwords by prompt or the `ADMIN_PASSWORD` environment variable, not as command-line arguments.
- The app has no built-in rate limiting. Run it behind a TLS reverse proxy that rate-limits `/api/auth/*` (see docs/operations.md).
- OpenRouter prompts are anonymized before they leave your install; Ollama keeps data local.
- `METRC_PLATFORM_ENABLED=false` disables the METRC platform features if you need to shut them off quickly.
