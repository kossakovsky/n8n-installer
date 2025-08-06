# n8n-installer Technical Context

## Technology Stack

### Core Infrastructure
- **Docker Compose**: Service orchestration and container management
- **Caddy Server**: HTTP/2 web server with automatic HTTPS
- **PostgreSQL**: Primary database for n8n and optional services
- **Redis**: Caching layer and n8n queue management

### Programming Languages
- **Shell Scripts**: Primary automation and installation logic
- **Python**: Utility scripts (n8n_pipe.py, start_services.py)
- **JavaScript/Node.js**: n8n workflows and custom code nodes
- **JSON**: Configuration and workflow definitions

### Service Architecture
- **n8n Platform**: Queue mode with worker scaling
- **Microservices**: Each tool runs as isolated Docker container
- **Reverse Proxy**: Caddy handles SSL termination and routing
- **Database Layer**: Postgres with optional vector capabilities

### AI/ML Integration
- **Vector Stores**: Qdrant, Supabase pgvector, Weaviate
- **LLM Hosting**: Ollama for local models
- **AI Frameworks**: Support for OpenAI, Anthropic, Gemini, Claude
- **Agent Platforms**: Flowise, Letta, n8n AI nodes

### Development Tools
- **Monitoring**: Prometheus metrics collection, Grafana visualization
- **Debugging**: Langfuse for AI performance tracking
- **Search**: SearXNG for private web search
- **Crawling**: Crawl4ai for web data extraction

### Security & Networking
- **SSL/TLS**: Automatic certificate management via Let's Encrypt
- **Domain Routing**: Wildcard subdomain configuration
- **Firewall**: Basic security enhancements during installation
- **Authentication**: Service-specific login systems

### File Structure
```
n8n-installer/
├── scripts/           # Installation and maintenance scripts
├── n8n/              # n8n configuration and backups
├── flowise/          # Flowise custom tools and workflows
├── grafana/          # Monitoring dashboards and configuration
├── prometheus/       # Metrics collection configuration
├── caddy-addon/      # Additional Caddy configurations
├── searxng/          # Search engine settings
└── docker-compose.yml # Main orchestration file
```

### Configuration Management
- **Environment Variables**: `.env` file for secrets and settings
- **Service Discovery**: Docker network with named containers
- **Volume Management**: Persistent data storage configuration
- **Port Mapping**: Internal service communication patterns

### Development Libraries (Pre-installed in n8n)
- **cheerio**: HTML/XML parsing and manipulation
- **axios**: HTTP client for API requests
- **moment**: Date/time manipulation
- **lodash**: Utility functions for JavaScript

### Deployment Pipeline
1. **System Preparation**: Updates, firewall, security enhancements
2. **Docker Installation**: Container runtime setup
3. **Secret Generation**: Secure password and key creation
4. **Interactive Wizard**: Service selection and configuration
5. **Service Launch**: Orchestrated container startup
6. **Health Verification**: Service availability confirmation

### Update Mechanism
- **Git-based Updates**: Fetch latest installer changes
- **Image Updates**: Pull newest Docker images
- **Service Restart**: Coordinated rolling updates
- **Backup Integration**: Optional workflow re-import

### Resource Management
- **Scaling**: Configurable n8n worker count
- **Memory**: Service-specific memory allocation
- **Storage**: Volume management for persistent data
- **Network**: Container-to-container communication

### Integration Points
- **API Connectivity**: RESTful interfaces between services
- **Database Sharing**: Common Postgres instance for multiple services
- **Event Triggers**: Webhook-based workflow activation
- **File System**: Shared volume for data exchange (`/data/shared`)

### Monitoring & Observability
- **Metrics**: Prometheus data collection
- **Dashboards**: Grafana visualization panels
- **Logging**: Container-level log aggregation
- **Health Checks**: Service availability monitoring
- **Performance**: AI model execution tracking via Langfuse
