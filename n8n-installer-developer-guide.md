# n8n-installer Developer Documentation

> 🤖 **AI Context Note**: This document describes a complex Docker-based installation system for AI and automation services. When analyzing issues or making modifications, pay special attention to the sequential dependencies between scripts and the shared environment variable system. The project uses Docker Compose profiles for selective service deployment, which is critical for understanding service interactions.

## 📁 Project Architecture Overview

The n8n-installer project is a sophisticated Docker-based installation framework that orchestrates multiple AI and automation services. It follows a modular, script-based architecture with careful dependency management and state preservation.

## 🔄 Installation Flow Diagram

```
User runs: git clone && cd n8n-installer && sudo bash ./scripts/install.sh
                                    ↓
                         scripts/install.sh (Entry Point)
                                    ↓
                    Checks for nested directories & fixes paths
                                    ↓
                    Validates all required scripts are present
                                    ↓
                    Makes all scripts executable if needed
                                    ↓
         ┌──────────────────────────────────────────────────────┐
         │         Sequential Execution of 6 Scripts            │
         └──────────────────────────────────────────────────────┘
                                    ↓
         01_system_preparation.sh → 02_install_docker.sh → 03_generate_secrets.sh
                                    ↓
         04_wizard.sh → 06_run_services.sh → 07_final_report.sh
                                    ↓
                        Installation Complete
```

> 🤖 **AI Context Note**: The installation MUST follow this exact sequence. Each script depends on the successful completion of the previous one. Breaking this sequence will cause installation failure. When troubleshooting, always verify that each step completed successfully before investigating the failing step.

## 📝 File-by-File Interaction Documentation

### 🚀 **Entry Point: scripts/install.sh**

**Purpose**: Master orchestrator that manages the entire installation process

**Key Functions**:
- **Nested Directory Detection**: Automatically fixes if user accidentally creates nested n8n-installer/n8n-installer structure
- **Script Validation**: Ensures all 6 required installation scripts exist
- **Permission Management**: Makes scripts executable if they aren't already
- **Sequential Execution**: Runs each installation step with error handling

**Interactions**:
1. Sources `utils.sh` for logging functions
2. Executes scripts 01-06 in sequence
3. Exits on any script failure to prevent partial installations

> 🤖 **AI Context Note**: This script contains self-healing logic for common user errors (nested directories, permission issues). When users report installation failures, first check if they're running this script from the correct directory and with sudo privileges. The script will re-execute itself if it detects and fixes a nested directory structure.

---

### 🛠️ **scripts/utils.sh**

**Purpose**: Shared utility functions for consistent logging across all scripts

**Key Functions**:
- `log_info()`: Information messages with timestamps
- `log_success()`: Success confirmations
- `log_error()`: Error reporting
- `log_warning()`: Warning messages
- `log_message()`: Base function that creates bordered messages

**Used By**: Every script in the project sources this file for consistent output formatting

> 🤖 **AI Context Note**: When generating or modifying scripts for this project, ALWAYS source utils.sh at the beginning with `source "$(dirname "$0")/utils.sh"` and use these logging functions instead of plain echo statements. This ensures consistent output formatting and helps with debugging.

---

### 💻 **01_system_preparation.sh**

**Purpose**: Prepares the Ubuntu system with security and dependencies

**Actions**:
1. Updates system packages (`apt update && apt upgrade`)
2. Installs essential tools (git, curl, make, python3, whiptail, etc.)
3. Configures UFW firewall (allows SSH, HTTP, HTTPS)
4. Enables Fail2Ban for brute-force protection
5. Sets up automatic security updates

**Dependencies Created**:
- Python packages: `python3-dotenv`, `python3-yaml` (needed by `start_services.py`)
- `whiptail` (needed by `04_wizard.sh`)
- `openssl` (needed by `03_generate_secrets.sh`)

> 🤖 **AI Context Note**: This script assumes Ubuntu 24.04 LTS. The package names and firewall commands are Ubuntu-specific. Key dependencies: `python3-dotenv` and `python3-yaml` are REQUIRED for start_services.py to function. If these fail to install, the entire system will fail at step 5.

---

### 🐳 **02_install_docker.sh**

**Purpose**: Installs Docker Engine and Docker Compose plugin

**Key Features**:
- **Idempotent**: Checks if Docker already installed
- **Lock Handling**: `run_apt_with_retry()` function handles apt lock conflicts
- **User Management**: Adds the sudo user to docker group for non-root access

**Process**:
1. Checks for existing Docker installation
2. Adds Docker's GPG key and repository
3. Installs docker-ce, docker-compose-plugin
4. Adds user to docker group
5. Verifies installation

> 🤖 **AI Context Note**: The `run_apt_with_retry()` function is critical for handling concurrent apt operations. It uses `fuser` to detect locks and retries up to 10 times with 10-second waits. This is especially important on fresh Ubuntu installations where automatic updates might be running. The script requires Docker Compose v2+ (installed as a plugin, not standalone).

---

### 🔐 **03_generate_secrets.sh**

**Purpose**: Generates secure passwords and creates the `.env` configuration file

**Complex Logic**:
1. **Template Processing**: Reads from `.env.example` template
2. **Secret Generation**: Creates different types of secrets:
   - `password`: 32-character alphanumeric passwords
   - `secret`: Base64-encoded secrets
   - `hex`: Hexadecimal keys
   - `fixed`: Static values
3. **User Prompts**: Collects:
   - Domain name (required)
   - Email address (required)
   - OpenAI API key (optional)
   - n8n workflow import choice
   - Number of n8n workers
4. **Hash Generation**: Uses Caddy to generate bcrypt hashes for basic auth

**Key Variables Generated**:
```bash
VARS_TO_GENERATE=(
    ["FLOWISE_PASSWORD"]="password:32"
    ["N8N_ENCRYPTION_KEY"]="secret:64"
    ["POSTGRES_PASSWORD"]="password:32"
    ["DIFY_SECRET_KEY"]="secret:64"
    # ... 40+ more variables
)
```

**Domain Substitution**: Replaces `yourdomain.com` placeholder with actual domain for all hostname variables

> 🤖 **AI Context Note**: This script has two modes: initial generation and update mode (--update flag). It preserves existing values when updating. The script temporarily installs Caddy to generate bcrypt hashes, then uninstalls it. The domain substitution is CRITICAL - it replaces "yourdomain.com" in all hostname variables. The associative array VARS_TO_GENERATE defines the type and length of each secret. When adding new services, you must add their secrets here.

---

### 🎯 **04_wizard.sh**

**Purpose**: Interactive service selection using whiptail

**Service Categories**:
- **Base Services**: n8n, flowise, dify, monitoring
- **Ollama Variants**: CPU, GPU-NVIDIA, GPU-AMD
- **AI Tools**: open-webui, supabase, langfuse
- **Vector Stores**: qdrant, weaviate, neo4j
- **Support Services**: searxng, letta, portainer

**Process**:
1. Reads current `COMPOSE_PROFILES` from `.env`
2. Displays checkbox menu for service selection
3. Updates `COMPOSE_PROFILES` with selected services
4. Writes back to `.env` file

> 🤖 **AI Context Note**: The wizard modifies ONLY the COMPOSE_PROFILES variable in .env. Service profiles must match exactly with those defined in docker-compose.yml. The wizard handles Ollama variants specially - only one variant (cpu, gpu-nvidia, gpu-amd) can be selected. When adding new services, you must add them to both base_services_data array here AND as a profile in docker-compose.yml.

---

### 🚀 **06_run_services.sh**

**Purpose**: Validates environment and launches services

**Checks Performed**:
1. `.env` file exists
2. `docker-compose.yml` exists
3. `Caddyfile` exists
4. Docker daemon is running
5. `start_services.py` is executable

**Execution**: Calls `start_services.py` which handles the complex service orchestration

> 🤖 **AI Context Note**: This is a simple validation script that delegates to start_services.py. The Python script is used because it can handle complex logic like external repository management and conditional service startup that would be difficult in bash.

---

### 🐍 **start_services.py**

**Purpose**: Python orchestrator for complex multi-repository service management

**Key Functions**:

#### Profile Detection:
```python
def is_supabase_enabled()  # Checks if 'supabase' in COMPOSE_PROFILES
def is_dify_enabled()       # Checks if 'dify' in COMPOSE_PROFILES
```

#### Repository Management:
```python
def clone_supabase_repo()   # Git sparse checkout of supabase/docker
def clone_dify_repo()        # Git sparse checkout of dify/docker
```

#### Environment Preparation:
```python
def prepare_supabase_env()   # Copies .env to supabase/docker/.env
def prepare_dify_env()       # Maps variables from root .env to service-specific
```

#### Service Orchestration:
```python
def stop_existing_containers()  # Stops all containers with proper profiles
def start_supabase()            # Starts Supabase with external compose file
def start_dify()                # Starts Dify with external compose file
def start_local_services()      # Starts main services from docker-compose.yml
```

#### Special Handling:
- **SearXNG First Run**: Temporarily removes security restrictions for initialization
- **Service Dependencies**: Ensures proper startup order (Supabase → Dify → n8n)
- **Network Management**: All services join `localai_default` network

> 🤖 **AI Context Note**: This Python script is the most complex component. Key patterns:
> 1. External services (Supabase, Dify) use sparse git checkout to get only their docker directories
> 2. The script uses dotenv to read COMPOSE_PROFILES and determine which services to start
> 3. All docker-compose commands use project name "localai" for consistency
> 4. The SearXNG workaround is necessary because it needs to create config files on first run
> 5. prepare_dify_env() does variable mapping (DIFY_SECRET_KEY → SECRET_KEY) because Dify expects different variable names
> 6. The script handles both docker-compose.yml and docker-compose.yaml (Dify uses .yaml)
> 7. Sleep timers (15 seconds) ensure services initialize before dependent services start

---

### 📊 **07_final_report.sh**

**Purpose**: Displays service credentials and access URLs

**Process**:
1. Sources `.env` file for all variables
2. Uses `is_profile_active()` to check which services are enabled
3. Displays relevant credentials for each active service
4. Shows formatted output with service-specific information

**Example Output**:
```
================================= n8n =================================
Host: n8n.yourdomain.com

================================= Flowise =============================
Host: flowise.yourdomain.com
User: user@example.com
Password: [generated_password]
```

> 🤖 **AI Context Note**: This script reads credentials from .env and only displays information for active services (based on COMPOSE_PROFILES). The passwords shown here are the ONLY record of generated passwords - they're not stored anywhere else. If a user loses this output, they must regenerate passwords.

---

## 🔄 Update Mechanism

### **scripts/update.sh**
1. Performs git pull to get latest code
2. Updates system packages
3. Calls `apply_update.sh`

### **scripts/apply_update.sh**
1. Updates `.env` with new variables via `03_generate_secrets.sh --update`
2. Runs wizard to update service selection
3. Pulls latest Docker images
4. Restarts services via `06_run_services.sh`
5. Shows final report

> 🤖 **AI Context Note**: The update process preserves user configuration while adding new variables. The --update flag on 03_generate_secrets.sh is critical - without it, all passwords would be regenerated. The update process can handle adding new services but cannot remove deprecated ones automatically.

---

## 🐳 Docker Architecture

### **docker-compose.yml Structure**

**Service Templates** (using YAML anchors):
```yaml
x-n8n: &service-n8n          # Base n8n configuration
x-ollama: &service-ollama    # Base Ollama configuration
```

**Core Services** (always running):
- `postgres`: Database for n8n and other services
- `redis`: Queue management and caching
- `caddy`: Reverse proxy with automatic SSL

**Profile-Based Services**: Each service has a profile tag for selective deployment

**Volume Management**:
```yaml
volumes:
  n8n_storage:        # n8n workflow data
  postgres_data:      # Database persistence
  caddy-data:         # SSL certificates
  # ... 20+ more volumes
```

> 🤖 **AI Context Note**: Docker Compose profiles are the key to selective deployment. Services without profiles always run. Services with profiles only run if their profile is in COMPOSE_PROFILES. The YAML anchors (&service-n8n) define reusable configurations - modifying the anchor affects all services using it. Volume names must be unique across all services. The network "localai_default" is implicitly created and all services join it.

---

## 🐍 Internal Utility Service: python-runner (Optional)

**Purpose**: Lightweight internal container to run custom user Python scripts inside the compose network without exposing any ports.

- **Image**: `python:3.11-slim`
- **Profiles**: `python-runner` (disabled by default; enabled via wizard or `.env`)
- **Mount**: `./python-runner:/app`
- **Command**: Installs `requirements.txt` if present, then runs `python /app/main.py`.
- **Network**: Joins the default compose network (`localai_default`), so it can reach other services by their container names (e.g., `n8n`, `postgres`, `redis`, `qdrant`).
- **Security/Exposure**: No external ports, no reverse proxy, no domains. Internal-only.

### How to enable (Wizard)

- Run `sudo bash ./scripts/install.sh` (initial) or `sudo bash ./scripts/update.sh` (update) and select **Python Runner** in the wizard.

### How to enable (manually)

Add the profile to `.env` so it is managed by the normal startup flow:
```bash
COMPOSE_PROFILES="...,python-runner"
```

Or start on-demand from the CLI without changing `.env`:
```bash
docker compose -p localai --profile python-runner up -d python-runner
```

### Where to put your code

- Local path: `python-runner/`
- Entry file: `python-runner/main.py`
- Optional deps: `python-runner/requirements.txt` (installed automatically on container start)

### Developing and running your script

1) Edit `python-runner/main.py` with your logic. Example: connect to `postgres` using the hostname `postgres` and credentials from `.env`.
2) Add dependencies to `python-runner/requirements.txt` if needed.
3) Start or restart the service:
```bash
docker compose -p localai --profile python-runner up -d --force-recreate python-runner
```
4) View logs:
```bash
docker compose -p localai logs -f python-runner
```

This service is intentionally minimal to avoid conflicts and can be extended by users as needed.

---

## 🌐 Network Architecture

### **Caddyfile Configuration**

**Pattern for each service**:
```
{$SERVICE_HOSTNAME} {
    reverse_proxy service_name:port
}
```

**Special Cases**:
- Basic auth for monitoring services (Prometheus, Grafana)
- WebSocket support for real-time services
- Internal-only services without external exposure

> 🤖 **AI Context Note**: Caddy automatically handles SSL certificates via Let's Encrypt. The {$VARIABLE} syntax reads from environment variables. Service names in reverse_proxy must match container names in docker-compose.yml. Caddy runs in the same Docker network, so it uses internal container names and ports, not external ones.

---

## 🔧 Environment Variable Flow

```
.env.example (template)
        ↓
03_generate_secrets.sh (generation + user input)
        ↓
.env (master configuration)
        ↓
    ├── docker-compose.yml (main services)
    ├── supabase/docker/.env (if enabled)
    └── dify/docker/.env (if enabled)
```

> 🤖 **AI Context Note**: The .env file is the single source of truth. It's loaded by Docker Compose automatically. External services (Supabase, Dify) need their own .env files, which are created by copying and transforming the main .env. Never modify .env.example directly - it's the template. Variable precedence: .env file > docker-compose.yml defaults > Dockerfile defaults.

---

## 📁 Directory Structure After Installation

```
n8n-installer/
├── scripts/                # Installation and maintenance scripts
│   ├── install.sh         # Main entry point
│   ├── 01-06_*.sh        # Installation steps
│   ├── update.sh         # Update mechanism
│   └── utils.sh          # Shared utilities
├── n8n/                   # n8n configuration
│   ├── backup/           # Workflow backups
│   └── n8n_import_script.sh
├── supabase/             # Cloned if enabled
│   └── docker/
├── dify/                 # Cloned if enabled
│   └── docker/
├── shared/               # Shared data volume
├── docker-compose.yml    # Main service definitions
├── Caddyfile            # Reverse proxy config
├── .env                 # Generated configuration
└── .env.example         # Template file
```

> 🤖 **AI Context Note**: The supabase/ and dify/ directories are git repositories cloned with sparse-checkout (only their docker/ subdirectories). The shared/ directory is mounted as /data/shared in n8n containers for file exchange. The n8n/backup/ directory contains workflow JSON files imported during installation if requested.

---

## 🔑 Key Design Patterns

### **1. Idempotent Operations**
Every script can be run multiple times safely. They check current state before making changes.

### **2. Error Propagation**
Using `set -e` and explicit error checks with `|| { log_error "..."; exit 1; }`

### **3. External Repository Integration**
Supabase and Dify are managed as external repositories with sparse checkout, keeping them updatable.

### **4. Profile-Based Service Management**
Docker Compose profiles allow selective service deployment without modifying compose files.

### **5. Shared Resource Optimization**
Multiple services share Postgres and Redis instances when possible.

> 🤖 **AI Context Note**: These patterns are fundamental to the system's reliability. Idempotency means scripts check before acting (e.g., "if Docker not installed, install it"). Error propagation ensures failures stop the process immediately. External repositories allow independent updates. Profiles enable modularity without code duplication. Resource sharing reduces memory footprint but means service isolation is limited.

---

## 🚨 Critical Dependencies

1. **Domain Name**: Must be configured with wildcard DNS before installation
2. **Ubuntu 24.04 LTS**: Scripts assume Ubuntu/Debian package management
3. **Docker Compose Profiles**: Requires Docker Compose v2+ for profile support
4. **Python 3**: Required for `start_services.py` orchestration
5. **Internet Connection**: Needed for Docker image pulls and git clones

> 🤖 **AI Context Note**: Failure points by dependency:
> - No domain/DNS → Caddy SSL fails → services unreachable externally (but work on localhost)
> - Wrong OS → apt commands fail → installation aborts at step 1
> - Old Docker → profiles not supported → all services start regardless of selection
> - No Python → step 5 fails → services don't start
> - No internet → Docker pulls fail → partial installation

---

## 🔧 Troubleshooting Integration Points

### **Common Failure Points**:
1. **APT Lock Issues**: Handled by `run_apt_with_retry()` in `02_install_docker.sh`
2. **Docker Daemon Not Running**: Checked in `06_run_services.sh`
3. **Missing Permissions**: Scripts automatically fix executable permissions
4. **Network Conflicts**: All services use `localai_default` network
5. **Port Conflicts**: Caddy handles all external ports (80, 443)

> 🤖 **AI Context Note**: When debugging issues:
> - Check `docker ps` to see running containers
> - Check `docker compose -p localai ps` to see service states
> - Check `docker logs [container_name]` for service-specific errors
> - Verify .env has all required variables (compare with .env.example)
> - Ensure COMPOSE_PROFILES contains selected services
> - For network issues, verify all services are on network `docker network inspect localai_default`
> - For "port already in use", check if another web server is running on ports 80/443

---

## 🎯 AI Assistant Guidelines

> 🤖 **AI Assistant Instructions**: When working with this system:
> 
> 1. **Always check prerequisites**: Verify Ubuntu version, Docker version, and sudo privileges
> 2. **Respect script sequence**: Never skip steps or run scripts out of order
> 3. **Preserve user data**: The .env file contains user-specific configuration - always back up before modifications
> 4. **Use existing patterns**: Follow the established patterns for adding new services
> 5. **Test changes incrementally**: Make small changes and test before proceeding
> 6. **Check profile consistency**: Service profiles must match between wizard, docker-compose.yml, and COMPOSE_PROFILES
> 7. **Document all changes**: Update this documentation when modifying the system
> 8. **Consider resource usage**: Each service consumes memory - warn users about requirements
> 9. **Maintain idempotency**: Any script modifications must be safely re-runnable
> 10. **Follow logging conventions**: Always use utils.sh logging functions for consistency

---

## 📚 Quick Reference for AI Assistants

### Adding a New Service Checklist:
- [ ] Add service definition to `docker-compose.yml` with profile
- [ ] Add hostname variable to `.env.example`
- [ ] Add password generation to `03_generate_secrets.sh` VARS_TO_GENERATE
- [ ] Add service to `04_wizard.sh` base_services_data array
- [ ] Add reverse proxy block to `Caddyfile`
- [ ] Add credentials display to `07_final_report.sh`
- [ ] Update README.md with service description
- [ ] Test complete installation flow

### Debugging Command Reference:
```bash
# Check service status
docker compose -p localai ps

# View service logs
docker compose -p localai logs [service_name]

# Verify environment variables
docker compose -p localai config

# Test without starting
docker compose -p localai config --dry-run

# Force recreate services
docker compose -p localai up -d --force-recreate

# Clean everything
docker compose -p localai down -v
```

---

*This documentation is designed to be both human-readable and AI-optimized. The AI Context Notes provide additional insights for artificial intelligence assistants to better understand and work with the system.*