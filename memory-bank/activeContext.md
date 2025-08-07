# Active Context - Dify AI Platform Integration

## Current Phase
**PLAN MODE - Technology Validation & Architecture Design**

## Active Task
**Dify AI Platform Integration** - Level 3 (Intermediate Feature)

## Task Overview
Integrating Dify, an open-source AI application development platform, into the n8n-installer project. This involves:

- Multi-service architecture integration (API, Worker, Web, Nginx, Vector DB)
- Repository cloning and management (similar to Supabase pattern)
- Shared resource configuration (PostgreSQL, Redis)
- Complex environment variable mapping
- Service orchestration and startup dependencies

## Current Focus Areas

### 1. Technology Validation Requirements
- [ ] **Repository Analysis**: Clone and analyze Dify repository structure
- [ ] **Service Dependencies**: Map Dify services to existing infrastructure
- [ ] **Database Integration**: Design shared PostgreSQL strategy
- [ ] **Environment Mapping**: Analyze Dify .env requirements

### 2. Architecture Design Decisions (Creative Phase Required)
- **Database Sharing Strategy**: How to share PostgreSQL between n8n, Supabase, and Dify
- **Service Communication**: Network configuration for inter-service communication  
- **Vector Database Conflict**: Handle Dify's bundled Weaviate vs existing Weaviate service
- **Resource Management**: Allocation strategy for multiple AI services

### 3. Integration Strategy
Following Supabase pattern:
- Clone external repository with sparse checkout
- External docker-compose file inclusion
- Shared environment configuration
- Service selection wizard integration

## Key Technical Challenges

### Challenge 1: Multi-Service Complexity
**Impact**: High - Dify consists of 9+ interconnected services
**Status**: Planning mitigation strategy

### Challenge 2: Resource Sharing
**Impact**: Medium - Need efficient database/cache sharing
**Status**: Requires architecture design phase

### Challenge 3: Environment Variable Complexity  
**Impact**: Medium - Extensive .env configuration needs mapping
**Status**: Analysis in progress

## Implementation Phases Planned

### Phase 1: Repository Integration
- start_services.py modifications
- Dify repository cloning functions
- Environment preparation

### Phase 2: Service Integration
- Docker Compose integration
- Shared network configuration
- Service wizard integration

### Phase 3: Configuration & Proxy
- Environment variable generation
- Caddy reverse proxy setup
- Database credential mapping

### Phase 4: Documentation & Validation
- README updates
- Final report integration
- Comprehensive testing

## Files to be Modified
1. `start_services.py` - Add Dify functions (clone, prepare, start)
2. `scripts/03_generate_secrets.sh` - Add Dify environment variables
3. `scripts/04_wizard.sh` - Add Dify to service selection
4. `docker-compose.yml` - Reference external Dify compose file
5. `Caddyfile` - Add Dify reverse proxy configuration
6. `.env.example` - Add Dify configuration variables
7. `README.md` - Add Dify service documentation
8. `scripts/06_final_report.sh` - Add Dify reporting

## Next Mode Transition
Upon completion of technology validation:
- **CREATIVE MODE**: Resolve architecture design decisions
- **IMPLEMENT MODE**: Execute the planned integration

## References
- Dify Documentation: https://docs.dify.ai/en/getting-started/install-self-hosted/docker-compose
- Existing Supabase integration pattern in start_services.py
- Level 3 planning guidelines
