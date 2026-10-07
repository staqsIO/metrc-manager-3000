# METRC keys

METRC uses two keys per request:

- **Vendor (integrator) key**: identifies the software. You obtain it from METRC for your state. It can live in `.env` (`METRC_VENDOR_API_KEY`, `METRC_VENDOR_API_KEY_CO`) or be stored per facility.
- **User key**: identifies the licensed operator's user and is issued in the operator's METRC account. It is entered per facility on the Facilities page (sidebar, `/facilities`, **Add Facility**), and stored encrypted with `METRC_ENCRYPTION_KEY`. `METRC_USER_API_KEY` in `.env` is only read by the optional MCP service.

## Sandbox vs production

Start in the sandbox (`METRC_API_URL=https://sandbox-api-co.metrc.com`, the default for the MCP service). Sandbox license numbers look like `SF-SBX-CO-1-8002`. Production uses your real license numbers and your state's production API. Check METRC's public integrator pages for how to request vendor and sandbox access for your state.

## Rules

- `METRC_ENCRYPTION_KEY` and `METRC_ENCRYPTION_SALT` must never change after first use; otherwise stored facility keys cannot be decrypted. Back up `.env`.
- Never commit keys to git or paste them into issues. `.env` is git-ignored.
- Rotate a leaked user key in METRC, then re-enter it on the Facilities page (`/facilities`).
