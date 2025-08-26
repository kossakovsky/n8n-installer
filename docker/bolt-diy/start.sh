#!/bin/bash
set -euo pipefail

echo "==============================================="
echo "Starting bolt.diy"
echo "==============================================="
echo "External Access: https://${BOLT_HOSTNAME:-localhost}"
echo "Internal Port: 5173"
echo "==============================================="

# Patch vite.config.ts if BOLT_HOSTNAME is set and patch not already applied
if [ ! -z "${BOLT_HOSTNAME:-}" ]; then
  # Check if already patched
  if ! grep -q "allowedHosts:" vite.config.ts; then
    echo "Patching vite.config.ts for hostname: ${BOLT_HOSTNAME}"
    sed -i '/^export default defineConfig((config) => {$/,/^  return {$/{ /^  return {$/a\    server: { host: "0.0.0.0", port: 5173, strictPort: false, hmr: { clientPort: 443, protocol: "wss", host: "'"${BOLT_HOSTNAME}"'" }, allowedHosts: ["'"${BOLT_HOSTNAME}"'", "localhost"] },
}' vite.config.ts
    echo "Patch applied successfully"
  else
    echo "vite.config.ts already patched, skipping"
  fi
fi

# Start Vite dev server
exec pnpm run dev --host 0.0.0.0
