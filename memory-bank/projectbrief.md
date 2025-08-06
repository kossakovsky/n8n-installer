# n8n-installer Project Brief

## Project Overview
The **n8n-installer** is an open-source Docker Compose template designed to significantly simplify setting up a comprehensive, self-hosted environment for n8n and Flowise. It bundles essential supporting tools for AI development, automation, and monitoring.

## Project Purpose
This installer helps users create their own powerful, private AI workshop with capabilities to:
- Automate repetitive tasks
- Build smart assistants tailored to specific needs  
- Analyze information and gain insights
- Generate creative content

## Core Architecture
- **Foundation**: Docker Compose orchestration
- **Core Services**: n8n, Caddy, Postgres, Redis (always included)
- **Scalable Design**: n8n runs in queue mode with Redis for task management
- **Configurable Workers**: Dynamic specification of n8n workers for parallel processing

## Available Services Suite
### Always Included
- **n8n**: Low-code platform with 400+ integrations and AI components
- **Caddy**: Web proxy with automatic HTTPS/TLS
- **Postgres**: Database storage
- **Redis**: Caching and task queue management

### Optional Services (Wizard Selection)
- **Supabase**: Open-source Firebase alternative (database, auth, vectors)
- **Open WebUI**: ChatGPT-like interface for AI models and n8n agents
- **Flowise**: No-code/low-code AI agent builder
- **Qdrant**: High-performance vector store for AI
- **SearXNG**: Private metasearch engine
- **Langfuse**: AI agent performance monitoring
- **Crawl4ai**: Flexible web crawler for AI
- **Letta**: Open-source agent server and SDK
- **Weaviate**: AI-native vector database
- **Neo4j**: Graph database
- **Ollama**: Local LLM hosting
- **Prometheus/Grafana**: Monitoring and visualization

## Key Features
- **Rich Toolset**: Curated collection of open-source AI/automation tools
- **Full Control**: Self-hosted with complete data ownership
- **300+ Community Workflows**: Optional import of ready-made automation templates
- **Pre-installed Libraries**: cheerio, axios, moment, lodash for n8n custom JavaScript
- **Managed HTTPS**: Automatic SSL certificate handling via Caddy
- **Comprehensive Monitoring**: Built-in performance tracking capabilities

## Installation Requirements
- **Domain**: Registered domain with wildcard DNS A-record configured
- **Server**: Ubuntu 24.04 LTS, 64-bit minimum
- **Resources**: 
  - Full setup: 8GB RAM / 4 CPU cores / 60GB disk
  - Minimal (n8n + Flowise): 4GB RAM / 2 CPU cores / 30GB disk

## Current Status
- **Repository**: Active development on `develop` branch
- **State**: Clean working tree, up to date with origin
- **Architecture**: Mature, production-ready template system
- **Community**: Active with forum support and contribution tracking

## Technical Foundation
- **Platform**: Docker/Docker Compose
- **Languages**: Shell scripting, Python utilities, JSON configurations
- **Deployment**: Automated installation with interactive wizard
- **Updates**: Automated update mechanism with version management
- **Cleanup**: Built-in Docker maintenance utilities
