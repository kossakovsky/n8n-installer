#!/bin/sh
# Import n8n workflows and credentials from backup directory
# This script runs inside the n8n-import container

# Exit if neither import flag is set
if [ "$RUN_N8N_IMPORT" != "true" ] && [ "$FORCE_IMPORT" != "true" ]; then
  echo 'Skipping n8n import based on environment variables.'
  exit 0
fi

set -e

# Temp file for counter (pipes create subshells in POSIX sh)
COUNTER_FILE=$(mktemp)
trap 'rm -f "$COUNTER_FILE"' EXIT
echo "0" > "$COUNTER_FILE"

# Import credentials first
echo 'Importing credentials...'
CRED_FILES=$(find /backup/credentials -maxdepth 1 -type f -not -name '.gitkeep' 2>/dev/null || true)
if [ -n "$CRED_FILES" ]; then
  CRED_COUNT=$(echo "$CRED_FILES" | wc -l | tr -d ' ')
  echo "0" > "$COUNTER_FILE"
  echo "$CRED_FILES" | while IFS= read -r file; do
    CURRENT=$(cat "$COUNTER_FILE")
    CURRENT=$((CURRENT + 1))
    echo "$CURRENT" > "$COUNTER_FILE"
    filename=$(basename "$file")
    printf "[%2d/%d] %s" "$CURRENT" "$CRED_COUNT" "$filename"
    if n8n import:credentials --input="$file" >/dev/null 2>&1; then
      echo " OK"
    else
      echo " FAILED"
    fi
  done
fi

# Import workflows
echo ''
echo 'Importing workflows...'
WORKFLOW_FILES=$(find /backup/workflows -maxdepth 1 -type f -not -name '.gitkeep' 2>/dev/null || true)
if [ -z "$WORKFLOW_FILES" ]; then
  echo 'No workflows found to import.'
  exit 0
fi

TOTAL_FOUND=$(echo "$WORKFLOW_FILES" | wc -l | tr -d ' ')

# Apply limit if set (e.g., make import n=10)
if [ -n "$IMPORT_LIMIT" ]; then
  WORKFLOW_FILES=$(echo "$WORKFLOW_FILES" | head -n "$IMPORT_LIMIT")
fi
TOTAL=$(echo "$WORKFLOW_FILES" | wc -l | tr -d ' ')
echo "Importing $TOTAL of $TOTAL_FOUND workflows"
echo ''

# Reset counter for workflows
echo "0" > "$COUNTER_FILE"

echo "$WORKFLOW_FILES" | while IFS= read -r file; do
  CURRENT=$(cat "$COUNTER_FILE")
  CURRENT=$((CURRENT + 1))
  echo "$CURRENT" > "$COUNTER_FILE"

  filename=$(basename "$file")
  printf "[%3d/%d] %s" "$CURRENT" "$TOTAL" "$filename"

  if n8n import:workflow --input="$file" >/dev/null 2>&1; then
    echo " OK"
  else
    echo " FAILED"
  fi
done

echo ''
echo 'Import complete!'
