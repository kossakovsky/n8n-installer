# Migration Strategy (Caddy ↔ Traefik + Public/Local TLS)

## Desired End State

- Users can pick **Caddy** or **Traefik** during install/update (default to current Caddy path for backwards compatibility).
- Users can pick **TLS mode**:
  - **Public**: ACME/Let’s Encrypt (HTTP-01/DNS-01) with user email + domain.
  - **Local**: wildcard cert for e.g. `*.homelab.lan` with a generated local CA, plus helper to install the root CA on the host (and instructions for browsers/OS).
- All services retain current hostnames, basic-auth protections, and entrypoints; “welcome” page still available behind auth.
- Proxy-specific assets (Caddyfile vs. Traefik static/dynamic config) are generated/validated by scripts instead of being hand-edited.

## Phased Approach

1. **Inventory & Abstractions**
   - Add proxy/TLS selection to env generation (script-driven flags: `REVERSE_PROXY`, `TLS_MODE`, `TLS_PROVIDER`, `USER_DOMAIN_NAME`, `WILDCARD_DOMAIN`, `ACME_EMAIL`, `LOCAL_CA_CERT`, `LOCAL_CA_KEY`).
   - Introduce a proxy-agnostic data model for routes (hostname → target service/port + auth requirement) to drive template generation. The table in `service-routing-map.md` is the starting point—load it (YAML/JSON) and render both Caddy and Traefik configs from it.
2. **Traefik Scaffolding**
   - Add Traefik service definition (compose profile or env toggle) with Docker provider, file provider (mount `traefik.dynamic.yml`), ACME storage volume, entrypoints (80/443), and optional TCP router for Neo4j Bolt. Sample static/dynamic files are in `sample-scripts/`.
   - Add small static-file container for the welcome site (Traefik cannot serve files directly). Use `nginx:alpine` mounting `./welcome` as shown in `file-change-map.md`.
   - Provide dynamic config template for routers/middlewares based on the routing map. Include middleware definitions for each group of services (e.g., `auth-prometheus`, `auth-comfyui`) and HSTS/compression headers reused via chains.
3. **Script Updates**
   - Replace `caddy hash-password` dependency with a local bcrypt/htpasswd generator (Python `bcrypt` module via `python3 -c "import bcrypt; print(bcrypt.hashpw(...))"` or `htpasswd -B`). Store the helper in `scripts/utils.sh`.
   - Adjust pre-flight checks, health checks, and reports to key off selected proxy/TLS mode (`REVERSE_PROXY=caddy|traefik`, `TLS_MODE=public|local`).
   - Generate either `Caddyfile` or `traefik.dynamic.yml` + `traefik.yml`, and include/exclude the right proxy service in docker-compose. Example prompt flow is in `sample-scripts/proxy_selection_flow.sh`.
4. **Documentation & UX**
   - Update README/CLAUDE/cloudflare docs for dual-proxy support and local-CA flow. Provide copy-pastable instructions for trusting the local CA on Ubuntu/macOS/Windows.
   - Add test matrix covering proxy choice × TLS mode × profile combinations. Include manual validation steps (curl endpoints, check TLS cert issuer, etc.).
5. **Validation**
   - Dry-run generation of configs, lint proxy configs, and ensure start/doctor scripts validate the active proxy (caddy `validate` vs. `traefik check --configfile traefik.yml`). Include `docker compose config` checks before bring-up.

## TLS/User Input Flows

- Prompt sequence:
  1. Proxy choice (Caddy | Traefik).
  2. TLS mode (Public ACME | Local CA/wildcard).
  3. Domain input (primary domain; allow non-public TLDs like `.lan`).
  4. If Public: email + optional DNS-01 provider selection (at least HTTP-01 default).
  5. If Local: wildcard CN (default `*.${USER_DOMAIN_NAME}`), CA output paths, and consent to install CA on host (scripted if possible; otherwise instructions).
- Persist choices to `.env` (new vars) and reuse on re-run.

## Testing Checklist (future)

- Proxy toggle idempotency (rerun install/update without drift).
- Public ACME issuance (HTTP-01 with open ports) and DNS-01 (for homelab behind NAT if desired).
- Local CA path: generated certs mounted into Traefik; system/browser trust installed; services reachable via HTTPS.
- Auth middlewares applied to all services previously protected by Caddy basic_auth.

## Decisions & Best Practices (hand this to junior devs)

- **Environment variables**
  - `REVERSE_PROXY`: `caddy` (default) or `traefik`.
  - `TLS_MODE`: `public` or `local`.
  - `ACME_EMAIL`: stored even for local mode (used again if user switches back to public).
  - `WILDCARD_DOMAIN`: defaults to `*.${USER_DOMAIN_NAME}`.
  - `LOCAL_CA_CERT`/`LOCAL_CA_KEY`: absolute paths under `./certs/` (gitignored). Scripts must create directory and restrict permissions (`chmod 600`).
  - `TRAEFIK_ACME_STORAGE`: path mounted into Traefik (default `./traefik/acme.json`).
- **Local CA tooling**
  - Use `mkcert` if installed; otherwise fall back to OpenSSL commands (documented in `file-change-map.md`). Always prompt the user before installing a root cert on their machine.
  - Provide command snippets for trusting CA on Ubuntu (`sudo cp rootCA.pem /usr/local/share/ca-certificates && sudo update-ca-certificates`), macOS (`security add-trusted-cert -d -r trustRoot ...`), Windows (`certutil -addstore Root rootCA.pem`).
- **Hashing**
  - Use consistent bcrypt cost (12) for all services. Sample Python one-liner:

    ```bash
    python3 -c 'import bcrypt,sys; print(bcrypt.hashpw(sys.argv[1].encode(), bcrypt.gensalt(rounds=12)).decode())' "$PLAINTEXT"
    ```

- **Template generation**
  - Keep routing data declarative (JSON/YAML) so future proxies can be added. Avoid duplicating hostname lists.
  - Always write generated config to a deterministic path (`./generated/Caddyfile`, `./generated/traefik.dynamic.yml`) and symlink/copy into runtime locations.
- **Profiles & Compose**
  - Use mutually exclusive compose profiles `proxy-caddy` and `proxy-traefik`. Scripts should set `COMPOSE_PROFILES` so that exactly one is active.
  - Add `depends_on`/healthchecks for Traefik similar to Caddy (listen on 80/443 + `bolt` entrypoint).
- **Validation discipline**
  - After config generation, run `caddy validate` or `traefik check`. Fail fast if invalid.
  - When TLS mode is `local`, warn user that browsers may require manual trust even after host install.
