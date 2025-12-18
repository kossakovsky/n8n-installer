# Traefik Migration – Scrum Plan

This document translates the migration blueprint into epics, user stories, and task checklists. Work through the epics **in order**; every checkbox is a definition-of-done gate. Reference the supporting docs listed beside each task:

- `migration-plan.md` – strategy, decisions, best practices.
- `file-change-map.md` – implementation details/snippets.
- `service-routing-map.md` – canonical routing/auth data.
- `sample-scripts/` – reference implementations (prompts, Traefik config).

---

## Epic 1 – Environment & Secrets Foundation
Outcome: Installer captures proxy/TLS choices, generates hashes locally, and scaffolds TLS assets.

### Story 1.1 – Add Proxy/TLS Env Inputs

- [ ] Update `.env.example` with the keys listed in `file-change-map.md` (REVERSE_PROXY, TLS_MODE, etc.).
- [ ] Extend `scripts/03_generate_secrets.sh` prompts using `sample-scripts/proxy_selection_flow.sh` flow.
- [ ] Ensure values persist/reload on rerun (reuse `generated_values` logic).

### Story 1.2 – Implement Local CA + Hash Helpers

- [ ] Swap `generate_bcrypt_hash` to the Python bcrypt helper described in `migration-plan.md`.
- [ ] Remove the Caddy apt install/uninstall block from `03_generate_secrets.sh`.
- [ ] Add `ensure_local_ca` helper (mkcert/openssl fallback) per `file-change-map.md` snippet.
- [ ] Document host trust instructions (Ubuntu/macOS/Windows) in script output or README.

### Story 1.3 – Render Proxy Config Templates

- [ ] Create template locations (`./traefik/traefik.yml`, `./traefik/traefik.dynamic.yml`, `templates/Caddyfile.tpl`).
- [ ] Wire `03_generate_secrets.sh` to render the appropriate config(s) based on `REVERSE_PROXY`.
- [ ] Validate generated files exist and log paths for the user.

---

## Epic 2 – Compose & Proxy Services
Outcome: docker-compose supports mutually exclusive proxy profiles with all required containers/volumes.

### Story 2.1 – Add Traefik & Welcome Services

- [ ] Introduce `proxy-traefik` profile with the Traefik definition from `file-change-map.md`.
- [ ] Add `welcome-web` container mounting `./welcome` (profile `proxy-traefik`).
- [ ] Create new volumes (`traefik-acme`, `traefik-config`) and mount them as specified.

### Story 2.2 – Gate Existing Caddy Service

- [ ] Apply `profiles: ["proxy-caddy"]` to the Caddy service.
- [ ] Ensure only the active proxy profile publishes ports 80/443/7687.
- [ ] Remove any other host port exposes to prevent bypassing the selected proxy.

### Story 2.3 – Compose Validation

- [ ] Run `docker compose -f docker-compose.yml config` for both profiles; fix lint errors.
- [ ] Document commands/results in PR notes for QA reference.

---

## Epic 3 – Service Routing Data Model
Outcome: Routing/auth data is structured and used to generate both proxy configs.

### Story 3.1 – Convert Routing Table to Machine-Readable Form

- [ ] Extract `service-routing-map.md` rows into `traefik/routing-map.yml` (YAML as per example).
- [ ] Add parser in `scripts/03_generate_secrets.sh` or helper module to load the YAML.

### Story 3.2 – Generate Traefik Dynamic Config

- [ ] Iterate routing map to create routers/services/middlewares (use `sample-scripts/traefik.dynamic.example.yml` as reference).
- [ ] Ensure all basic-auth services consume `${XXX_USERNAME}`/`${XXX_PASSWORD_HASH}` variables.
- [ ] Add TCP router for Neo4j Bolt with TLS passthrough.

### Story 3.3 – Generate Caddyfile from Same Data

- [ ] Render each hostname block from the routing map (preserve special cases like SearXNG headers).
- [ ] Confirm parity with existing Caddyfile output via diff before deleting static version.

---

## Epic 4 – Orchestration & Automation Updates
Outcome: install/update/start scripts honor proxy selection, generate configs, and validate proxy state.

### Story 4.1 – Compose Profile Selection

- [ ] Modify `scripts/install.sh` and `scripts/apply_update.sh` to append `proxy-caddy` or `proxy-traefik` to `COMPOSE_PROFILES`.
- [ ] Ensure profile updates remain idempotent (no duplicate entries).

### Story 4.2 – Service Launch Adjustments

- [ ] Update `scripts/06_run_services.sh` to require the correct config files (see snippet in `file-change-map.md`) before running start scripts.
- [ ] Integrate pre-flight validation: `caddy validate` or `traefik check --configfile /etc/traefik/traefik.yml`.
- [ ] Update `start_services.py` to pass the proper `--profile` argument when invoking `docker compose`.

### Story 4.3 – Doctor & Update Preview Enhancements

- [ ] Add proxy-aware health checks in `scripts/doctor.sh` (service running + config validation).
- [ ] Modify `scripts/update_preview.sh` to check only the active proxy image.
- [ ] When `TLS_MODE=local`, doctor should emit a reminder to trust the local CA.

---

## Epic 5 – Reporting, UX, and Documentation
Outcome: User-facing artifacts reflect the new proxy/TLS capabilities and guide installation.

### Story 5.1 – Welcome Page & Final Report

- [ ] Adapt `scripts/generate_welcome_page.sh` to record `proxy`, `tls_mode`, and `certificate_hint`.
- [ ] Update `scripts/07_final_report.sh` to show scheme derived from `TLS_MODE` and highlight local CA trust steps when applicable.

### Story 5.2 – README / CLAUDE / Cloudflare Docs

- [ ] Update install instructions (new prompts, `.env` example).
- [ ] Expand troubleshooting/common issues for Traefik/local CA.
- [ ] Clarify Cloudflare Tunnel behavior for each proxy option.

### Story 5.3 – Testing & QA Checklist

- [ ] Execute the matrix from `migration-plan.md` (Caddy+public, Traefik+public, Traefik+local).
- [ ] Verify HTTPS certificates (issuer, CN) for each scenario.
- [ ] Record command outputs (curl health endpoints, traefik/caddy validation) for handoff to reviewers.

---

## Epic 6 – Final Review & Cleanup
Outcome: Repository ready for PR with documentation and artifacts aligned.

- [ ] Ensure generated files (`traefik/*.yml`, templated `Caddyfile`) are committed or added to `.gitignore` per decision.
- [ ] Remove obsolete instructions referencing mandatory Caddy dependency.
- [ ] Update `TraefikMigration/README.md` → “Implementation in progress” status if applicable.
- [ ] Submit PR with links to this checklist and completed sections checked off.
