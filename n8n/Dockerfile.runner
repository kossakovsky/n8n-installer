FROM n8nio/runners:stable

USER root

# Install npm packages that can be used in Code nodes
# These must match NODE_FUNCTION_ALLOW_EXTERNAL in n8n-task-runners.json
# Note: n8nio/runners uses pnpm, not npm
RUN pnpm add cheerio axios moment lodash

# Copy task runner configuration
COPY n8n-task-runners.json /etc/n8n-task-runners.json

USER runner
