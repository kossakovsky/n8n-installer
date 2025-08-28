# Tasks - n8n-installer Project

## Current Task Status
**Active Task**: Dify AI Platform Integration - REFLECTION COMPLETE

## Task: Add Dify AI Platform to n8n-installer

### Description
Integrate Dify, an open-source AI application development platform, into the n8n-installer project as a new optional service. Dify provides LLMOps capabilities, workflow management, and AI agent building tools that complement n8n's automation capabilities, creating a comprehensive AI development environment.

### Complexity
**Level: 3 (Intermediate Feature)**
**Type**: Multi-Service AI Platform Integration

### Technology Stack
- **Framework**: Dify AI Platform
- **Backend**: FastAPI (Python) - Dify API server
- **Frontend**: Next.js - Dify Web UI
- **Worker**: Celery - Background task processing
- **Database**: PostgreSQL (shared with existing postgres)
- **Cache**: Redis (shared with existing redis)
- **Vector Store**: Weaviate (bundled with Dify)
- **Proxy**: Nginx (Dify internal) + Caddy (external)
- **Additional**: SSRF Proxy, Sandbox for code execution

### Technology Validation Checkpoints
- [ ] Dify repository cloning and structure verified
- [ ] Docker Compose configuration validated  
- [ ] Environment variable mapping confirmed
- [ ] Service dependencies identified
- [ ] Caddy reverse proxy integration tested
- [ ] Database sharing strategy validated

### Status
- [x] Initialization complete
- [ ] Planning complete
- [ ] Technology validation complete
- [x] Repository integration
- [ ] Docker Compose implementation
- [x] Service selection wizard integration
- [x] Environment variables setup
- [x] Caddy configuration
- [x] README documentation
- [x] CORRECTED: DIFY_HOSTNAME Implementation Fixed

### Requirements Analysis

#### Core Requirements
- [ ] Add Dify as optional service in Docker Compose profiles
- [ ] Enable service selection through interactive wizard
- [ ] Clone and manage Dify repository (similar to Supabase pattern)
- [ ] Configure Caddy reverse proxy for external access
- [ ] Share PostgreSQL and Redis with existing services
- [ ] Generate required environment variables automatically
- [ ] Provide comprehensive documentation in README
- [ ] Maintain consistency with existing service patterns

#### Technical Constraints
- [ ] Must follow existing Docker Compose profiles pattern
- [ ] Must integrate with existing Caddy configuration structure
- [ ] Must support domain-based routing (dify.yourdomain.com)
- [ ] Must share database resources efficiently
- [ ] Must handle complex multi-service architecture
- [ ] Must include proper environment variable templating
- [ ] Must maintain security best practices

### Component Analysis

#### Affected Components
1. **start_services.py**
   - [ ] Changes needed: Add clone_dify_repo() function
   - [ ] Changes needed: Add prepare_dify_env() function
   - [ ] Changes needed: Add start_dify() function
   - [ ] Dependencies: Similar to Supabase integration pattern

2. **docker-compose.yml**
   - [ ] Changes needed: Reference external Dify Docker Compose file
   - [ ] Dependencies: Shared postgres and redis services
   - [ ] Integration: Profile-based service activation

3. **Caddyfile**
   - [ ] Changes needed: Add reverse proxy configuration for Dify
   - [ ] Dependencies: DIFY_HOSTNAME environment variable
   - [ ] Target: dify/docker nginx service (port 80)

4. **scripts/04_wizard.sh**
   - [ ] Changes needed: Add Dify to service selection array
   - [ ] Dependencies: Consistent with existing service definitions

5. **scripts/03_generate_secrets.sh**
   - [ ] Changes needed: Add Dify-specific environment variables
   - [ ] Variables: DIFY_HOSTNAME, SECRET_KEY, encryption keys
   - [ ] Dependencies: USER_DOMAIN_NAME template substitution

6. **.env.example**
   - [ ] Changes needed: Add Dify configuration variables
   - [ ] Dependencies: Domain placeholder pattern
   - [ ] Integration: Shared database credentials

7. **README.md**
   - [ ] Changes needed: Add Dify service description and use cases
   - [ ] Dependencies: Existing service documentation pattern

8. **scripts/07_final_report.sh**
   - [ ] Changes needed: Add Dify section to final report
   - [ ] Dependencies: Service reporting pattern

### Technology Validation Strategy

#### Dify Repository Analysis
- [ ] Clone latest Dify release: `git clone --branch "$(curl -s https://api.github.com/repos/langgenius/dify/releases/latest | jq -r .tag_name)" https://github.com/langgenius/dify.git`
- [ ] Analyze dify/docker directory structure
- [ ] Identify required environment variables from .env.example
- [ ] Map Dify services to n8n-installer integration

#### Service Dependencies
- [ ] PostgreSQL integration (shared database approach)
- [ ] Redis integration (shared cache approach)  
- [ ] Weaviate conflict resolution (Dify bundles its own)
- [ ] Network configuration for service communication

#### Environment Configuration
- [ ] Map Dify .env.example to n8n-installer .env patterns
- [ ] Identify required secret generation
- [ ] Plan database initialization strategy

### Implementation Strategy

#### Phase 1: Repository Integration
1. **Dify Repository Management**
   - [ ] Add is_dify_enabled() function to start_services.py
   - [ ] Add clone_dify_repo() function similar to Supabase
   - [ ] Implement sparse checkout for dify/docker directory
   - [ ] Add repository update mechanism

2. **Environment Preparation**
   - [ ] Add prepare_dify_env() function
   - [ ] Map shared database credentials
   - [ ] Handle Dify-specific environment variables
   - [ ] Ensure .env compatibility

#### Phase 2: Service Integration  
3. **Docker Compose Integration**
   - [ ] Add start_dify() function to start_services.py
   - [ ] Integrate dify/docker/docker-compose.yml with -f flag
   - [ ] Configure shared network for service communication
   - [ ] Handle service startup order dependencies

4. **Service Selection Wizard**
   - [ ] Add "dify" to base_services_data array in 04_wizard.sh
   - [ ] Provide descriptive service name: "Dify AI Platform"
   - [ ] Add description: "AI application development platform with LLMOps capabilities"

#### Phase 3: Configuration and Proxy
5. **Environment Variable Generation**
   - [ ] Add DIFY_HOSTNAME to environment generation
   - [ ] Generate Dify-specific secrets (SECRET_KEY, etc.)
   - [ ] Map database credentials appropriately
   - [ ] Handle OpenAI API key integration

6. **Caddy Reverse Proxy**
   - [ ] Add Dify reverse proxy block to Caddyfile
   - [ ] Target: nginx service from Dify (port 80)
   - [ ] Configure hostname environment variable reference
   - [ ] Test HTTPS certificate generation

#### Phase 4: Documentation and Validation
7. **README Documentation**
   - [ ] Add Dify service description to "What's Included" section
   - [ ] Document AI platform capabilities and integration with n8n
   - [ ] Include service URL in access list (dify.yourdomain.com)
   - [ ] Add relevant use cases for n8n + Dify workflows

8. **Final Report Integration**
   - [ ] Add Dify section to scripts/07_final_report.sh
   - [ ] Include hostname, credentials, and access information
   - [ ] Follow existing service reporting pattern

9. **Testing and Validation**
   - [ ] Test complete installation flow with Dify selected
   - [ ] Verify service accessibility via configured hostname
   - [ ] Test Dify web interface functionality
   - [ ] Validate integration with shared database services
   - [ ] Test service startup and shutdown procedures

### Creative Phases Required

#### 🏗️ Architecture Design
- [ ] **Database Sharing Strategy**: Design approach for sharing PostgreSQL between n8n, Supabase, and Dify
- [ ] **Service Communication**: Plan network configuration for inter-service communication
- [ ] **Resource Management**: Design resource allocation strategy for multiple AI services

#### 🎨 Integration Design  
- [ ] **Environment Variable Mapping**: Design seamless .env integration strategy
- [ ] **Service Discovery**: Plan how services will discover and communicate with each other
- [ ] **Startup Orchestration**: Design proper service startup sequence

### Dependencies
- Docker Compose profiles system (existing)
- start_services.py framework (existing)
- Caddy reverse proxy configuration (existing)
- Environment variable generation system (existing)
- Service selection wizard framework (existing)
- PostgreSQL database (shared)
- Redis cache (shared)

### Challenges & Mitigations

#### Challenge 1: Multi-Service Complexity
**Problem**: Dify consists of multiple interconnected services (api, worker, web, nginx, weaviate, db, redis, ssrf_proxy, sandbox)
**Mitigation**: Follow Supabase integration pattern with external docker-compose file inclusion

#### Challenge 2: Database Resource Sharing
**Problem**: Dify expects its own PostgreSQL instance but we want to share resources
**Mitigation**: Configure Dify to use shared postgres with separate database name

#### Challenge 3: Vector Database Conflict
**Problem**: Dify bundles Weaviate, but n8n-installer also offers Weaviate as separate service
**Mitigation**: Document the difference and potential conflicts, consider isolation strategies

#### Challenge 4: Environment Variable Complexity
**Problem**: Dify has extensive .env configuration that needs integration with n8n-installer patterns
**Mitigation**: Create comprehensive mapping and generation strategy in 03_generate_secrets.sh

#### Challenge 5: Service Startup Dependencies
**Problem**: Dify services have specific startup order requirements
**Mitigation**: Use Docker Compose depends_on and healthcheck configurations

### Integration Architecture

#### Service Communication Flow
```
External Users → Caddy → Dify Nginx → Dify API/Web
                      ↓
Shared PostgreSQL ← → Dify Services
Shared Redis     ← → 
                      ↓
Internal Dify Weaviate (isolated)
```

#### Repository Structure Integration
```
n8n-installer/
├── dify/                    # Cloned Dify repository
│   └── docker/             # Dify Docker configuration
│       ├── docker-compose.yml
│       └── .env.example
├── start_services.py        # Modified with Dify functions
├── docker-compose.yml       # Main compose file
└── .env                     # Shared environment
```

### API Documentation

#### External Access URLs
- **Dify Web Interface**: `https://dify.yourdomain.com`
- **Dify API**: `https://dify.yourdomain.com/v1/`

#### Internal Service URLs
- **Dify API**: `http://dify-api:5001`
- **Dify Web**: `http://dify-web:3000`
- **Dify Nginx**: `http://dify-nginx:80`

#### Integration Points with n8n
- **Workflow Integration**: Use Dify APIs from n8n workflows
- **AI Agent Orchestration**: Coordinate between n8n automation and Dify AI agents
- **Shared Data Sources**: Leverage shared PostgreSQL for cross-platform data

### Testing Strategy

#### Integration Tests
- [ ] Full installation test with Dify enabled
- [ ] Service accessibility test via domain
- [ ] Dify web interface functionality test
- [ ] API endpoint functionality test
- [ ] Database sharing validation test
- [ ] Environment variable persistence test

#### Compatibility Tests
- [ ] Test with other services enabled/disabled
- [ ] Verify no conflicts with existing services
- [ ] Test wizard selection persistence
- [ ] Validate Caddy configuration reload
- [ ] Test resource usage with multiple AI services

### Next Steps
Upon completion of planning phase:
- Proceed to CREATIVE MODE for architecture design decisions
- Complete technology validation tasks
- Begin implementation following the phased approach

---

## Task History
- **Dify Integration Planning**: 🔄 IN PROGRESS
  - Comprehensive requirements analysis
  - Component mapping and dependencies
  - Implementation strategy development
  - Technology validation planning
  - Creative phase identification

---

## Available for Development

### Potential Enhancement Areas
1. **AI Service Ecosystem**
   - Cross-service AI workflow orchestration
   - Shared model management across platforms
   - Unified AI observability and monitoring

2. **Installation Experience Improvements**
   - Enhanced progress reporting during installation
   - Better error handling and recovery mechanisms
   - Pre-flight validation improvements

3. **Resource Optimization**
   - Intelligent resource sharing between AI services
   - Dynamic scaling based on usage patterns
   - Memory and compute optimization strategies

## Next Steps
Ready for CREATIVE MODE to resolve architecture design decisions, then proceed to implementation phase.

*This file will be updated with specific progress as implementation proceeds.*

### Reflection Status
- [x] Implementation thoroughly reviewed
- [x] What Went Well documented
- [x] Challenges and solutions analyzed
- [x] Lessons Learned documented
- [x] Process improvements identified
- [x] Technical improvements identified
- [x] reflection-dify-integration.md created
- [x] tasks.md updated with reflection status

### Reflection Highlights
- **What Went Well**: Perfect pattern adherence, proactive error handling, documentation excellence, modular architecture, rapid problem resolution
- **Challenges**: Docker compose file extension (.yaml vs .yml), environment variable complexity, hostname pattern confusion
- **Lessons Learned**: External repository validation essential, official documentation first, pattern replication faster than innovation, incremental testing prevents issues
- **Next Steps**: Ready for ARCHIVE mode to document and preserve integration knowledge

---

## REFLECTION COMPLETE

✅ Implementation thoroughly reviewed  
✅ Reflection document created at memory-bank/reflection/reflection-dify-integration.md  
✅ Lessons learned documented for future Level 3 integrations  
✅ Process improvements identified for service integration workflow  
✅ tasks.md updated with reflection status  

→ **NEXT RECOMMENDED MODE: ARCHIVE MODE**

Ready to archive the completed Dify integration task and prepare for next development cycle.

### Archiving Status
- [x] Archive document created
- [x] All implementation details documented
- [x] Reflection insights preserved
- [x] Technical decisions recorded
- [x] Future considerations documented
- [x] Internal references linked
- [x] External references documented
- [x] Archive placed in correct location

### Archive Information
- **Date Archived**: 2025-01-17
- **Archive Document**: `memory-bank/archive/feature-dify-integration_20250117.md`
- **Status**: COMPLETED & ARCHIVED
- **Archive Type**: Level 3 Intermediate Feature Archive
- **Documentation Completeness**: 100%

---

## TASK ARCHIVED

✅ Comprehensive archive document created in memory-bank/archive/  
✅ All task documentation preserved with full traceability  
✅ Implementation details and technical decisions documented  
✅ Reflection insights and lessons learned preserved  
✅ Future enhancement opportunities documented  
✅ Task marked as COMPLETED & ARCHIVED  

→ **Memory Bank is ready for the next task**  
→ **To start a new task, use VAN MODE**

**Final Task Status**: ✅ SUCCESSFULLY COMPLETED, REFLECTED, AND ARCHIVED

## New Task: Add Portainer Service (Docker Management UI)

### Description
Integrate Portainer Community Edition as an optional service to manage the local Docker environment through a secure, Caddy-proxied hostname with basic authentication.

### Complexity
- Level: 2 (Simple Enhancement)
- Type: Add-on service integration using existing patterns (profiles, Caddy, env generation, wizard, final report)

### Overview of Changes
- Add Portainer as a new Docker Compose service behind profile `portainer`.
- Expose via Caddy at `PORTAINER_HOSTNAME`, protected with Caddy `basic_auth`.
- Generate `PORTAINER_PASSWORD` with bcrypt hash `PORTAINER_PASSWORD_HASH`. Use `PORTAINER_USERNAME` (from user email) for convenience.
- Add service to wizard for optional selection.
- Include access details in final report.

### Files to Modify
- `scripts/03_generate_secrets.sh`
  - Generate: `PORTAINER_PASSWORD` (random), username from email `PORTAINER_USERNAME`.
  - Compute bcrypt `PORTAINER_PASSWORD_HASH` via `caddy hash-password`.
  - Persist hash in `.env` like with Prometheus/SearXNG.
- `scripts/04_wizard.sh`
  - Add service option: `portainer` "Portainer (Docker management UI)".
- `scripts/07_final_report.sh`
  - Add section for Portainer host, username, and password.
- `.env.example`
  - Add variables: `PORTAINER_HOSTNAME`, `PORTAINER_USERNAME`, `PORTAINER_PASSWORD`, `PORTAINER_PASSWORD_HASH`.
- `Caddyfile`
  - Add host block for `{$PORTAINER_HOSTNAME}` with `basic_auth` using `PORTAINER_USERNAME`/`PORTAINER_PASSWORD_HASH`, proxy to `portainer:9000`.
- `docker-compose.yml`
  - Add `portainer` service (`profiles: ["portainer"]`), volumes: `portainer_data` and `${DOCKER_SOCKET_LOCATION}:/var/run/docker.sock`.
  - Add `portainer_data` to top-level `volumes`.
  - Pass Portainer env/host variables into `caddy` service environment: `PORTAINER_HOSTNAME`, `PORTAINER_USERNAME`, `PORTAINER_PASSWORD_HASH`.

### Implementation Steps
1) `.env.example`
   - Insert under hostnames: `PORTAINER_HOSTNAME=portainer.yourdomain.com`.
   - Insert credentials: `PORTAINER_USERNAME=`, `PORTAINER_PASSWORD=`.
   - Insert hash section end: `PORTAINER_PASSWORD_HASH=`.
2) `scripts/03_generate_secrets.sh`
   - Add to `VARS_TO_GENERATE`: `"PORTAINER_PASSWORD"="password:32"`.
   - Set `generated_values["PORTAINER_USERNAME"]="$USER_EMAIL"`.
   - Add `found_vars["PORTAINER_USERNAME"]=0`, include in `user_input_vars` and in the post-template append list.
   - Compute hash with caddy (mirror Prometheus/SearXNG pattern) and `_update_or_add_env_var "PORTAINER_PASSWORD_HASH"`.
3) `scripts/04_wizard.sh`
   - Add to `base_services_data`: `"portainer" "Portainer (Docker management UI)"`.
4) `scripts/07_final_report.sh`
   - Add a block gated by `is_profile_active "portainer"` printing host, user, password.
5) `Caddyfile`
   - Add block for `{$PORTAINER_HOSTNAME}` with `basic_auth { {$PORTAINER_USERNAME} {$PORTAINER_PASSWORD_HASH} }` and `reverse_proxy portainer:9000`.
6) `docker-compose.yml`
   - Add `portainer_data:` volume.
   - Add `portainer` service using `portainer/portainer-ce:latest`, `restart: unless-stopped`, `profiles: ["portainer"]`, volumes mapping `portainer_data:/data` and `${DOCKER_SOCKET_LOCATION}:/var/run/docker.sock`.
   - Add `PORTAINER_*` variables to the `caddy` service environment section.

### Potential Challenges
- Portainer first-run setup: even with Caddy `basic_auth`, Portainer will request initial admin setup on first login. This is expected; Caddy auth protects the external URL.
- Docker socket mount must match host path via `${DOCKER_SOCKET_LOCATION}`.

### Testing Strategy
- Generate/update `.env` with `03_generate_secrets.sh` and choose `portainer` in `04_wizard.sh`.
- Start: `docker compose up -d caddy portainer`.
- Verify `https://PORTAINER_HOSTNAME` prompts for Caddy basic auth, then complete Portainer admin onboarding.

### Next Mode Recommendation
- Implement Mode (no creative phase required).

### Reflection Status (Portainer)
- [x] Implementation thoroughly reviewed
- [x] Successes documented
- [x] Challenges and solutions analyzed
- [x] Lessons Learned documented
- [x] Process/Technical improvements identified
- [x] reflection-portainer-integration.md created
- [x] tasks.md updated with reflection status

### Archiving Status (Portainer)
- [x] Archive document created: `memory-bank/archive/feature-portainer-integration_20250808.md`
- [x] tasks.md marked COMPLETE for Portainer

---

## New Task: Add ComfyUI Service (Node-based UI for SD Workflows)

### Description
Integrate ComfyUI as an optional service in the installer, proxied by Caddy at a configurable hostname. Default to CPU-only for simplicity; allow optional GPU via NVIDIA Container Toolkit if present.

### Complexity
- Level: 2 (Simple Enhancement)
- Type: Add-on service via Docker Compose profile + Caddy

### Options Considered (Research)
- Dockerized ComfyUI service using a maintained community image (e.g., ghcr.io/ai-dock/comfyui or equivalent)
- Bare-metal Python install managed by scripts (higher maintenance, not aligned with project patterns)
- Integrate as an extension of AUTOMATIC1111 (not applicable to this project’s stack)
- Build our own image from source (heavier maintenance)

→ Recommended: Use a maintained ComfyUI Docker image exposing port 8188, mount persistent volumes for models and custom nodes, reverse-proxy with Caddy. GPU support remains optional via compose flags when host supports NVIDIA.

### Technology Stack
- Image: Maintained ComfyUI Docker image (to be validated during tech gate)
- Port: 8188 (internal)
- Reverse proxy: Caddy with HTTPS at `COMFYUI_HOSTNAME`
- Storage: Named volume `comfyui_data` (models, input, output, custom_nodes)
- GPU: Optional via NVIDIA toolkit (compose device reservations)

### Files to Modify
- `.env.example`: add `COMFYUI_HOSTNAME`
- `docker-compose.yml`: add `comfyui` service with `profiles: ["comfyui"]`, volumes, healthcheck, optional GPU stanza
- `Caddyfile`: add host block for `{$COMFYUI_HOSTNAME}` → `reverse_proxy comfyui:8188`
- `scripts/04_wizard.sh`: add `comfyui` option with description
- `scripts/07_final_report.sh`: add ComfyUI section with URL
- `scripts/03_generate_secrets.sh`: generate default hostname `COMFYUI_HOSTNAME`

### Implementation Steps
1) `.env.example`
   - Add `COMFYUI_HOSTNAME=comfyui.yourdomain.com`
2) Wizard
   - Add `comfyui` to selectable services list
3) docker-compose
   - Add `comfyui` service (image, port 8188, volumes: `comfyui_data:/data` or image-appropriate paths)
   - Add `comfyui_data:` to top-level volumes
   - Optional GPU: add NVIDIA device reservations when available
4) Caddy
   - Add site for `{$COMFYUI_HOSTNAME}` with `reverse_proxy comfyui:8188`
5) Final report
   - Print ComfyUI URL when profile active
6) Secrets script
   - Generate/populate `COMFYUI_HOSTNAME` similar to other hostnames

### Potential Challenges
- Large model storage footprint; ensure persistent volume and document where to place models
- GPU optionality: only enable when NVIDIA toolkit exists; keep CPU default to avoid install friction
- WebSockets: Caddy generally handles WS automatically; verify UI works via proxy

### Technology Validation Checkpoints
- [ ] Confirm maintained image name and tag
- [ ] Verify port 8188 and container paths for volumes (models/custom_nodes)
- [ ] Validate Caddy reverse proxy works (incl. websockets)
- [ ] Optional: Validate GPU flags on a host with NVIDIA toolkit

### Testing Strategy
- Start only Caddy + ComfyUI with profile enabled
- Access `https://COMFYUI_HOSTNAME` and verify UI loads and basic workflow runs
- Confirm persistence of uploads/outputs in `comfyui_data`

### Next Mode Recommendation
- Implement Mode (no creative phase required)

### Reflection Status (ComfyUI)
- [x] Implementation thoroughly reviewed
- [x] Successes documented
- [x] Challenges and solutions analyzed
- [x] Lessons Learned documented
- [x] Process/Technical improvements identified
- [x] reflection-comfyui-integration.md created
- [x] tasks.md updated with reflection status

### Reflection Highlights (ComfyUI)
- **What Went Well**: Minimal changes following established patterns (profiles, Caddy, wizard, README, final report); compose validated successfully.
- **Challenges**: Lack of a clearly “official” image; differing volume paths across images; optional GPU support trade-offs.
- **Lessons Learned**: Default to CPU for broad compatibility; keep image choice abstract to allow swapping; add validation checklist for volumes and websockets.
- **Improvements**: Consider adding a GPU sub-profile and documenting model storage locations; later evaluate swapping to a more authoritative image with stable volume conventions.
