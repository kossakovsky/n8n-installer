# Changelog

All notable changes to this project are documented in this file.

## [December 2025]

### Added
- **Anonymous Telemetry** - Optional usage analytics via Scarf (opt-out with `SCARF_ANALYTICS=false`)
- **NocoDB** - Open source Airtable alternative with spreadsheet database interface
- **Gost Proxy** - HTTP/HTTPS proxy for AI services outbound traffic (geo-bypass)
- **Welcome Page** - Post-install dashboard with service credentials and quick start
- **Makefile** - Common project commands (`make install`, `make update`, `make logs`, `make status`, etc.)
- **Doctor diagnostics** - System health checks and troubleshooting
- **Update preview** - Preview changes before applying updates
- **n8n v2.0 support** - Worker-runner sidecar pattern for task execution

### Fixed
- **n8n 2.1.0+ compatibility** - Switch to static ffmpeg binary (apk removed upstream in n8n 2.1.0)

### Changed
- **Postgresus → Databasus** - Rebrand to Databasus with new Docker image `databasus/databasus:latest`. Now supports PostgreSQL, MySQL, MariaDB, and MongoDB backups
- **Git sync** - Replaced `git pull` with `git fetch + reset` for more reliable updates (handles accidental local commits)

## [November 2025]

### Added
- **Docling** - Universal document converter to Markdown/JSON
- **LightRAG** - Graph-based RAG with knowledge graphs

## [October 2025]

### Added
- **RAGFlow** - Deep document understanding RAG engine
- **WAHA** - WhatsApp HTTP API (NOWEB engine)

## [August 2025]

### Added
- **Gotenberg** - Document conversion API (internal use)
- **Dify** - AI Application Development Platform with LLMOps
- **Portainer** - Docker management UI
- **ComfyUI** - Node-based Stable Diffusion UI
- **Cloudflare Tunnel** - Zero-trust secure access
- **RAGApp** - Open-source RAG UI + API
- **Python Runner** - Custom Python code execution
- **Postiz** - Social publishing platform
- **PaddleOCR** - OCR API Server
- **LibreTranslate** - Self-hosted translation API (50+ languages)
- **Postgresus** - PostgreSQL backups & monitoring

## [May 2025]

### Added
- **Qdrant** - Vector database
- **Weaviate** - Vector database with API Key Auth
- **Neo4j** - Graph database
- **Letta** - Agent Server & SDK
- **Monitoring** - Prometheus, Grafana, cAdvisor, node-exporter

## [April 2025]

### Added
- **Langfuse** - LLM observability and analytics platform
