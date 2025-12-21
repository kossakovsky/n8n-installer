# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **n8n-install**, a Docker Compose-based installer that provides a comprehensive self-hosted environment for n8n workflow automation and numerous AI/automation services. The installer includes an interactive wizard, automated secret generation, and integrated HTTPS via Caddy.

### Core Architecture

- **Profile-based service management**: Services are activated via Docker Compose profiles (e.g., `n8n`, `flowise`, `monitoring`). Profiles are stored in the `.env` file's `COMPOSE_PROFILES` variable.
- **No exposed ports**: Services do NOT publish ports directly. All external HTTPS access is routed through Caddy reverse proxy on ports 80/443.
- **Shared secrets**: Core services (Postgres, Redis/Valkey, Caddy) are always included. Other services are optional and selected during installation.
- **Queue-based n8n**: n8n runs in `queue` mode with Redis, Postgres, and dynamically scaled workers (`N8N_WORKER_COUNT`).

### Key Files

- `Makefile`: Common commands (install, update, logs, etc.)
- `docker-compose.yml`: Service definitions with profiles
- `Caddyfile`: Reverse proxy configuration with automatic HTTPS
- `.env`: Generated secrets and configuration (from `.env.example`)
- `scripts/install.sh`: Main installation orchestrator
- `scripts/04_wizard.sh`: Interactive service selection using whiptail
- `scripts/03_generate_secrets.sh`: Secret generation and bcrypt hashing
- `scripts/07_final_report.sh`: Post-install credential summary

## Common Development Commands

### Makefile Commands

```bash
make install           # Full installation
make update            # Update system and services
make update-preview    # Preview available updates (dry-run)
make clean             # Remove unused Docker resources

make logs              # View logs (all services)
make logs s=<service>  # View logs for specific service
make status            # Show container status
make monitor           # Live CPU/memory monitoring
make restarts          # Show restart count per container
make doctor            # Run system diagnostics (DNS, SSL, containers, disk, memory)

make switch-beta       # Switch to develop branch and update
make switch-stable     # Switch to main branch and update
make help              # Show all available commands
```


## Adding a New Service

Follow this workflow when adding a new optional service (refer to `.claude/commands/add-new-service.md` for complete details):

1. **docker-compose.yml**: Add service with `profiles: ["myservice"]`, `restart: unless-stopped`. Do NOT expose ports.
2. **Caddyfile**: Add reverse proxy block using `{$MYSERVICE_HOSTNAME}`. Consider if basic auth is needed.
3. **.env.example**: Add `MYSERVICE_HOSTNAME=myservice.yourdomain.com` and credentials if using basic auth.
4. **scripts/03_generate_secrets.sh**: Generate passwords and bcrypt hashes. Add to `VARS_TO_GENERATE` map.
5. **scripts/04_wizard.sh**: Add service to `base_services_data` array for wizard selection.
6. **scripts/generate_welcome_page.sh**: Add service to `SERVICES_ARRAY` for welcome dashboard.
7. **welcome/app.js**: Add `SERVICE_METADATA` entry with name, description, icon, color, category.
8. **scripts/07_final_report.sh**: Add service URL and credentials output using `is_profile_active "myservice"`.
9. **README.md**: Add one-line description under "What's Included".
10. **CHANGELOG.md**: Add entry under `## [Unreleased]` → `### Added`.

**Always ask users if the new service requires Caddy basic auth protection.**

## Important Service Details

### n8n Configuration (v2.0+)

- n8n runs in `EXECUTIONS_MODE=queue` with Redis as the queue backend
- **OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true**: All executions (including manual tests) run on workers
- **Worker-Runner Sidecar Pattern**: Each worker has its own dedicated task runner
  - Workers and runners are generated dynamically via `scripts/generate_n8n_workers.sh`
  - Configuration stored in `docker-compose.n8n-workers.yml` (auto-generated, gitignored)
  - Runner connects to its worker via `network_mode: "service:n8n-worker-N"` (localhost:5679)
  - Runner image `n8nio/runners` must match n8n version
- **Scaling**: Change `N8N_WORKER_COUNT` in `.env` and run `bash scripts/generate_n8n_workers.sh`
- **Code node libraries**: Configured via `n8n/n8n-task-runners.json` and `n8n/Dockerfile.runner`:
  - JS packages installed via `pnpm add` in Dockerfile.runner
  - Allowlist configured in `n8n-task-runners.json` (`NODE_FUNCTION_ALLOW_EXTERNAL`, `NODE_FUNCTION_ALLOW_BUILTIN`)
  - Default packages: `cheerio`, `axios`, `moment`, `lodash`
- Workflows can access the host filesystem via `/data/shared` (mapped to `./shared`)
- `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` allows Code nodes to access environment variables

### Caddy Reverse Proxy

- Automatically obtains Let's Encrypt certificates when `LETSENCRYPT_EMAIL` is set
- Hostnames are passed via environment variables (e.g., `N8N_HOSTNAME`, `FLOWISE_HOSTNAME`)
- Basic auth uses bcrypt hashes generated by `scripts/03_generate_secrets.sh` via Caddy's hash command
- Never add `ports:` to services in docker-compose.yml; let Caddy handle all external access

### Secret Generation

The `scripts/03_generate_secrets.sh` script:
- Generates random passwords, JWT secrets, API keys, and encryption keys
- Creates bcrypt password hashes using Caddy's `hash-password` command
- Preserves existing user-provided values in `.env`
- Supports different secret types via `VARS_TO_GENERATE` map: `password:32`, `jwt`, `api_key`, `base64:64`, `hex:32`

### Utility Functions (scripts/utils.sh)

Source with: `source "$(dirname "$0")/utils.sh" && init_paths`

Key functions:
- `is_profile_active "myservice"` - Check if profile is enabled
- `read_env_var "VAR_NAME"` / `write_env_var "VAR_NAME" "value"` - .env manipulation
- `load_env` - Source .env file to make variables available
- `update_compose_profiles "profile1,profile2"` - Update COMPOSE_PROFILES in .env
- `gen_password 32` / `gen_hex 64` / `gen_base64 64` - Secret generation
- `generate_bcrypt_hash "password"` - Create Caddy-compatible bcrypt hash (uses Caddy binary)
- `json_escape "string"` - Escape string for JSON output
- `wt_input`, `wt_password`, `wt_yesno`, `wt_msg` - Whiptail dialog wrappers
- `wt_checklist`, `wt_radiolist`, `wt_menu` - Whiptail selection dialogs
- `wt_parse_choices "$result" array_name` - Parse quoted checklist output safely
- `log_info`, `log_success`, `log_warning`, `log_error` - Logging functions
- `log_header`, `log_subheader`, `log_divider`, `log_box` - Formatted output
- `print_ok`, `print_error`, `print_warning`, `print_info` - Doctor output helpers
- `get_real_user` / `get_real_user_home` - Get actual user even under sudo
- `backup_preserved_dirs` / `restore_preserved_dirs` - Directory preservation for git updates

### Service Profiles

Common profiles:
- `n8n`: n8n workflow automation (includes main app, worker, runner, and import services)
- `flowise`: Flowise AI agent builder
- `monitoring`: Prometheus, Grafana, cAdvisor, node-exporter
- `langfuse`: Langfuse observability (includes ClickHouse, MinIO, worker, web)
- `cpu`, `gpu-nvidia`, `gpu-amd`: Ollama hardware profiles (mutually exclusive)
- `cloudflare-tunnel`: Cloudflare Tunnel for zero-trust access (see `cloudflare-instructions.md`)
- `gost`: HTTP/HTTPS proxy for routing AI service outbound traffic
- `python-runner`: Internal Python execution environment (no external access)

## Architecture Patterns

### Healthchecks

Services should define healthchecks for proper dependency management:
```yaml
healthcheck:
  test: ["CMD-SHELL", "wget -qO- http://localhost:8080/health || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 5
```

### Service Dependencies

Use `depends_on` with conditions:
```yaml
depends_on:
  postgres:
    condition: service_healthy
  redis:
    condition: service_healthy
```

### Environment Variable Patterns

- All secrets/passwords end with `_PASSWORD` or `_KEY`
- All hostnames end with `_HOSTNAME`
- Password hashes end with `_PASSWORD_HASH`
- Use `${VAR:-default}` for optional vars with defaults

### Profile Activation Logic

In bash scripts, check if a profile is active:
```bash
if is_profile_active "myservice"; then
  # Service-specific logic
fi
```

### Proxy Configuration (for AI services)

Services making outbound HTTP requests to AI APIs (OpenAI, Anthropic, etc.) should use the shared proxy anchor:
```yaml
x-proxy-env: &proxy-env
  HTTP_PROXY: ${GOST_PROXY_URL:-}
  HTTPS_PROXY: ${GOST_PROXY_URL:-}
  NO_PROXY: ${GOST_NO_PROXY:-}

services:
  myservice:
    environment:
      <<: *proxy-env  # Inherit proxy settings
```

**Important:** Healthchecks must bypass proxy:
```yaml
healthcheck:
  test: ["CMD-SHELL", "http_proxy= https_proxy= HTTP_PROXY= HTTPS_PROXY= wget -qO- http://localhost:8080/health || exit 1"]
```

### Welcome Page Dashboard

The welcome page (`welcome/`) provides a post-install dashboard showing all active services:
- `scripts/generate_welcome_page.sh`: Generates `welcome/services.json` with service URLs, credentials, and metadata
- `welcome/app.js`: Contains `SERVICE_METADATA` object defining display properties (name, description, icon, color, category)
- Categories: `ai`, `database`, `monitoring`, `tools`, `infra`, `automation`
- Always use `json_escape "$VAR"` when building JSON to handle special characters

### Preserved Directories

Directories in `PRESERVE_DIRS` (defined in `scripts/utils.sh`) survive git updates:
- `python-runner/` - User's custom Python code

These are backed up before `git reset --hard` and restored after.

## Common Issues and Solutions

### Service won't start after adding
1. Ensure profile is added to `COMPOSE_PROFILES` in `.env`
2. Check logs: `docker compose -p localai logs <service>`
3. Verify no port conflicts (no services should publish ports)
4. Ensure healthcheck is properly defined if service has dependencies

### Caddy certificate issues
- DNS must be configured before installation (wildcard A record: `*.yourdomain.com`)
- Check Caddy logs for certificate acquisition errors
- Verify `LETSENCRYPT_EMAIL` is set in `.env`

### Password hash generation fails
- Ensure Caddy container is running: `docker compose -p localai up -d caddy`
- Script uses: `docker exec caddy caddy hash-password --plaintext "$password"`

## File Locations

- Shared files accessible by n8n: `./shared` (mounted as `/data/shared` in n8n)
- n8n storage: Docker volume `localai_n8n_storage`
- Service-specific volumes: Defined in `volumes:` section at top of `docker-compose.yml`
- Installation logs: stdout during script execution
- Service logs: `docker compose -p localai logs <service>`

## Testing Changes

### Syntax Validation

```bash
# Docker Compose syntax
docker compose -p localai config --quiet

# Bash script syntax
bash -n scripts/03_generate_secrets.sh
bash -n scripts/04_wizard.sh
bash -n scripts/05_configure_services.sh
bash -n scripts/07_final_report.sh
bash -n scripts/generate_welcome_page.sh
```

### Full Testing

When modifying installer scripts:
1. Test on a clean Ubuntu 24.04 LTS system (minimum 4GB RAM / 2 CPU)
2. Verify all profile combinations work
3. Check that `.env` is properly generated
4. Confirm final report displays correct URLs and credentials
5. Test update script preserves custom configurations
