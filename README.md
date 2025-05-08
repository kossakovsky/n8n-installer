# n8n Ecosystem Installer

**n8n Ecosystem Installer** is an open, docker compose template designed to significantly simplify the setup of a comprehensive development environment centered around n8n and Flowise. It bundles essential supporting tools like Open WebUI (as an interface for n8n agents), Supabase (database, vector store, auth), Qdrant (high-performance vector store), Langfuse (LLM observability), SearXNG (private metasearch), Grafana/Prometheus (monitoring), Crawl4ai (web crawling), and Caddy (managed HTTPS).

This is Cole's version with a couple of improvements and the addition of Supabase, Open WebUI, Flowise, Langfuse, SearXNG, and Caddy!
Also, the RAG AI Agent workflows from the video will be automatically in your
n8n instance if you use this setup instead of the base one provided by n8n! Note: these workflows might require external LLM API keys.
Also, you have the option during setup to automatically import over 300 community workflows into your n8n instance!

## Important Links

- Forked from [coleam00/local-ai-packaged](https://github.com/coleam00/local-ai-packaged)

- [Original Starter Kit](https://github.com/n8n-io/self-hosted-ai-starter-kit) by the n8n team

- [Community](https://thinktank.ottomator.ai/c/local-ai/18) forum over in the oTTomator Think Tank

- [GitHub Kanban board](https://github.com/users/coleam00/projects/2/views/1) for feature implementation and bug squashing.

- Download my N8N + OpenWebUI integration [directly on the Open WebUI site.](https://openwebui.com/f/coleam/n8n_pipe/) (more instructions below)

### What's included

✅ [**Self-hosted n8n**](https://n8n.io/) - Low-code platform with over 400
integrations and advanced AI components

✅ [**Supabase**](https://supabase.com/) - Open source database as a service -
most widely used database for AI agents

✅ [**Open WebUI**](https://openwebui.com/) - ChatGPT-like interface to
privately interact with your local models and N8N agents

✅ [**Flowise**](https://flowiseai.com/) - No/low code AI agent
builder that pairs very well with n8n

✅ [**Qdrant**](https://qdrant.tech/) - Open source, high performance vector
store with an comprehensive API. Even though you can use Supabase for RAG, this was
kept unlike Postgres since it's faster than Supabase so sometimes is the better option.

✅ [**SearXNG**](https://searxng.org/) - Open source, free internet metasearch engine which aggregates
results from up to 229 search services. Users are neither tracked nor profiled, hence the fit with the local AI package.

✅ [**Caddy**](https://caddyserver.com/) - Managed HTTPS/TLS for custom domains

✅ [**Langfuse**](https://langfuse.com/) - Open source LLM engineering platform for agent observability

✅ [**Crawl4ai**](https://github.com/Alfresco/crawl4ai) - Flexible web crawler designed for AI data extraction workflows.

✅ [**Prometheus**](https://prometheus.io/) - Open source monitoring and alerting toolkit.

✅ [**Grafana**](https://grafana.com/) - Open source platform for monitoring and observability, often used with Prometheus.

## Prerequisites

Before you begin, make sure you have the following software installed:

- [Python](https://www.python.org/downloads/) - Required to run the setup script
- [Git/GitHub Desktop](https://desktop.github.com/) - For easy repository management
- [Docker/Docker Desktop](https://www.docker.com/products/docker-desktop/) - Required to run all services

## Installation

### Prerequisites before Installation

1.  **Domain Name:** You need a registered domain name (e.g., `yourdomain.com`).
2.  **DNS Configuration:** Before running the installation script, you **must** configure the following DNS A-record(s) for your domain, pointing to the public IP address of the server where you intend to install the n8n ecosystem. Replace `yourdomain.com` with your actual domain:

    - **Wildcard Record (Required):**
      `A *.yourdomain.com` -> `YOUR_SERVER_IP`
    - **Apex/Root Domain Record (Recommended, if you plan to use `yourdomain.com` directly for any service or a landing page):**
      `A yourdomain.com` -> `YOUR_SERVER_IP`

3.  **Server:** A Linux server (Ubuntu 24.04 LTS x64 recommended and tested). The installation was tested on a machine with **8 GB Memory / 4 Intel vCPUs / 120 GB Disk**.

### Running the Installer

The recommended way to install is using the provided main installation script. Connect to your server via SSH and run:

```bash
git clone https://github.com/kossakovsky/n8n-installer && cd n8n-installer && bash ./scripts/install.sh
```

This single command automates the entire setup process, including:

- System preparation (updates, firewall configuration with UFW, Fail2Ban setup for brute-force protection).
- Docker and Docker Compose installation.
- Generation of the `.env` configuration file with necessary secrets and your domain settings.
- Launching all the services using Docker Compose.

During the installation, the script will prompt you for:

1.  Your **primary domain name** (Required, e.g., `yourdomain.com`). This is the domain for which you've configured the wildcard DNS A-record.
2.  Your **email address** (Required, used for service logins like Flowise, Supabase dashboard, Grafana, etc., and crucial for Let's Encrypt SSL certificates).
3.  An optional **OpenAI API key** (Not required, used by Supabase AI features and Crawl4ai if provided. Press Enter to skip).
4.  Whether you want to **import ~300 ready-made n8n community workflows** (y/n, Optional. This can take around 20-30 minutes depending on your server and network).

Upon successful completion, the script will display a summary report containing the access URLs and credentials for the deployed services.

> [!NOTE]
> The `install.sh` script handles the creation and population of the `.env` file based on `.env.example` and the information you provide. You typically do not need to manually create or edit this file unless making advanced customizations _after_ the initial setup.

The script will generate secure values for necessary secrets like:

- `N8N_ENCRYPTION_KEY`
- `N8N_USER_MANAGEMENT_JWT_SECRET`
- `POSTGRES_PASSWORD`
- `JWT_SECRET`
- `ANON_KEY` (derived from JWT_SECRET)
- `SERVICE_ROLE_KEY` (derived from JWT_SECRET)
- `DASHBOARD_PASSWORD`
- `CLICKHOUSE_PASSWORD`
- `MINIO_ROOT_PASSWORD`
- `LANGFUSE_SALT`
- `NEXTAUTH_SECRET`
- `ENCRYPTION_KEY` (Langfuse)
- `GRAFANA_ADMIN_PASSWORD`
- And others...

> The installation script handles the generation of these secrets automatically.

The script will also configure hostnames in the `.env` file based on the domain you provide, for example:

- `N8N_HOSTNAME=n8n.yourdomain.com`
- `WEBUI_HOSTNAME=webui.yourdomain.com` (Note: The example in the original README used `openwebui.yourdomain.com` for the variable `WEBUI_HOSTNAME`, ensure consistency with your `.env` and `Caddyfile` if `WEBUI_HOSTNAME` is indeed the variable used for Open WebUI)
- `FLOWISE_HOSTNAME=flowise.yourdomain.com`
- `SUPABASE_HOSTNAME=supabase.yourdomain.com`
- `SEARXNG_HOSTNAME=searxng.yourdomain.com`
- `LANGFUSE_HOSTNAME=langfuse.yourdomain.com`
- `GRAFANA_HOSTNAME=grafana.yourdomain.com`
- `PROMETHEUS_HOSTNAME=prometheus.yourdomain.com`
- `LETSENCRYPT_EMAIL=your-email-address` (filled with the email you provide)

Service Startup

The `install.sh` script automatically starts all services using Docker Compose after the configuration is complete. You generally do not need to start services manually after the initial installation. If you need to restart services after stopping them manually, the `scripts/04_run_services.sh` script can be used, or you can manage them via standard `docker compose` commands (though using the provided scripts is recommended).

## Deploying to the Cloud

### Prerequisites for the below steps

- Linux machine (preferably Unbuntu) with Nano, Git, and Docker installed

## ⚡️ Quick start and usage

The main component of the starter kit is a docker compose file
pre-configured with network and disk so there isn't much else you need to
install. After completing the installation steps above, follow the steps below
to get started.

1. Open <http://localhost:5678/> in your browser to set up n8n. You'll only
   have to do this once. You are NOT creating an account with n8n in the setup here,
   it is only a local account for your instance!
2. Open the included workflow:
   <http://localhost:5678/workflow/vTN9y2dLXqTiDfPT>
3. Create credentials for every service:

   Postgres (through Supabase): use DB, username, and password from .env. IMPORTANT: Host is 'db'
   (name of the Supabase Postgres service within the Docker network).

   Qdrant URL: http://qdrant:6333 (API key can be whatever since this is running locally)

   Google Drive: Follow [this guide from n8n](https://docs.n8n.io/integrations/builtin/credentials/google/).
   Don't use localhost for the redirect URI, just use another domain you have, it will still work!
   Alternatively, you can set up [local file triggers](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.localfiletrigger/).

4. Select **Test workflow** to start running the workflow.
5. Make sure to toggle the workflow as active and copy the "Production" webhook URL!
6. Open <http://localhost:3000/> in your browser to set up Open WebUI.
   You'll only have to do this once. You are NOT creating an account with Open WebUI in the
   setup here, it is only a local account for your instance!
7. Go to Workspace -> Functions -> Add Function -> Give name + description then paste in
   the code from `n8n_pipe.py`

   The function is also [published here on Open WebUI's site](https://openwebui.com/f/coleam/n8n_pipe/).

8. Click on the gear icon and set the n8n_url to the production URL for the webhook
   you copied in a previous step.
9. Toggle the function on and now it will be available in your model dropdown in the top left!

To open n8n at any time, visit <http://localhost:5678/> in your browser.
To open Open WebUI at any time, visit <http://localhost:3000/>.

With your n8n instance, you'll have access to over 400 integrations and a
suite of basic and advanced AI nodes such as
[AI Agent](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.agent/),
[Text classifier](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.text-classifier/),
and [Information Extractor](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.information-extractor/)
nodes. Remember to use Qdrant or Supabase as your vector store. If you wish to use language models, you can configure the n8n instance, assuming you have an LLM instance running separately.

> [!NOTE]
> This starter kit is designed to help you get started with
> workflows. While it's not fully optimized for production environments, it
> This installer is designed to help you get started quickly with n8n and related tools. While it's not fully optimized for production environments, it
> combines robust components that work well together for proof-of-concept
> projects. You can customize it to meet your specific needs

## Upgrading

To update all containers to their latest versions (n8n, Open WebUI, etc.), run these commands:
and pull the latest changes from the repository, use the update script:

```bash
sudo bash ./scripts/update.sh
```

This script will:

1.  Pull the latest changes from the Git repository.
2.  Stop the currently running services using `docker compose down`.
3.  Pull the latest Docker images for all services using `docker compose pull`.
4.  Ask if you want to re-run the n8n workflow import (useful if new workflows were added).
5.  Restart the services using the `scripts/04_run_services.sh` script.

## Troubleshooting

Here are solutions to common issues you might encounter:

### Supabase Issues

- **Supabase Pooler Restarting**: If the supabase-pooler container keeps restarting itself, follow the instructions in [this GitHub issue](https://github.com/supabase/supabase/issues/30210#issuecomment-2456955578).

- **Supabase Analytics Startup Failure**: If the supabase-analytics container fails to start after changing your Postgres password, delete the folder `supabase/docker/volumes/db/data`.

- **If using Docker Desktop**: Go into the Docker settings and make sure "Expose daemon on tcp://localhost:2375 without TLS" is turned on

- **Supabase Service Unavailable** - Make sure you don't have an "@" character in your Postgres password! If the connection to the kong container is working (the container logs say it is receiving requests from n8n) but n8n says it cannot connect, this is generally the problem from what the community has shared. Other characters might not be allowed too, the @ symbol is just the one I know for sure!

## 👓 Recommended reading

n8n is full of useful content for getting started quickly with its AI concepts
and nodes. If you run into an issue, go to [support](#support).

- [AI agents for developers: from theory to practice with n8n](https://blog.n8n.io/ai-agents/)
- [Tutorial: Build an AI workflow in n8n](https://docs.n8n.io/advanced-ai/intro-tutorial/)
- [Langchain Concepts in n8n](https://docs.n8n.io/advanced-ai/langchain/langchain-n8n/)
- [Demonstration of key differences between agents and chains](https://docs.n8n.io/advanced-ai/examples/agent-chain-comparison/)
- [What are vector databases?](https://docs.n8n.io/advanced-ai/examples/understand-vector-databases/)

## 🎥 Video walkthrough

- [Cole's Guide to the Local AI Starter Kit](https://youtu.be/pOsO40HSbOo)

## 🛍️ More AI templates

For more AI workflow ideas, visit the [**official n8n AI template
gallery**](https://n8n.io/workflows/?categories=AI). From each workflow,
select the **Use workflow** button to automatically import the workflow into
your local n8n instance.

### Learn AI key concepts

- [AI Agent Chat](https://n8n.io/workflows/1954-ai-agent-chat/)
- [AI chat with any data source (using the n8n workflow too)](https://n8n.io/workflows/2026-ai-chat-with-any-data-source-using-the-n8n-workflow-tool/)
- [Chat with OpenAI Assistant (by adding a memory)](https://n8n.io/workflows/2098-chat-with-openai-assistant-by-adding-a-memory/)
- [Use an open-source LLM (via HuggingFace)](https://n8n.io/workflows/1980-use-an-open-source-llm-via-huggingface/)
- [Chat with PDF docs using AI (quoting sources)](https://n8n.io/workflows/2165-chat-with-pdf-docs-using-ai-quoting-sources/)
- [AI agent that can scrape webpages](https://n8n.io/workflows/2006-ai-agent-that-can-scrape-webpages/)

### Local AI templates

- [Tax Code Assistant](https://n8n.io/workflows/2341-build-a-tax-code-assistant-with-qdrant-mistralai-and-openai/)
- [Breakdown Documents into Study Notes with MistralAI and Qdrant](https://n8n.io/workflows/2339-breakdown-documents-into-study-notes-using-templating-mistralai-and-qdrant/)
- [Financial Documents Assistant using Qdrant and](https://n8n.io/workflows/2335-build-a-financial-documents-assistant-using-qdrant-and-mistralai/) [Mistral.ai](http://mistral.ai/)
- [Recipe Recommendations with Qdrant and Mistral](https://n8n.io/workflows/2333-recipe-recommendations-with-qdrant-and-mistral/)

### Example AI templates (May require external APIs or separate local model setup)

## Tips & tricks

### Accessing local files

The starter kit will create a shared folder (by default,
The installer will create a shared folder (by default,
located in the same directory) which is mounted to the n8n container and
allows n8n to access files on disk. This folder within the n8n container is
located at `/data/shared` -- this is the path you'll need to use in nodes that
interact with the local filesystem.

**Nodes that interact with the local filesystem**

- [Read/Write Files from Disk](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.filesreadwrite/)
- [Local File Trigger](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.localfiletrigger/)
- [Execute Command](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.executecommand/)

## 📜 License

This project (originally created by the n8n team, link at the top of the README) is licensed under the Apache License 2.0 - see the
[LICENSE](LICENSE) file for details.

## Monitoring n8n with Prometheus and Grafana

Prometheus and Grafana are included for monitoring your n8n instance.

- Prometheus: http://localhost:9090/ or https://prometheus.a2.fyi/
- Grafana: http://localhost:3002/ or https://grafana.a2.fyi/ (default admin password is set in `.env`)

**To add n8n metrics:**

- n8n exposes metrics at `http://n8n:5678/metrics` (if not, see n8n docs for enabling Prometheus metrics).
- Prometheus is pre-configured to scrape n8n metrics.
- Grafana can be configured to use Prometheus as a data source (default URL: `http://prometheus:9090`).

**Default credentials for Grafana:**

- Username: admin
- Password: (set in `.env` as `GRAFANA_ADMIN_PASSWORD`)

You can import community dashboards for n8n or create your own!
