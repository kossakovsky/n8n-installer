# File Change Map (Planned)

Each section below specifies *what* must change, *how* to change it, and (when useful) provides sample snippets that junior developers can copy. Follow the implementation order at the bottom.

## Compose & Proxy Config

- `docker-compose.yml`
  - Introduce mutually exclusive proxy profiles:
    - `proxy-caddy`: wraps the existing `caddy` service (no public ports unless this profile is active).
    - `proxy-traefik`: new `traefik` service plus a lightweight `welcome-web` static file server.
  - Base Traefik service definition:

    ```yaml
    traefik:
      profiles: ["proxy-traefik"]
      image: traefik:v3.1
      command:
        - "--providers.docker=true"
        - "--providers.docker.exposedbydefault=false"
        - "--providers.file.filename=/etc/traefik/traefik.dynamic.yml"
        - "--entrypoints.web.address=:80"
        - "--entrypoints.websecure.address=:443"
        - "--entrypoints.bolt.address=:7687"
        - "--certificatesresolvers.acme.email=${ACME_EMAIL}"
        - "--certificatesresolvers.acme.storage=/acme/acme.json"
        - "--certificatesresolvers.acme.httpchallenge.entrypoint=web"
      ports:
        - "80:80"
        - "443:443"
        - "7687:7687"
      volumes:
        - ./traefik/traefik.yml:/etc/traefik/traefik.yml:ro
        - ./traefik/traefik.dynamic.yml:/etc/traefik/traefik.dynamic.yml:ro
        - traefik-acme:/acme
        - /var/run/docker.sock:/var/run/docker.sock:ro
      environment:
        - TRAEFIK_CERT_RESOLVER=${TRAEFIK_CERT_RESOLVER:-acme}
    ```

  - Add `welcome-web` container (nginx or Caddy file-server) under `profiles: ["proxy-traefik"]` mounting `./welcome`.
  - Keep Caddy service identical but decorated with `profiles: ["proxy-caddy"]`. Only one proxy profile should appear in `COMPOSE_PROFILES`.
  - Gate volumes:
    - `caddy-config`, `caddy-data` remain but only used when `proxy-caddy` active.
    - Add `traefik-acme`, `traefik-config` (bind-mount to `./traefik` folder).
  - Ensure no other service publishes host ports; all ingress goes through the active proxy.
- `Caddyfile`
  - Convert to a template emitted by `scripts/03_generate_secrets.sh` (copy existing content into `templates/Caddyfile.tpl` and inject hostnames). Still needed for the Caddy path.
- Traefik configuration (new files under `./traefik/`)
  - `traefik.yml`: static settings (entrypoints, providers, access logs). Example provided in `sample-scripts/traefik.dynamic.example.yml` (top comments explain usage).
  - `traefik.dynamic.yml`: generated from `service-routing-map.md`. Break routers/middlewares/services into logical groups (auth/no-auth, TCP vs HTTP). Support TLS passthrough for Neo4j Bolt as shown in the sample.
- Static welcome server
  - Example:

    ```yaml
    welcome-web:
      profiles: ["proxy-traefik"]
      image: nginx:alpine
      volumes:
        - ./welcome:/usr/share/nginx/html:ro
      healthcheck:
        test: ["CMD", "wget", "-qO-", "http://localhost"]
    ```

## Environment & Secrets

- `.env.example`
  - New keys (with defaults/examples):

    ```
    REVERSE_PROXY=caddy
    TLS_MODE=public
    ACME_EMAIL=user@example.com
    WILDCARD_DOMAIN=*.yourdomain.com
    LOCAL_CA_CERT=certs/local-ca.pem
    LOCAL_CA_KEY=certs/local-ca-key.pem
    TRAEFIK_ACME_STORAGE=traefik/acme.json
    TRAEFIK_CERT_RESOLVER=acme
    ```

  - Document local-domain expectations (allow `.lan`, `.home`, etc.).
- `scripts/03_generate_secrets.sh`
  - Remove Caddy apt install/uninstall block.
  - Embed proxy/TLS prompt flow (see `sample-scripts/proxy_selection_flow.sh`).
  - When TLS mode is `local`, run helper function:

    ```bash
    ensure_local_ca() {
      mkdir -p "$(dirname "$LOCAL_CA_CERT")"
      if command -v mkcert >/dev/null; then
        mkcert -install
        mkcert -key-file "$LOCAL_CA_KEY" -cert-file "$LOCAL_CA_CERT" "$WILDCARD_DOMAIN"
      else
        openssl req -x509 -nodes -days 3650 \
          -newkey rsa:4096 \
          -keyout "$LOCAL_CA_KEY" \
          -out "$LOCAL_CA_CERT" \
          -subj "/CN=${WILDCARD_DOMAIN}"
      fi
    }
    ```

  - Write generated proxy configs into `./traefik/` or project root depending on selection.
- `scripts/utils.sh`
  - Replace `generate_bcrypt_hash` with Python helper (documented in `migration-plan.md`).
  - Add convenience functions: `current_proxy`, `current_tls_mode`, `require_proxy_config`.

## Install/Update Orchestration

- `scripts/install.sh` / `scripts/apply_update.sh`
  - After secrets generation, call new helper to render config:

    ```bash
    generate_proxy_configs "$REVERSE_PROXY"
    ```

  - Append `proxy-caddy` or `proxy-traefik` to `COMPOSE_PROFILES` automatically.
- `scripts/06_run_services.sh`
  - Pre-flight:

    ```bash
    if [[ "$REVERSE_PROXY" == "traefik" ]]; then
      require_file "$PROJECT_ROOT/traefik/traefik.yml" "Missing Traefik static config"
      require_file "$PROJECT_ROOT/traefik/traefik.dynamic.yml" "Missing Traefik dynamic config"
    else
      require_file "$PROJECT_ROOT/Caddyfile"
    fi
    ```

  - Run `caddy validate` or `traefik check --configfile traefik.yml` before starting services; abort on failure.
- `start_services.py`
  - Expand compose invocation:

    ```python
    proxy_profile = "proxy-traefik" if env_values.get("REVERSE_PROXY") == "traefik" else "proxy-caddy"
    cmd = ["docker", "compose", "-p", "localai", "--profile", proxy_profile, "-f", "docker-compose.yml"]
    ```

## Health/Diagnostics

- `scripts/doctor.sh`
  - Add branch:

    ```bash
    if [[ "$REVERSE_PROXY" == "traefik" ]]; then
      check_service "traefik" "80"
      docker exec traefik traefik check --configfile /etc/traefik/traefik.yml >/dev/null && count_ok "Traefik config valid"
    else
      check_service "caddy" "80"
      docker exec caddy caddy validate --config /etc/caddy/Caddyfile >/dev/null && count_ok "Caddyfile valid"
    fi
    ```

  - When `TLS_MODE=local`, print a warning reminding user to trust the local CA.
- `scripts/update_preview.sh`
  - Only inspect the image belonging to the selected proxy. For the unused proxy, print “skipped (profile disabled)”.

## Reporting & Generated Content

- `scripts/generate_welcome_page.sh` & `scripts/07_final_report.sh`
  - Determine scheme:

    ```bash
    BASE_SCHEME=$([[ "$TLS_MODE" == "public" || "$TLS_MODE" == "local" ]] && echo "https" || echo "http")
    ```

  - Include new metadata in the welcome JSON:

    ```json
    "proxy": "${REVERSE_PROXY}",
    "tls_mode": "${TLS_MODE}",
    "certificate_hint": "Local CA – install ${LOCAL_CA_CERT}" // only when TLS_MODE=local
    ```

- `welcome/` assets
  - Mention both proxy options and instructions to import local CA cert (docs section / modal).

## Documentation

- `README.md`, `CLAUDE.md`
  - Update installation steps to mention the proxy/TLS prompts, show sample `.env` fragment, explain local CA trust flow.
- `cloudflare-instructions.md`
  - Clarify that whether using Caddy or Traefik, Cloudflare Tunnel still bypasses proxy-level auth; provide Traefik-specific router examples for Zero-Trust integrations.

## Implementation Order Checklist

1. **Environment layer**: update `.env.example`, `03_generate_secrets.sh`, and `utils.sh` so proxy/TLS data is captured (use `sample-scripts/proxy_selection_flow.sh` as your reference).
2. **Hashing + CA helpers**: replace Caddy hashing with Python bcrypt, add local CA generator.
3. **Compose changes**: add Traefik service, welcome-web container, new volumes, and profiles. Verify with `docker compose config`.
4. **Config generation**: implement template rendering (`traefik.yml`, `traefik.dynamic.yml`, templated `Caddyfile`). Leverage `service-routing-map.md` for all hostnames/auth requirements.
5. **Orchestration scripts**: ensure install/update/start routines pick the right proxy profile and validate configs.
6. **Diagnostics & docs**: update doctor/update-preview/reporting/readme/cloudflare instructions.
7. **Testing**: follow `migration-plan.md` checklist (public + local TLS, both proxies) before submitting PR.
