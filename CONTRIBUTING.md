# Contributing

Thanks for helping. Please follow the [Contributor Covenant 2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/) in all project spaces.

## How the repositories fit together

This repo holds the Docker Compose stack, setup scripts and documentation. The
code lives in sibling repositories checked out next to it (setup.sh clones
them):

- [metrc-formul8-os-platform](https://github.com/staqsIO/metrc-formul8-os-platform): web app, sync jobs
- [metrc-formul8-os-client](https://github.com/staqsIO/metrc-formul8-os-client): METRC API client
- [metrc-formul8-os-mcp](https://github.com/staqsIO/metrc-formul8-os-mcp): MCP server
- [metrc-formul8-os-keyservice](https://github.com/staqsIO/metrc-formul8-os-keyservice): OpenRouter key service

## Local development

Use Node 22 LTS for the sibling repositories. Each README has its own setup
steps: [platform](https://github.com/staqsIO/metrc-formul8-os-platform#develop-locally),
[client](https://github.com/staqsIO/metrc-formul8-os-client#development),
[mcp](https://github.com/staqsIO/metrc-formul8-os-mcp),
[keyservice](https://github.com/staqsIO/metrc-formul8-os-keyservice#development).

## Tests

In this repo:

```bash
for t in scripts/tests/*.test.sh; do bash "$t"; done
```

Run each sibling's own test command (see its README).

## Pull request checklist

- [ ] Tests pass and new behavior has tests
- [ ] `scripts/scrub-check.sh` passes on the files you changed (copy `scripts/scrub-banned.example.txt` to `scripts/scrub-banned.local.txt` first)
- [ ] No secrets, keys, customer data or real license numbers in code, docs or fixtures
- [ ] `.env.example` and `docs/configuration.md` updated together when you add a variable
