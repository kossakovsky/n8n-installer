# Service Routing & Auth Map (from current Caddyfile)

| Service           | Container:Port         | Hostname env          | Auth expectation                                     | Notes for Traefik                                                     |
| ----------------- | ---------------------- | --------------------- | ---------------------------------------------------- | --------------------------------------------------------------------- |
| n8n               | `n8n:5678`             | `N8N_HOSTNAME`        | App auth                                             | Preserve `/healthz` check; webhook URL uses https when hostname set.  |
| Open WebUI        | `open-webui:8080`      | `WEBUI_HOSTNAME`      | App auth                                             | Simple HTTP router.                                                   |
| Flowise           | `flowise:3001`         | `FLOWISE_HOSTNAME`    | App auth                                             | Basic reverse proxy.                                                  |
| Dify              | `nginx:80`             | `DIFY_HOSTNAME`       | App auth                                             | Router to nginx front.                                                |
| RAGApp            | `ragapp:8000`          | `RAGAPP_HOSTNAME`     | **Basic auth** (`RAGAPP_USERNAME/PASSWORD_HASH`)     | Needs middleware for basic auth; keep `/admin`/`/docs` usable.        |
| RAGFlow           | `ragflow:80`           | `RAGFLOW_HOSTNAME`    | App auth                                             | Straight proxy.                                                       |
| Langfuse          | `langfuse-web:3000`    | `LANGFUSE_HOSTNAME`   | App auth                                             | Straight proxy.                                                       |
| Supabase (Kong)   | `kong:8000`            | `SUPABASE_HOSTNAME`   | App auth                                             | HTTP router; consider HSTS.                                           |
| Grafana           | `grafana:3000`         | `GRAFANA_HOSTNAME`    | App auth                                             | Straight proxy.                                                       |
| WAHA              | `waha:3000`            | `WAHA_HOSTNAME`       | App auth + API key                                   | Straight proxy.                                                       |
| Prometheus        | `prometheus:9090`      | `PROMETHEUS_HOSTNAME` | **Basic auth** (`PROMETHEUS_USERNAME/PASSWORD_HASH`) | Add basic-auth middleware.                                            |
| Portainer         | `portainer:9000`       | `PORTAINER_HOSTNAME`  | App auth                                             | Straight proxy.                                                       |
| Postiz            | `postiz:5000`          | `POSTIZ_HOSTNAME`     | App auth                                             | Straight proxy; env already uses https when hostname set.             |
| Postgresus        | `postgresus:4005`      | `POSTGRESUS_HOSTNAME` | None                                                 | Straight proxy.                                                       |
| Letta             | `letta:8283`           | `LETTA_HOSTNAME`      | API key                                              | Straight proxy.                                                       |
| LightRAG          | `lightrag:9621`        | `LIGHTRAG_HOSTNAME`   | **Built-in auth**                                    | Straight proxy; keep docs URL working.                                |
| Weaviate          | `weaviate:8080`        | `WEAVIATE_HOSTNAME`   | API key                                              | Straight proxy.                                                       |
| Qdrant            | `qdrant:6333`          | `QDRANT_HOSTNAME`     | API key                                              | Straight proxy; dashboard at `/dashboard`.                            |
| ComfyUI           | `comfyui:8188`         | `COMFYUI_HOSTNAME`    | **Basic auth** (`COMFYUI_USERNAME/PASSWORD_HASH`)    | Add basic-auth middleware.                                            |
| LibreTranslate    | `libretranslate:5000`  | `LT_HOSTNAME`         | **Basic auth** (`LT_USERNAME/PASSWORD_HASH`)         | Basic-auth middleware.                                                |
| Neo4j (HTTP)      | `neo4j:7474`           | `NEO4J_HOSTNAME`      | App auth                                             | HTTP router.                                                          |
| Neo4j (Bolt/WSS)  | `neo4j:7687`           | `NEO4J_HOSTNAME`      | App auth                                             | Needs Traefik TCP router with TLS/SNI or passthrough.                 |
| PaddleOCR         | `paddleocr:8080`       | `PADDLEOCR_HOSTNAME`  | **Basic auth** (`PADDLEOCR_USERNAME/PASSWORD_HASH`)  | Basic-auth middleware.                                                |
| Docling           | `docling:5001`         | `DOCLING_HOSTNAME`    | **Basic auth** (`DOCLING_USERNAME/PASSWORD_HASH`)    | Basic-auth middleware; `/ui` + `/docs`.                               |
| Welcome page      | `welcome` static files | `WELCOME_HOSTNAME`    | **Basic auth** (`WELCOME_USERNAME/PASSWORD_HASH`)    | Needs new static file server container for Traefik.                   |
| SearXNG           | `searxng:8080`         | `SEARXNG_HOSTNAME`    | **Basic auth for non-private IPs**                   | Recreate path-based headers + cache headers; keep `@protected` logic. |
| Ollama API        | (commented out)        | `OLLAMA_HOSTNAME`     | None                                                 | Optional future router.                                               |
| Cloudflare Tunnel | `cloudflared`          | n/a                   | n/a                                                  | Bypasses proxy auth; docs need both proxy options.                    |

_All hostnames come from `.env` and default to `*.yourdomain.com`. Basic-auth hashes currently generated via `caddy hash-password`; this must be replaced with a proxy-agnostic bcrypt generator described in `migration-plan.md`._

## How to Consume This Map

1. **Convert to structured data.** Copy the table into a YAML/JSON file so scripts can iterate over it:

   ```yaml
   - service: n8n
     hostname_var: N8N_HOSTNAME
     target: http://n8n:5678
     auth: none
   - service: prometheus
     hostname_var: PROMETHEUS_HOSTNAME
     target: http://prometheus:9090
     auth: basic
     auth_env:
       user: PROMETHEUS_USERNAME
       hash: PROMETHEUS_PASSWORD_HASH
   ```

2. **Generate Traefik routers.** For each entry, render:

   ```yaml
   http:
     routers:
       prometheus:
         rule: "Host(`${PROMETHEUS_HOSTNAME}`)"
         entryPoints: ["websecure"]
         service: prometheus-svc
         middlewares: ["auth-prometheus","secure-headers"]
         tls:
           certResolver: ${TRAEFIK_CERT_RESOLVER:-acme}
     services:
       prometheus-svc:
         loadBalancer:
           servers:
             - url: "http://prometheus:9090"
   ```

   Middlewares referenced above are defined once (see `sample-scripts/traefik.dynamic.example.yml`).
3. **Generate Caddyfile blocks.** Use the same data to render `{$PROMETHEUS_HOSTNAME}` blocks and reuse hashed credentials.
4. **TCP routing.** For Neo4j Bolt, use `tcp.routers` with `HostSNI` matching `NEO4J_HOSTNAME` and enable TLS passthrough, as shown in the sample dynamic file.

By deriving both proxy configs from this map, we avoid drift and guarantee that every hostname/auth combination stays in sync.
