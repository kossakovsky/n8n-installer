# Outline (Shadowsocks) outbound routing override

This override forces outbound HTTP(S) traffic from n8n services through an Outline/Shadowsocks proxy.

## Files

- `docker-compose.outline.yml` – Compose overlay (no secrets).
- `.env.vpn.example` – Template for Outline connection settings (secrets not committed).

## Setup

1) Create secrets file in repo root:

```bash
cp overrides/outline/.env.vpn.example .env.vpn
nano .env.vpn
```

2) Start stack with the overlay:

```bash
docker compose --env-file .env --env-file .env.vpn \
  -f docker-compose.yml -f overrides/outline/docker-compose.outline.yml up -d
```

## Verify

Check outbound IP from n8n container:

```bash
docker exec -it n8n wget -s https://ifconfig.me
```

Stop Outline to validate no direct leak:


```bash
docker stop outline
docker exec -it n8n curl -m 7 -s https://ifconfig.me
# expected: timeout / connection failure
```

## Notes

- This setup uses SOCKS5 proxying (not a full L3 VPN).

- `socks5h://` is used to proxy DNS queries through the SOCKS proxy.

- For strict transparent proxying of all TCP (even apps ignoring proxy env),
add container-level REDIRECT/TPROXY rules or host policy routing.

