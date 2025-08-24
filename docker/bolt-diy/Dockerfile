FROM node:20-slim

WORKDIR /app

# Install git and required libraries
RUN apt-get update && apt-get install -y git libatomic1 && \
    rm -rf /var/lib/apt/lists/*

RUN git clone -b stable --depth 1 https://github.com/stackblitz-labs/bolt.diy.git .

# Install pnpm and dependencies
RUN npm install -g pnpm@9.15.9
RUN pnpm install --frozen-lockfile

# Create startup script that patches vite.config.ts with the actual hostname
RUN cat > /app/start.sh << 'EOF'
#!/bin/bash
# Extract domain from BOLT_HOSTNAME (e.g., bolt.example.com -> .example.com)
if [ ! -z "$BOLT_HOSTNAME" ]; then
  DOMAIN=$(echo $BOLT_HOSTNAME | sed 's/^[^.]*\./\./')
  echo "Configuring Vite for hostname: $BOLT_HOSTNAME and domain: $DOMAIN"
  sed -i "/return {/a\    server: { host: \"0.0.0.0\", port: 5173, strictPort: false, allowedHosts: [\"$BOLT_HOSTNAME\", \"$DOMAIN\", \"localhost\"] }," vite.config.ts
else
  echo "No BOLT_HOSTNAME set, using default config"
  sed -i '/return {/a\    server: { host: "0.0.0.0", port: 5173, strictPort: false },' vite.config.ts
fi
exec pnpm run dev --host 0.0.0.0
EOF

RUN chmod +x /app/start.sh

EXPOSE 5173

CMD ["/app/start.sh"]
