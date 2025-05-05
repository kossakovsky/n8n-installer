#!/bin/sh

# Exit immediately if RUN_N8N_IMPORT is not set to true
if [ "$RUN_N8N_IMPORT" != "true" ]; then
  echo 'Skipping n8n import based on RUN_N8N_IMPORT environment variable.'
  exit 0
fi

set -e

echo 'Importing credentials...'
find /backup/credentials -maxdepth 1 -type f -not -name '.gitkeep' -print -exec sh -c '
  echo "Attempting to import credential file: $1";
  n8n import:credentials --input="$1" || echo "Error importing credential file: $1"
' sh {} \;

echo 'Importing workflows...'
find /backup/workflows -maxdepth 1 -type f -not -name '.gitkeep' -print -exec sh -c '
  echo "Attempting to import workflow file: $1";
  n8n import:workflow --input="$1" || echo "Error importing workflow file: $1"
' sh {} \;

echo 'Import process finished.' 