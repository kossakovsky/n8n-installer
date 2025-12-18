# Traefik Migration Notes

This folder captures analysis and planning for adding a selectable reverse-proxy layer (Caddy **or** Traefik) with support for both public HTTPS (Let’s Encrypt) and local/private deployments (wildcard cert + local CA). No runtime code has been changed yet; everything here is documentation and scaffolding to guide the implementation. Treat this directory as the “spec” you hand to a junior developer.

Contents:

- `migration-plan.md` — phased strategy and user/TLS flows
- `file-change-map.md` — per-file change requirements across scripts/config/docs
- `service-routing-map.md` — service-by-service routing/auth needs to mirror the current Caddyfile
- `sample-scripts/` — scaffolding for future prompts/config generation (not wired into the installer yet)

Goals:

- Allow the installer to offer **proxy choice** (Caddy or Traefik) without breaking existing public-Caddy defaults.
- Support **TLS mode selection**: public ACME/Let’s Encrypt vs. local CA + wildcard certs for homelab domains (e.g., `*.homelab.lan`), including host CA install guidance.
- Keep the service matrix, hostnames, and auth protections intact while making proxy and TLS paths configurable.

## How To Use This Folder

1. **Start with `migration-plan.md`.** It includes the decisions already made (env variable names, TLS tooling expectations, validation steps) and prescribes the order in which to modify files.
2. **Consult `file-change-map.md` while editing.** Each subsection lists concrete tasks for a junior developer with examples/snippets (e.g., exact env flags to add, sample Traefik configuration). Check items off as they are implemented.
3. **Use `service-routing-map.md` as your canonical routing table.** Every row explains the hostname, target container, and whether basic auth middleware is required. When generating Traefik config, read from this table rather than copying from the Caddyfile manually.
4. **Leverage the sample scripts.** `sample-scripts/proxy_selection_flow.sh` demonstrates the whiptail prompt flow for proxy/TLS selection, and `sample-scripts/traefik.dynamic.example.yml` shows how to model routers/middlewares/services. Treat them as reference implementations to copy into the main scripts/templates.
5. **Follow the best practices section in `migration-plan.md`.** It documents decisions like “store proxy choice in `REVERSE_PROXY` with default `caddy`” and “use Python `bcrypt` for hash generation”.

Once implementation starts, keep this documentation updated so future contributors understand the rationale behind each change.
