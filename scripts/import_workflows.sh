#!/bin/sh
# Import n8n workflows and credentials from backup directory
# This script runs inside the n8n-import container

# Exit if neither import flag is set
if [ "$RUN_N8N_IMPORT" != "true" ] && [ "$FORCE_IMPORT" != "true" ]; then
  echo 'Skipping n8n import based on environment variables.'
  exit 0
fi

set -e

# Import credentials first
echo 'Importing credentials...'
CRED_FILES=$(find /backup/credentials -maxdepth 1 -type f -not -name '.gitkeep' 2>/dev/null || true)
if [ -n "$CRED_FILES" ]; then
  CRED_COUNT=$(echo "$CRED_FILES" | wc -l | tr -d ' ')
  CURRENT=0
  echo "$CRED_FILES" | while IFS= read -r file; do
    CURRENT=$((CURRENT + 1))
    filename=$(basename "$file")
    echo "[$CURRENT/$CRED_COUNT] Importing credential: $filename"
    n8n import:credentials --input="$file" 2>/dev/null || echo "  Error importing: $filename"
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

# Apply limit if IMPORT_LIMIT is set
if [ -n "$IMPORT_LIMIT" ] && [ "$IMPORT_LIMIT" -gt 0 ] 2>/dev/null; then
  WORKFLOW_FILES=$(echo "$WORKFLOW_FILES" | head -n "$IMPORT_LIMIT")
  TOTAL=$(echo "$WORKFLOW_FILES" | wc -l | tr -d ' ')
  echo "Found $TOTAL_FOUND workflows, importing first $TOTAL (limit: $IMPORT_LIMIT)"
else
  TOTAL=$TOTAL_FOUND
  echo "Found $TOTAL workflows to import"
fi
echo ''

# Use a counter file since pipes create subshells
COUNTER_FILE=$(mktemp)
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

rm -f "$COUNTER_FILE"

echo ''
echo 'Import complete!'
