# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-01-11

### Added
- **Custom TLS certificates** - Support for corporate/internal certificates via `caddy-addon/` mechanism
- New `make stop` and `make start` commands for stopping/starting all services without restart
- New `make setup-tls` command and `scripts/setup_custom_tls.sh` helper script for easy certificate configuration
- New `make git-pull` command for fork workflows - merges from upstream instead of hard reset

## [1.0.0] - 2026-01-07

### Added
- First official stable release

## [0.38.0] - 2026-01-04

### Fixed
- Gost proxy bypass for Supabase internal services

## [0.37.0] - 2026-01-02

### Added
- Workflow import command (`make import`)

## [0.36.0] - 2025-12-28

### Changed
- Postgresus renamed to Databasus with new Docker image `databasus/databasus:latest`
- Now supports PostgreSQL, MySQL, MariaDB, and MongoDB backups

## [0.35.0] - 2025-12-25

### Added
- Anonymous telemetry via Scarf (opt-out with `SCARF_ANALYTICS=false`)

## [0.34.0] - 2025-12-25

### Added
- NocoDB - Open source Airtable alternative with spreadsheet database interface

## [0.33.0] - 2025-12-22

### Fixed
- Static ffmpeg binary for n8n 2.1.0+ compatibility (apk removed upstream)

## [0.32.0] - 2025-12-21

### Fixed
- Healthcheck proxy bypass for localhost connections

## [0.31.0] - 2025-12-20

### Added
- Gost proxy - HTTP/HTTPS proxy for AI services outbound traffic (geo-bypass)

## [0.30.0] - 2025-12-11

### Added
- Doctor diagnostics - System health checks and troubleshooting
- Update preview - Preview changes before applying updates
- Wizard service groups for better organization

## [0.29.0] - 2025-12-12

### Fixed
- Open-webui healthcheck with longer start_period

## [0.28.0] - 2025-12-11

### Added
- Welcome page dashboard with service credentials and quick start

## [0.27.0] - 2025-12-09

### Fixed
- n8n v2.0 migration review issues

## [0.26.0] - 2025-12-09

### Added
- n8n 2.0 support with worker-runner sidecar pattern
- Makefile for common project commands (`make install`, `make update`, `make logs`, etc.)

### Changed
- Task execution now uses dedicated runners per worker
- Workers and runners generated dynamically via `scripts/generate_n8n_workers.sh`

## [0.25.0] - 2025-12-08

### Changed
- n8n Dockerfile updated to use stable version 2.0.0

## [0.24.0] - 2025-11-09

### Added
- Docling - Universal document converter to Markdown/JSON

## [0.23.0] - 2025-11-01

### Added
- LightRAG - Graph-based RAG with knowledge graphs

## [0.22.0] - 2025-10-29

### Added
- RAGFlow - Deep document understanding RAG engine

## [0.21.0] - 2025-10-15

### Added
- WAHA - WhatsApp HTTP API (NOWEB engine)

## [0.20.0] - 2025-08-28

### Added
- Postgresus - PostgreSQL backups & monitoring

## [0.19.0] - 2025-08-28

### Added
- LibreTranslate - Self-hosted translation API (50+ languages)

## [0.18.0] - 2025-08-27

### Added
- PaddleOCR - OCR API Server

## [0.17.0] - 2025-08-19

### Added
- Postiz - Social publishing platform

## [0.16.0] - 2025-08-15

### Added
- Python Runner - Custom Python code execution environment

## [0.15.0] - 2025-08-15

### Added
- RAGApp - Open-source RAG UI + API

## [0.14.0] - 2025-08-13

### Added
- Cloudflare Tunnel - Zero-trust secure access

## [0.13.0] - 2025-08-07

### Added
- ComfyUI - Node-based Stable Diffusion UI

## [0.12.0] - 2025-08-07

### Added
- Portainer - Docker management UI

## [0.11.0] - 2025-08-06

### Added
- Gotenberg - Document conversion API (internal use)

## [0.10.0] - 2025-08-06

### Added
- Dify - AI Application Development Platform with LLMOps

## [0.9.0] - 2025-06-17

### Added
- Qdrant Caddy reverse proxy configuration

## [0.8.0] - 2025-05-28

### Added
- Monitoring stack - Prometheus, Grafana, cAdvisor, node-exporter

## [0.7.0] - 2025-05-26

### Added
- Neo4j - Graph database

## [0.6.0] - 2025-05-24

### Added
- Weaviate - Vector database with API Key Auth

## [0.5.0] - 2025-05-22

### Added
- Qdrant - Vector database

## [0.4.0] - 2025-05-15

### Added
- Ollama - Local LLM inference

## [0.3.0] - 2025-05-15

### Added
- Letta - Agent Server & SDK

## [0.2.0] - 2025-05-09

### Added
- Interactive service selection wizard using whiptail
- Profile-based service management via Docker Compose profiles

## [0.1.0] - 2025-04-18

### Added
- Langfuse - LLM observability and analytics platform
- Initial fork from coleam00/local-ai-packager with enhanced service support
