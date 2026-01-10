# Caddy Addons

This directory allows you to extend or override Caddy configuration without modifying the main `Caddyfile`.

All `.conf` files in this directory are automatically imported via `import /etc/caddy/addons/*.conf` at the end of the main Caddyfile.

## Use Cases

- Custom TLS certificates (corporate/internal CA)
- Additional reverse proxy rules
- Custom headers or middleware
- Rate limiting or access control

## Custom TLS Certificates

For corporate/internal deployments where Let's Encrypt is not available, you can use your own certificates.

### Quick Setup

1. Place your certificates in the `certs/` directory:
   ```bash
   cp /path/to/your/cert.crt ./certs/wildcard.crt
   cp /path/to/your/key.key ./certs/wildcard.key
   ```

2. Run the setup script:
   ```bash
   make setup-tls
   ```

3. Restart Caddy:
   ```bash
   docker compose -p localai restart caddy
   ```

### Manual Setup

1. Copy the example file:
   ```bash
   cp caddy-addon/custom-tls.conf.example caddy-addon/custom-tls.conf
   ```

2. Edit `custom-tls.conf` with your hostnames and certificate paths

3. Place certificates in `certs/` directory

4. Restart Caddy:
   ```bash
   docker compose -p localai restart caddy
   ```

## How Site Override Works

When you define a site block in an addon file with the same hostname as the main Caddyfile, Caddy will use **both** configurations. To completely override a site, use the exact same hostname.

Example: To override `n8n.yourdomain.com` with a custom certificate:

```
# caddy-addon/custom-tls.conf
n8n.internal.company.com {
    tls /etc/caddy/certs/wildcard.crt /etc/caddy/certs/wildcard.key
    reverse_proxy n8n:5678
}
```

Make sure your `.env` file has `N8N_HOSTNAME=n8n.internal.company.com`.

## File Structure

```
caddy-addon/
├── .gitkeep                    # Keeps directory in git
├── README.md                   # This file
├── custom-tls.conf.example     # Example for custom certificates
└── custom-tls.conf             # Your custom config (gitignored)

certs/
├── .gitkeep                    # Keeps directory in git
├── wildcard.crt                # Your certificate (gitignored)
└── wildcard.key                # Your private key (gitignored)
```

## Important Notes

- Files in `caddy-addon/*.conf` are gitignored (preserved during updates)
- Files in `certs/` are gitignored (certificates are not committed)
- Example files (`*.example`) are tracked in git
- Caddy validates configuration on startup - check logs if it fails:
  ```bash
  docker compose -p localai logs caddy
  ```

## Caddy Documentation

- [Caddyfile Syntax](https://caddyserver.com/docs/caddyfile)
- [TLS Directive](https://caddyserver.com/docs/caddyfile/directives/tls)
- [Reverse Proxy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
