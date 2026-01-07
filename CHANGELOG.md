# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.5.3] - 2026-01-04

### Fixed
- Gost proxy bypass for Supabase internal services

## [2.5.2] - 2026-01-02

### Added
- Workflow import command (`make import`)

## [2.5.1] - 2025-12-28

### Changed
- Postgresus renamed to Databasus with new Docker image `databasus/databasus:latest`
- Now supports PostgreSQL, MySQL, MariaDB, and MongoDB backups

## [2.5.0] - 2025-12-25

### Added
- Anonymous telemetry via Scarf (opt-out with `SCARF_ANALYTICS=false`)

## [2.4.0] - 2025-12-25

### Added
- NocoDB - Open source Airtable alternative with spreadsheet database interface

## [2.3.2] - 2025-12-22

### Fixed
- Static ffmpeg binary for n8n 2.1.0+ compatibility (apk removed upstream)

## [2.3.1] - 2025-12-21

### Fixed
- Healthcheck proxy bypass for localhost connections

## [2.3.0] - 2025-12-20

### Added
- Gost proxy - HTTP/HTTPS proxy for AI services outbound traffic (geo-bypass)

## [2.2.0] - 2025-12-11

### Added
- Doctor diagnostics - System health checks and troubleshooting
- Update preview - Preview changes before applying updates
- Wizard service groups for better organization

## [2.1.1] - 2025-12-12

### Fixed
- Open-webui healthcheck with longer start_period

## [2.1.0] - 2025-12-11

### Added
- Welcome page dashboard with service credentials and quick start

## [2.0.1] - 2025-12-09

### Fixed
- n8n v2.0 migration review issues

## [2.0.0] - 2025-12-09

### Added
- n8n 2.0 support with worker-runner sidecar pattern
- Makefile for common project commands (`make install`, `make update`, `make logs`, etc.)

### Changed
- Task execution now uses dedicated runners per worker
- Workers and runners generated dynamically via `scripts/generate_n8n_workers.sh`

## [1.22.1] - 2025-12-08

### Changed
- n8n Dockerfile updated to use stable version 2.0.0

## [1.22.0] - 2025-11-09

### Added
- Docling - Universal document converter to Markdown/JSON

## [1.21.0] - 2025-11-01

### Added
- LightRAG - Graph-based RAG with knowledge graphs

## [1.20.0] - 2025-10-29

### Added
- RAGFlow - Deep document understanding RAG engine

## [1.19.0] - 2025-10-15

### Added
- WAHA - WhatsApp HTTP API (NOWEB engine)

## [1.18.0] - 2025-08-28

### Added
- Postgresus - PostgreSQL backups & monitoring

## [1.17.0] - 2025-08-28

### Added
- LibreTranslate - Self-hosted translation API (50+ languages)

## [1.16.0] - 2025-08-27

### Added
- PaddleOCR - OCR API Server

## [1.15.0] - 2025-08-19

### Added
- Postiz - Social publishing platform

## [1.14.0] - 2025-08-15

### Added
- Python Runner - Custom Python code execution environment

## [1.13.0] - 2025-08-15

### Added
- RAGApp - Open-source RAG UI + API

## [1.12.0] - 2025-08-13

### Added
- Cloudflare Tunnel - Zero-trust secure access

## [1.11.0] - 2025-08-07

### Added
- ComfyUI - Node-based Stable Diffusion UI

## [1.10.0] - 2025-08-07

### Added
- Portainer - Docker management UI

## [1.9.0] - 2025-08-06

### Added
- Gotenberg - Document conversion API (internal use)

## [1.8.0] - 2025-08-06

### Added
- Dify - AI Application Development Platform with LLMOps

## [1.7.0] - 2025-06-17

### Added
- Qdrant Caddy reverse proxy configuration

## [1.6.0] - 2025-05-28

### Added
- Monitoring stack - Prometheus, Grafana, cAdvisor, node-exporter

## [1.5.0] - 2025-05-26

### Added
- Neo4j - Graph database

## [1.4.0] - 2025-05-24

### Added
- Weaviate - Vector database with API Key Auth

## [1.3.0] - 2025-05-22

### Added
- Qdrant - Vector database

## [1.2.0] - 2025-05-15

### Added
- Ollama - Local LLM inference

## [1.1.0] - 2025-05-15

### Added
- Letta - Agent Server & SDK

## [1.0.0] - 2025-05-09

### Added
- Interactive service selection wizard using whiptail
- Profile-based service management via Docker Compose profiles

## [0.1.0] - 2025-04-18

### Added
- Langfuse - LLM observability and analytics platform
- Initial fork from coleam00/local-ai-packager with enhanced service support

[Unreleased]: https://github.com/kossakovsky/n8n-install/compare/v2.5.3...HEAD
[2.5.3]: https://github.com/kossakovsky/n8n-install/compare/v2.5.2...v2.5.3
[2.5.2]: https://github.com/kossakovsky/n8n-install/compare/v2.5.1...v2.5.2
[2.5.1]: https://github.com/kossakovsky/n8n-install/compare/v2.5.0...v2.5.1
[2.5.0]: https://github.com/kossakovsky/n8n-install/compare/v2.4.0...v2.5.0
[2.4.0]: https://github.com/kossakovsky/n8n-install/compare/v2.3.2...v2.4.0
[2.3.2]: https://github.com/kossakovsky/n8n-install/compare/v2.3.1...v2.3.2
[2.3.1]: https://github.com/kossakovsky/n8n-install/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/kossakovsky/n8n-install/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/kossakovsky/n8n-install/compare/v2.1.1...v2.2.0
[2.1.1]: https://github.com/kossakovsky/n8n-install/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/kossakovsky/n8n-install/compare/v2.0.1...v2.1.0
[2.0.1]: https://github.com/kossakovsky/n8n-install/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/kossakovsky/n8n-install/compare/v1.22.1...v2.0.0
[1.22.1]: https://github.com/kossakovsky/n8n-install/compare/v1.22.0...v1.22.1
[1.22.0]: https://github.com/kossakovsky/n8n-install/compare/v1.21.0...v1.22.0
[1.21.0]: https://github.com/kossakovsky/n8n-install/compare/v1.20.0...v1.21.0
[1.20.0]: https://github.com/kossakovsky/n8n-install/compare/v1.19.0...v1.20.0
[1.19.0]: https://github.com/kossakovsky/n8n-install/compare/v1.18.0...v1.19.0
[1.18.0]: https://github.com/kossakovsky/n8n-install/compare/v1.17.0...v1.18.0
[1.17.0]: https://github.com/kossakovsky/n8n-install/compare/v1.16.0...v1.17.0
[1.16.0]: https://github.com/kossakovsky/n8n-install/compare/v1.15.0...v1.16.0
[1.15.0]: https://github.com/kossakovsky/n8n-install/compare/v1.14.0...v1.15.0
[1.14.0]: https://github.com/kossakovsky/n8n-install/compare/v1.13.0...v1.14.0
[1.13.0]: https://github.com/kossakovsky/n8n-install/compare/v1.12.0...v1.13.0
[1.12.0]: https://github.com/kossakovsky/n8n-install/compare/v1.11.0...v1.12.0
[1.11.0]: https://github.com/kossakovsky/n8n-install/compare/v1.10.0...v1.11.0
[1.10.0]: https://github.com/kossakovsky/n8n-install/compare/v1.9.0...v1.10.0
[1.9.0]: https://github.com/kossakovsky/n8n-install/compare/v1.8.0...v1.9.0
[1.8.0]: https://github.com/kossakovsky/n8n-install/compare/v1.7.0...v1.8.0
[1.7.0]: https://github.com/kossakovsky/n8n-install/compare/v1.6.0...v1.7.0
[1.6.0]: https://github.com/kossakovsky/n8n-install/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/kossakovsky/n8n-install/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/kossakovsky/n8n-install/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/kossakovsky/n8n-install/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/kossakovsky/n8n-install/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/kossakovsky/n8n-install/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/kossakovsky/n8n-install/compare/v0.1.0...v1.0.0
[0.1.0]: https://github.com/kossakovsky/n8n-install/releases/tag/v0.1.0
