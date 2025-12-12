#!/bin/bash
# =============================================================================
# download_top_workflows.sh - Download popular n8n workflow templates
# =============================================================================
# Downloads the most popular workflow templates from n8n's public API,
# sorted by total views. Useful for seeding a fresh n8n installation with
# community-vetted examples.
#
# Features:
#   - Fetches workflow metadata from n8n API (paginated)
#   - Sorts by totalViews (most popular first)
#   - Removes duplicates by workflow ID
#   - Downloads full workflow JSON ready for n8n import
#   - Configurable count and output directory
#
# Usage: bash scripts/download_top_workflows.sh [count] [output_dir]
#   count      - Number of workflows to download (default: 500)
#   output_dir - Directory to save workflows (default: workflows)
#
# Examples:
#   bash scripts/download_top_workflows.sh           # Download top 500
#   bash scripts/download_top_workflows.sh 100       # Download top 100
#   bash scripts/download_top_workflows.sh 200 /tmp  # Download 200 to /tmp
# =============================================================================

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# --- Configuration ---
COUNT=${1:-500}
OUTPUT_DIR=${2:-workflows}
API_BASE="https://api.n8n.io/api/templates"
ROWS_PER_PAGE=100
MAX_PAGES=80

# --- Require dependencies ---
require_command "curl" "Please install curl to use this script."
require_command "jq" "Please install jq to use this script."

# --- Helper functions ---

# Generate a random 16-character base62 ID (like n8n workflow IDs)
generate_workflow_id() {
    cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | head -c 16
}

# Generate a UUID v4 (for versionId)
generate_version_id() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    else
        # Fallback for systems without uuidgen
        cat /proc/sys/kernel/random/uuid 2>/dev/null || \
            printf '%04x%04x-%04x-%04x-%04x-%04x%04x%04x' \
                $RANDOM $RANDOM $RANDOM $(($RANDOM & 0x0fff | 0x4000)) \
                $(($RANDOM & 0x3fff | 0x8000)) $RANDOM $RANDOM $RANDOM
    fi
}

# Convert filename slug to readable name
# "ai-agent-chat" -> "Ai agent chat"
slug_to_name() {
    local slug="$1"
    # Replace dashes with spaces, capitalize first letter only
    local with_spaces=$(echo "$slug" | sed 's/-/ /g')
    # Capitalize first character
    echo "$(echo "${with_spaces:0:1}" | tr '[:lower:]' '[:upper:]')${with_spaces:1}"
}

# --- Main ---
log_header "n8n Workflow Downloader"
log_info "Target: $COUNT most popular workflows"
log_info "Output: $OUTPUT_DIR/"

mkdir -p "$OUTPUT_DIR"

# Temporary file for metadata
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# Step 1: Fetch all workflow metadata
log_subheader "Fetching workflow metadata"

for page in $(seq 1 $MAX_PAGES); do
    result=$(curl -s "${API_BASE}/search?rows=${ROWS_PER_PAGE}&page=${page}")
    count=$(echo "$result" | jq '.workflows | length' 2>/dev/null || echo "0")

    if [ "$count" -eq 0 ] 2>/dev/null; then
        log_info "Completed at page $page (no more data)"
        break
    fi

    echo "$result" | jq -c '.workflows[] | {id, name, totalViews}' 2>/dev/null >> "$TEMP_FILE"

    if [ $((page % 10)) -eq 0 ]; then
        log_info "Fetched page $page..."
    fi
done

# Step 2: Sort by totalViews, remove duplicates, take top N
log_subheader "Selecting top $COUNT workflows"

TOP_IDS=$(cat "$TEMP_FILE" | jq -s "unique_by(.id) | sort_by(-.totalViews) | .[0:${COUNT}] | .[].id")
TOTAL=$(echo "$TOP_IDS" | wc -l | tr -d ' ')

log_info "Found $TOTAL unique workflows to download"

# Step 3: Download each workflow
log_subheader "Downloading workflows"

downloaded=0
failed=0

for id in $TOP_IDS; do
    downloaded=$((downloaded + 1))

    # Get workflow data
    workflow_data=$(curl -s "${API_BASE}/workflows/${id}")

    if echo "$workflow_data" | jq -e '.workflow' > /dev/null 2>&1; then
        # Extract name for filename (sanitize: lowercase, replace non-alphanum with dash)
        name=$(echo "$workflow_data" | jq -r '.workflow.name // "unnamed"' | \
            tr '[:upper:]' '[:lower:]' | \
            sed 's/[^a-z0-9]/-/g' | \
            sed 's/--*/-/g' | \
            sed 's/^-//;s/-$//' | \
            cut -c1-50)

        filename="${id}_${name}.json"

        # Generate n8n-compatible metadata
        workflow_name=$(slug_to_name "$name")
        workflow_id=$(generate_workflow_id)
        version_id=$(generate_version_id)

        # Extract workflow and add required metadata (name, active, id, versionId)
        echo "$workflow_data" | jq --arg name "$workflow_name" \
                                   --arg id "$workflow_id" \
                                   --arg versionId "$version_id" \
            '.workflow.workflow + {name: $name, active: false, id: $id, versionId: $versionId}' \
            > "$OUTPUT_DIR/$filename"

        if [ $((downloaded % 50)) -eq 0 ]; then
            log_info "Downloaded $downloaded/$TOTAL..."
        fi
    else
        log_warning "Failed to download workflow $id"
        failed=$((failed + 1))
    fi

    # Small delay to be nice to the API
    sleep 0.1
done

# Summary
log_divider
log_success "Download complete!"
log_info "Downloaded: $((downloaded - failed))/$TOTAL workflows"
if [ $failed -gt 0 ]; then
    log_warning "Failed: $failed"
fi
log_info "Location: $OUTPUT_DIR/"
