# Add this section to README.md after the "Quick Start" section

## 🔒 Secure Access with Cloudflare Tunnel (Optional)

Cloudflare Tunnel provides zero-trust access to your services without exposing any ports on your server. All traffic is routed through Cloudflare's secure network, providing DDoS protection and hiding your server's IP address.

### ⚠️ Important Architecture Note

Cloudflare Tunnel **bypasses Caddy** and connects directly to your services. This means:
- You get Cloudflare's security features (DDoS protection, Web Application Firewall, etc.)
- You lose Caddy's authentication features (basic auth for Prometheus, Grafana, etc.)
- Each service needs its own public hostname configuration in Cloudflare

### Benefits
- **No exposed ports** - Ports 80/443 can be completely closed on your firewall
- **DDoS protection** - Built-in Cloudflare protection
- **IP hiding** - Your server's real IP is never exposed
- **Zero-trust security** - Optional Cloudflare Access integration
- **No public IP required** - Works on private networks

### Setup Instructions

#### 1. Create a Cloudflare Tunnel

1. Go to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to **Access** → **Tunnels**
3. Click **Create a tunnel**
4. Choose **Cloudflared** connector
5. Name your tunnel (e.g., "n8n-install")
6. Copy the tunnel token (you'll need this during installation)

#### 2. Configure Public Hostnames

In the tunnel configuration, you need to create a public hostname for **each service** you want to expose. Click **Add a public hostname** for each entry:

| Service        | Public Hostname           | Service URL                | Notes                          |
| -------------- | ------------------------- | -------------------------- | ------------------------------ |
| **n8n**        | n8n.yourdomain.com        | `http://n8n:5678`          | Workflow automation            |
| **Flowise**    | flowise.yourdomain.com    | `http://flowise:3001`      | LangChain UI                   |
| **Dify**       | dify.yourdomain.com       | `http://nginx:80`          | AI application platform        |
| **Open WebUI** | webui.yourdomain.com      | `http://open-webui:8080`   | Chat interface                 |
| **Langfuse**   | langfuse.yourdomain.com   | `http://langfuse-web:3000` | LLM observability              |
| **Supabase**   | supabase.yourdomain.com   | `http://kong:8000`         | Backend as a Service           |
| **Grafana**    | grafana.yourdomain.com    | `http://grafana:3000`      | Metrics dashboard (⚠️ No auth)  |
| **Prometheus** | prometheus.yourdomain.com | `http://prometheus:9090`   | Metrics collection (⚠️ No auth) |
| **Portainer**  | portainer.yourdomain.com  | `http://portainer:9000`    | Docker management              |
| **Letta**      | letta.yourdomain.com      | `http://letta:8283`        | Memory management              |
| **Weaviate**   | weaviate.yourdomain.com   | `http://weaviate:8080`     | Vector database                |
| **Qdrant**     | qdrant.yourdomain.com     | `http://qdrant:6333`       | Vector database                |
| **ComfyUI**    | comfyui.yourdomain.com    | `http://comfyui:8188`      | Image generation (⚠️ No auth)   |
| **Neo4j**      | neo4j.yourdomain.com      | `http://neo4j:7474`        | Graph database                 |
| **SearXNG**    | searxng.yourdomain.com    | `http://searxng:8080`      | Private search (⚠️ No auth)     |

**⚠️ Security Warning:** Services marked with "No auth" normally have basic authentication through Caddy. When using Cloudflare Tunnel, you should:
- Enable [Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/applications/) for these services, OR
- Keep them internal only (don't create public hostnames for them)

#### 3. DNS Configuration

When you create public hostnames in the tunnel configuration, Cloudflare automatically creates the necessary DNS records. These will appear in your DNS dashboard as CNAME records pointing to the tunnel, with **Proxy status ON** (orange cloud).

**Note:** If DNS records aren't created automatically:
1. Go to your domain's DNS settings in Cloudflare
2. Add CNAME records manually:
   - **Name**: Service subdomain (e.g., `n8n`)
   - **Target**: Your tunnel ID (shown in tunnel dashboard)
   - **Proxy status**: ON (orange cloud)

#### 4. Install with Tunnel Support

1. Run the n8n-install as normal:
   ```bash
   sudo bash ./scripts/install.sh
   ```
2. When prompted for **Cloudflare Tunnel Token**, paste your token
3. In the Service Selection Wizard, select **Cloudflare Tunnel** to enable the service
4. Complete the rest of the installation

Note: Providing the token alone does not auto-enable the tunnel; you must enable the "cloudflare-tunnel" profile in the wizard (or add it to `COMPOSE_PROFILES`).

#### 5. Secure Your VPS (Recommended)

After confirming services work through the tunnel:

```bash
# Close web ports (UFW example)
sudo ufw delete allow 80/tcp
sudo ufw delete allow 443/tcp
sudo ufw delete allow 7687/tcp
sudo ufw reload

# Verify only SSH remains open
sudo ufw status
```

### Choosing Between Caddy and Cloudflare Tunnel

You have two options for accessing your services:

| Method                  | Pros                                                                                     | Cons                                                                                      | Best For                |
| ----------------------- | ---------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- | ----------------------- |
| **Caddy (Traditional)** | • Caddy auth features work<br>• Simple subdomain setup<br>• No Cloudflare account needed | • Requires open ports<br>• Server IP exposed<br>• No DDoS protection                      | Local/trusted networks  |
| **Cloudflare Tunnel**   | • No open ports<br>• DDoS protection<br>• IP hiding<br>• Global CDN                      | • Requires Cloudflare account<br>• Loses Caddy auth<br>• Each service needs configuration | Internet-facing servers |

### Adding Cloudflare Access (Optional but Recommended)

For services that lose Caddy's basic auth protection, you can add Cloudflare Access:

1. In Cloudflare Zero Trust → Access → Applications
2. Click **Add an application**
3. Select **Self-hosted**
4. Configure:
   - **Application name**: e.g., "Prometheus"
   - **Application domain**: `prometheus.yourdomain.com`
   - **Identity providers**: Configure your preferred auth method
5. Create access policies (who can access the service)

### 🛡️ Advanced Security with WAF Rules

Cloudflare's Web Application Firewall (WAF) allows you to create sophisticated security rules. This is especially important for **n8n webhooks** which need to be publicly accessible but should be protected from abuse.

#### Creating IP Allow Lists

1. **Go to Cloudflare Dashboard** → **Manage Account** → **Configurations** → **Lists**
2. Click **Create new list**
3. Configure:
   - **List name**: `approved_IP_addresses`
   - **Content type**: IP Address
4. Add IP addresses:
   ```
   # Example entries:
   1.2.3.4         # Office IP
   5.6.7.0/24      # Partner network
   10.0.0.0/8      # Internal network
   ```

#### Protecting n8n Webhooks with WAF Rules

n8n webhooks need special consideration because they must be publicly accessible for external services to trigger workflows, but you want to limit who can access them.

1. **Go to your domain** → **Security** → **WAF** → **Custom rules**
2. Click **Create rule**
3. **Rule name**: "Protect n8n webhooks"
4. **Expression Builder** or use **Edit expression**:

**Example 1: Block all except approved IPs for entire domain**
```
(not ip.src in $approved_IP_addresses and http.host contains "yourdomain.com")
```
- **Action**: Block
- **Description**: Blocks all traffic except from approved IPs

**Example 2: Protect n8n but allow specific webhook paths**
```
(http.host eq "n8n.yourdomain.com" and not ip.src in $approved_IP_addresses and not http.request.uri.path contains "/webhook/")
```
- **Action**: Block
- **Description**: Protects n8n UI but allows webhook endpoints

**Example 3: Allow webhooks from specific services only**
```
(http.host eq "n8n.yourdomain.com" and http.request.uri.path contains "/webhook/" and not ip.src in $webhook_allowed_IPs)
```
- **Action**: Block
- **Description**: Webhooks only accessible from specific service IPs

**Example 4: Rate limiting for webhook endpoints**
```
(http.host eq "n8n.yourdomain.com" and http.request.uri.path contains "/webhook/")
```
- **Action**: Managed Challenge
- **Description**: Add CAPTCHA if suspicious activity detected

#### Common Security Rule Patterns

| Use Case                             | Expression                                                                                                | Action                  | Notes                                  |
| ------------------------------------ | --------------------------------------------------------------------------------------------------------- | ----------------------- | -------------------------------------- |
| **Protect webhooks (CRITICAL)**      | `(http.request.uri.path contains "/webhook" and not ip.src in $webhook_service_IPs)`                      | Block                   | Webhooks have NO auth - must restrict! |
| **Protect all services**             | `(not ip.src in $approved_IP_addresses)`                                                                  | Block                   | Strictest - only approved IPs          |
| **Geographic restrictions**          | `(ip.geoip.country ne "US" and ip.geoip.country ne "GB")`                                                 | Block                   | Allow only specific countries          |
| **Block bots on sensitive services** | `(http.host in {"prometheus.yourdomain.com" "grafana.yourdomain.com"} and cf.bot_management.score lt 30)` | Block                   | Blocks likely bots                     |
| **Moderate UI protection**           | `(not http.request.uri.path contains "/webhook" and cf.threat_score gt 30)`                               | Managed Challenge       | UI has login, less strict              |
| **Rate limit webhooks**              | `(http.request.uri.path contains "/webhook/")`                                                            | Rate Limit (10 req/min) | Additional webhook protection          |
| **Separate webhook types**           | `(http.request.uri.path contains "/webhook/stripe" and not ip.src in $stripe_IPs)`                        | Block                   | Service-specific webhook protection    |

#### Service-Specific Security Strategies

**n8n (CRITICAL - Webhooks are the highest risk):**

⚠️ **Important**: n8n webhooks have NO built-in authentication and can trigger powerful workflows. They need STRONGER protection than the UI (which has login protection).

```
# Rule 1: STRICT webhook protection - only allow from known service IPs
(http.host eq "n8n.yourdomain.com" and 
 (http.request.uri.path contains "/webhook/" or 
  http.request.uri.path contains "/webhook-test/") and 
 not ip.src in $webhook_service_IPs)
Action: Block
Note: webhook_service_IPs should ONLY contain verified service IPs (Stripe, GitHub, etc.)

# Rule 2: Moderate UI protection - has login screen protection
(http.host eq "n8n.yourdomain.com" and 
 not http.request.uri.path contains "/webhook" and
 cf.threat_score gt 30)
Action: Managed Challenge
Note: UI has login protection, so can be less strict than webhooks
```

**Why this approach:**
- **Webhooks = No Auth** = Need IP allowlisting
- **UI = Has Login** = Can use lighter protection
- **Never expose webhooks broadly** - They can trigger database changes, send emails, call APIs

**Flowise:**
```
# API endpoints from approved IPs, public chatbot access
(http.host eq "flowise.yourdomain.com" and 
 http.request.uri.path contains "/api/" and 
 not ip.src in $api_allowed_IPs)
Action: Block
```

**Monitoring Services (Grafana/Prometheus):**
```
# Strict IP allowlist for monitoring
(http.host in {"grafana.yourdomain.com" "prometheus.yourdomain.com"} and 
 not ip.src in $monitoring_team_IPs)
Action: Block
```

#### Managing Multiple IP Lists

Create separate lists for different access levels:

| List Name               | Purpose                     | Example IPs                   |
| ----------------------- | --------------------------- | ----------------------------- |
| `approved_IP_addresses` | General admin access        | Office IPs, VPN endpoints     |
| `webhook_allowed_IPs`   | Services that call webhooks | Stripe, GitHub, Slack servers |
| `monitoring_team_IPs`   | DevOps team access          | Team member home IPs          |
| `api_consumer_IPs`      | Third-party API access      | Partner service IPs           |

#### Webhook Security Best Practices

⚠️ **CRITICAL**: Webhooks are your biggest security risk! Unlike the UI which has login protection, webhooks have NO authentication and can directly execute workflows that might:
- Access your database
- Send emails/messages  
- Call external APIs with your credentials
- Modify data
- Trigger financial transactions

**Essential Protection Steps:**

1. **Never expose webhooks to the entire internet**
   - Always use IP allowlists for webhook endpoints
   - Only add IPs of services that legitimately need webhook access

2. **Create strict webhook IP allowlists**:
   ```
   $webhook_service_IPs should only contain:
   - GitHub webhook IPs: 192.30.252.0/22, 185.199.108.0/22, etc.
   - Stripe webhook IPs: 3.18.12.63, 3.130.192.231, etc.
   - Your specific partner/integration IPs
   - Your monitoring service IPs
   ```

3. **Use webhook-specific paths** in n8n:
   - Production: `/webhook/prod-[unique-id]`
   - Testing: `/webhook-test/test-[unique-id]`
   - Never use simple, guessable webhook URLs

4. **Implement webhook signatures** in n8n workflows:
   - Always verify HMAC signatures from services like GitHub/Stripe
   - Add header validation in your n8n workflows
   - Reject requests without proper signatures

5. **Create separate rules for different webhook types**:
   ```
   # Stripe webhooks - only from Stripe's published IPs
   (http.host eq "n8n.yourdomain.com" and 
    http.request.uri.path contains "/webhook/stripe" and 
    not ip.src in $stripe_webhook_IPs)
   Action: Block
   
   # Internal webhooks - only from your infrastructure
   (http.host eq "n8n.yourdomain.com" and 
    http.request.uri.path contains "/webhook/internal" and 
    not ip.src in $internal_system_IPs)
   Action: Block
   ```

6. **Add rate limiting as additional protection**:
   ```
   # Rate limit even approved webhook IPs
   (http.host eq "n8n.yourdomain.com" and 
    http.request.uri.path contains "/webhook/")
   Action: Rate Limit (10 requests per minute)
   ```

7. **Monitor webhook access closely**:
   - Check Cloudflare Analytics → Security → Events regularly
   - Set up alerts for blocked webhook attempts
   - Review which IPs are trying to access your webhooks
   - Investigate any unexpected webhook triggers

#### Testing Your Rules

1. **Use Cloudflare's Trace Tool**:
   - Go to **Account Home** → **Trace**
   - Enter test URLs and IPs
   - See which rules would trigger

2. **Start with Log mode**:
   - Set initial action to "Log" instead of "Block"
   - Monitor for false positives
   - Switch to "Block" after verification

3. **Test webhook access**:
   ```bash
   # Test from allowed IP
   curl -X POST https://n8n.yourdomain.com/webhook/test-webhook
   
   # Test from non-allowed IP (should be blocked)
   curl -X POST https://n8n.yourdomain.com/admin
   ```

#### Important Considerations

- **Webhook IPs can change**: Services like GitHub, Stripe publish their webhook IP ranges - add these to your lists
- **Development vs Production**: Consider separate rules for development environments
- **Bypass for emergencies**: Keep a "break glass" rule you can quickly enable for emergency access
- **API rate limits**: Implement rate limiting on webhook endpoints to prevent abuse
- **Logging**: Enable logging on security rules to track access patterns

### Verifying Tunnel Connection

Check if the tunnel is running:
```bash
docker logs cloudflared --tail 20
```

You should see:
```
INF Registered tunnel connection connIndex=0
INF Updated to new configuration
```

### Troubleshooting

**"Too many redirects" error:**
- Make sure you're pointing to the service directly (e.g., `http://n8n:5678`), NOT to Caddy
- Verify the service URL uses HTTP, not HTTPS
- Check that DNS records have Proxy status ON (orange cloud)

**"Server not found" error:**
- Verify DNS records exist for your subdomain
- Check tunnel is healthy in Cloudflare dashboard
- Ensure tunnel token is correct in `.env`

**Services not accessible:**
- Verify tunnel status: `docker ps | grep cloudflared`
- Check tunnel logs: `docker logs cloudflared`
- Ensure the service is running: `docker ps`
- Verify service name and port in tunnel configuration

**Mixed mode (tunnel + direct access):**
- You can run both tunnel and traditional Caddy access simultaneously
- Useful for testing before closing firewall ports
- Simply keep ports 80/443 open until ready to switch fully to tunnel

### Disabling Tunnel

To disable Cloudflare Tunnel and return to Caddy-only access:

1. Remove from compose profiles:
   ```bash
   # Edit .env and remove "cloudflare-tunnel" from COMPOSE_PROFILES
   nano .env
   ```

2. Stop the tunnel and restart services:
   ```bash
   docker compose -p localai --profile cloudflare-tunnel down
   docker compose -p localai up -d
   ```

3. Re-open firewall ports if closed:
   ```bash
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw reload
   ```

### Important Notes

1. **Service-to-service communication** remains unchanged - containers still communicate directly via Docker network
2. **Ollama** is not included in the tunnel setup as it's typically used internally only
3. **Database ports** (PostgreSQL, Redis) should never be exposed through the tunnel
4. Consider using **Cloudflare Access** for any services that need authentication