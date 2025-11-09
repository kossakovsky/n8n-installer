#!/bin/bash

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# Check for openssl
if ! command -v openssl &> /dev/null; then
    log_error "openssl could not be found. Please ensure it is installed and available in your PATH." >&2
    exit 1
fi

# --- Configuration ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"
TEMPLATE_FILE="$PROJECT_ROOT/.env.example"
OUTPUT_FILE="$PROJECT_ROOT/.env"
DOMAIN_PLACEHOLDER="yourdomain.com"

# Variables to generate: varName="type:length"
# Types: password (alphanum), secret (base64), hex, base64, alphanum
declare -A VARS_TO_GENERATE=(
    ["FLOWISE_PASSWORD"]="password:32"
    ["N8N_ENCRYPTION_KEY"]="secret:64" # base64 encoded, 48 bytes -> 64 chars
    ["N8N_USER_MANAGEMENT_JWT_SECRET"]="secret:64" # base64 encoded, 48 bytes -> 64 chars
    ["POSTGRES_PASSWORD"]="password:32"
    ["POSTGRES_NON_ROOT_PASSWORD"]="password:32"
    ["JWT_SECRET"]="base64:64" # 48 bytes -> 64 chars
    ["DASHBOARD_PASSWORD"]="password:32" # Supabase Dashboard
    ["CLICKHOUSE_PASSWORD"]="password:32"
    ["MINIO_ROOT_PASSWORD"]="password:32"
    ["LANGFUSE_SALT"]="secret:64" # base64 encoded, 48 bytes -> 64 chars
    ["NEXTAUTH_SECRET"]="secret:64" # base64 encoded, 48 bytes -> 64 chars
    ["ENCRYPTION_KEY"]="hex:64" # Langfuse Encryption Key (32 bytes -> 64 hex chars)
    ["GRAFANA_ADMIN_PASSWORD"]="password:32"
    # From MD file (ensure they are in template if needed)
    ["SECRET_KEY_BASE"]="base64:64" # 48 bytes -> 64 chars
    ["VAULT_ENC_KEY"]="alphanum:32"
    ["LOGFLARE_PRIVATE_ACCESS_TOKEN"]="fixed:not-in-use" # For supabase-vector, can't be empty
    ["LOGFLARE_PUBLIC_ACCESS_TOKEN"]="fixed:not-in-use" # For supabase-vector, can't be empty
    ["PROMETHEUS_PASSWORD"]="password:32" # Added Prometheus password
    ["SEARXNG_PASSWORD"]="password:32" # Added SearXNG admin password
    ["LETTA_SERVER_PASSWORD"]="password:32" # Added Letta server password
    ["LANGFUSE_INIT_USER_PASSWORD"]="password:32"
    ["LANGFUSE_INIT_PROJECT_PUBLIC_KEY"]="langfuse_pk:32"
    ["LANGFUSE_INIT_PROJECT_SECRET_KEY"]="langfuse_sk:32"
    ["WEAVIATE_API_KEY"]="secret:48" # API Key for Weaviate service (36 bytes -> 48 chars base64)
    ["QDRANT_API_KEY"]="secret:48" # API Key for Qdrant service
    ["NEO4J_AUTH_PASSWORD"]="password:32" # Added Neo4j password
    ["NEO4J_AUTH_USERNAME"]="fixed:neo4j" # Added Neo4j username
    # Dify environment variables
    ["DIFY_SECRET_KEY"]="secret:64" # Dify application secret key (maps to SECRET_KEY in Dify)
    ["COMFYUI_PASSWORD"]="password:32" # Added ComfyUI basic auth password
    ["RAGAPP_PASSWORD"]="password:32" # Added RAGApp basic auth password
    ["PADDLEOCR_PASSWORD"]="password:32" # Added PaddleOCR basic auth password
    ["LT_PASSWORD"]="password:32" # Added LibreTranslate basic auth password
    # WAHA (WhatsApp HTTP API)
    ["WAHA_DASHBOARD_PASSWORD"]="password:32"
    ["WHATSAPP_SWAGGER_PASSWORD"]="password:32"
    # RAGFlow internal credentials
    ["RAGFLOW_MYSQL_ROOT_PASSWORD"]="password:32"
    ["RAGFLOW_MINIO_ROOT_PASSWORD"]="password:32"
    ["RAGFLOW_REDIS_PASSWORD"]="password:32"
    ["RAGFLOW_ELASTICSEARCH_PASSWORD"]="password:32"
    # LightRAG credentials
    ["LIGHTRAG_PASSWORD"]="password:32"
    ["LIGHTRAG_API_KEY"]="secret:48"
    # Docling credentials
    ["DOCLING_PASSWORD"]="password:32"
)

# Initialize existing_env_vars and attempt to read .env if it exists
log_info "Initializing environment configuration..."
declare -A existing_env_vars
declare -A generated_values

if [ -f "$OUTPUT_FILE" ]; then
    log_info "Found existing $OUTPUT_FILE. Reading its values to use as defaults and preserve current settings."
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -n "$line" && ! "$line" =~ ^\s*# && "$line" == *"="* ]]; then
            varName=$(echo "$line" | cut -d'=' -f1 | xargs)
            varValue=$(echo "$line" | cut -d'=' -f2-)
            # Repeatedly unquote "value" or 'value' to get the bare value
            _tempVal="$varValue"
            while true; do
                if [[ "$_tempVal" =~ ^\"(.*)\"$ ]]; then # Check double quotes
                    _tempVal="${BASH_REMATCH[1]}"
                    continue
                fi
                if [[ "$_tempVal" =~ ^\'(.*)\'$ ]]; then # Check single quotes
                    _tempVal="${BASH_REMATCH[1]}"
                    continue
                fi
                break # No more surrounding quotes of these types
            done
            varValue="$_tempVal"
            existing_env_vars["$varName"]="$varValue"
        fi
    done < "$OUTPUT_FILE"
fi

# Install Caddy
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt install -y caddy

# Check for caddy
if ! command -v caddy &> /dev/null; then
    log_error "caddy could not be found. Please ensure it is installed and available in your PATH." >&2
    exit 1
fi

require_whiptail
# Prompt for the domain name
DOMAIN="" # Initialize DOMAIN variable

# Try to get domain from existing .env file first
# Check if USER_DOMAIN_NAME is set in existing_env_vars and is not empty
if [[ -v existing_env_vars[USER_DOMAIN_NAME] && -n "${existing_env_vars[USER_DOMAIN_NAME]}" ]]; then
    DOMAIN="${existing_env_vars[USER_DOMAIN_NAME]}"
    # Ensure this value is carried over to generated_values for writing and template processing
    # If it came from existing_env_vars, it might already be there, but this ensures it.
    generated_values["USER_DOMAIN_NAME"]="$DOMAIN"
else
    while true; do
        DOMAIN_INPUT=$(wt_input "Primary Domain" "Enter the primary domain name for your services (e.g., example.com)." "") || true

        DOMAIN_TO_USE="$DOMAIN_INPUT" # Direct assignment, no default fallback

        # Validate domain input
        if [[ -z "$DOMAIN_TO_USE" ]]; then
            wt_msg "Validation" "Domain name cannot be empty."
            continue
        fi

        # Basic check for likely invalid domain characters (very permissive)
        if [[ "$DOMAIN_TO_USE" =~ [^a-zA-Z0-9.-] ]]; then
            wt_msg "Validation" "Warning: Domain contains potentially invalid characters: '$DOMAIN_TO_USE'"
        fi
        if wt_yesno "Confirm Domain" "Use '$DOMAIN_TO_USE' as the primary domain?" "yes"; then
            DOMAIN="$DOMAIN_TO_USE" # Set the final DOMAIN variable
            generated_values["USER_DOMAIN_NAME"]="$DOMAIN" # Using USER_DOMAIN_NAME
            log_info "Domain set to '$DOMAIN'. It will be saved in .env."
            break # Confirmed, exit loop
        fi
    done
fi

# Prompt for user email
if [[ -z "${existing_env_vars[LETSENCRYPT_EMAIL]}" ]]; then
    wt_msg "Email Required" "Please enter your email address. It will be used for logins and Let's Encrypt SSL."
fi

if [[ -n "${existing_env_vars[LETSENCRYPT_EMAIL]}" ]]; then
    USER_EMAIL="${existing_env_vars[LETSENCRYPT_EMAIL]}"
else
    while true; do
        USER_EMAIL=$(wt_input "Email" "Enter your email address." "") || true

        # Validate email input
        if [[ -z "$USER_EMAIL" ]]; then
            wt_msg "Validation" "Email cannot be empty."
            continue
        fi

        # Basic email format validation
        if [[ ! "$USER_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            wt_msg "Validation" "Warning: Email format appears to be invalid: '$USER_EMAIL'"
        fi
        if wt_yesno "Confirm Email" "Use '$USER_EMAIL' as your email?" "yes"; then
            break # Confirmed, exit loop
        fi
    done
fi



log_info "Generating secrets and creating .env file..."

# --- Helper Functions ---
# Usage: gen_random <length> <characters>
gen_random() {
    local length="$1"
    local characters="$2"
    head /dev/urandom | tr -dc "$characters" | head -c "$length"
}

# Usage: gen_password <length>
gen_password() {
    gen_random "$1" 'A-Za-z0-9'
}

# Usage: gen_hex <length> (length = number of hex characters)
gen_hex() {
    local length="$1"
    local bytes=$(( (length + 1) / 2 )) # Calculate bytes needed
    openssl rand -hex "$bytes" | head -c "$length"
}

# Usage: gen_base64 <length> (length = number of base64 characters)
gen_base64() {
    local length="$1"
    # Estimate bytes needed: base64 encodes 3 bytes to 4 chars.
    # So, we need length * 3 / 4 bytes. Use ceil division.
    local bytes=$(( (length * 3 + 3) / 4 ))
    openssl rand -base64 "$bytes" | head -c "$length" # Truncate just in case
}

# Function to update or add a variable to the .env file
# Usage: _update_or_add_env_var "VAR_NAME" "var_value"
_update_or_add_env_var() {
    local var_name="$1"
    local var_value="$2"
    local tmp_env_file

    tmp_env_file=$(mktemp)
    # Ensure temp file is cleaned up if this function exits unexpectedly (though trap in main script should also cover)
    # trap 'rm -f "$tmp_env_file"' EXIT

    if [[ -f "$OUTPUT_FILE" ]]; then
        grep -v -E "^${var_name}=" "$OUTPUT_FILE" > "$tmp_env_file" || true # Allow grep to not find anything
    else
        touch "$tmp_env_file" # Create empty temp if output file doesn't exist yet
    fi

    if [[ -n "$var_value" ]]; then
        echo "${var_name}='$var_value'" >> "$tmp_env_file"
    fi
    mv "$tmp_env_file" "$OUTPUT_FILE"
    # trap - EXIT # Remove specific trap for this temp file if desired, or let main script's trap handle it.
}

# Function to generate a hash using Caddy
# Usage: local HASH=$(_generate_and_get_hash "$plain_password")
_generate_and_get_hash() {
    local plain_password="$1"
    local new_hash=""
    if [[ -n "$plain_password" ]]; then
        new_hash=$(caddy hash-password --algorithm bcrypt --plaintext "$plain_password" 2>/dev/null)
        if [[ $? -ne 0 || -z "$new_hash" ]]; then
            # Optionally, log a warning here if logging was re-enabled
            # echo "Warning: Failed to hash password for use with $1 (placeholder)" >&2
            new_hash="" # Ensure it's empty on failure
        fi
    fi
    echo "$new_hash"
}

# --- Main Logic ---

if [ ! -f "$TEMPLATE_FILE" ]; then
    log_error "Template file not found at $TEMPLATE_FILE" >&2
    exit 1
fi

# Pre-populate generated_values with non-empty values from existing_env_vars
for key_from_existing in "${!existing_env_vars[@]}"; do
    if [[ -n "${existing_env_vars[$key_from_existing]}" ]]; then
        generated_values["$key_from_existing"]="${existing_env_vars[$key_from_existing]}"
    fi
done

# Store user input values (potentially overwriting if user was re-prompted and gave new input)
generated_values["FLOWISE_USERNAME"]="$USER_EMAIL"
generated_values["DASHBOARD_USERNAME"]="$USER_EMAIL"
generated_values["LETSENCRYPT_EMAIL"]="$USER_EMAIL"
generated_values["PROMETHEUS_USERNAME"]="$USER_EMAIL"
generated_values["SEARXNG_USERNAME"]="$USER_EMAIL"
generated_values["LANGFUSE_INIT_USER_EMAIL"]="$USER_EMAIL"
generated_values["WEAVIATE_USERNAME"]="$USER_EMAIL" # Set Weaviate username for Caddy
generated_values["COMFYUI_USERNAME"]="$USER_EMAIL" # Set ComfyUI username for Caddy
generated_values["RAGAPP_USERNAME"]="$USER_EMAIL" # Set RAGApp username for Caddy
generated_values["PADDLEOCR_USERNAME"]="$USER_EMAIL" # Set PaddleOCR username for Caddy
generated_values["LT_USERNAME"]="$USER_EMAIL" # Set LibreTranslate username for Caddy
generated_values["LIGHTRAG_USERNAME"]="$USER_EMAIL" # Set LightRAG username for built-in auth
generated_values["WAHA_DASHBOARD_USERNAME"]="$USER_EMAIL" # WAHA dashboard username default
generated_values["WHATSAPP_SWAGGER_USERNAME"]="$USER_EMAIL" # WAHA swagger username default
generated_values["DOCLING_USERNAME"]="$USER_EMAIL" # Set Docling username for Caddy


# Create a temporary file for processing
TMP_ENV_FILE=$(mktemp)
# Ensure temp file is cleaned up on exit
trap 'rm -f "$TMP_ENV_FILE"' EXIT

# Track whether our custom variables were found in the template
declare -A found_vars
found_vars["FLOWISE_USERNAME"]=0
found_vars["DASHBOARD_USERNAME"]=0
found_vars["LETSENCRYPT_EMAIL"]=0
found_vars["RUN_N8N_IMPORT"]=0
found_vars["PROMETHEUS_USERNAME"]=0
found_vars["SEARXNG_USERNAME"]=0
found_vars["OPENAI_API_KEY"]=0
found_vars["LANGFUSE_INIT_USER_EMAIL"]=0
found_vars["N8N_WORKER_COUNT"]=0
found_vars["WEAVIATE_USERNAME"]=0
found_vars["NEO4J_AUTH_USERNAME"]=0
found_vars["COMFYUI_USERNAME"]=0
found_vars["RAGAPP_USERNAME"]=0
found_vars["PADDLEOCR_USERNAME"]=0
found_vars["DOCLING_USERNAME"]=0
found_vars["LT_USERNAME"]=0
found_vars["LIGHTRAG_USERNAME"]=0
found_vars["WAHA_DASHBOARD_USERNAME"]=0
found_vars["WHATSAPP_SWAGGER_USERNAME"]=0

# Read template, substitute domain, generate initial values
while IFS= read -r line || [[ -n "$line" ]]; do
    # Substitute domain placeholder
    processed_line=$(echo "$line" | sed "s/$DOMAIN_PLACEHOLDER/$DOMAIN/g")

    # Check if it's a variable assignment line (non-empty, not comment, contains '=')
    if [[ -n "$processed_line" && ! "$processed_line" =~ ^\s*# && "$processed_line" == *"="* ]]; then
        varName=$(echo "$processed_line" | cut -d'=' -f1 | xargs) # Trim whitespace
        currentValue=$(echo "$processed_line" | cut -d'=' -f2-)

        # If already have a non-empty value from existing .env or prior generation/user input, use it
        if [[ -n "${generated_values[$varName]}" ]]; then
            processed_line="${varName}=\"${generated_values[$varName]}\""
        # Check if this is one of our user-input derived variables that might not have a value yet
        # (e.g. OPENAI_API_KEY if user left it blank). These are handled by `found_vars` later if needed.
        # Or, if variable needs generation AND is not already populated (or is empty) in generated_values
        elif [[ -v VARS_TO_GENERATE["$varName"] && -z "${generated_values[$varName]}" ]]; then
            IFS=':' read -r type length <<< "${VARS_TO_GENERATE[$varName]}"
            newValue=""
            case "$type" in
                password|alphanum) newValue=$(gen_password "$length") ;;
                secret|base64) newValue=$(gen_base64 "$length") ;;
                hex) newValue=$(gen_hex "$length") ;;
                langfuse_pk) newValue="pk-lf-$(gen_hex "$length")" ;;
                langfuse_sk) newValue="sk-lf-$(gen_hex "$length")" ;;
                fixed) newValue="$length" ;; # Handle fixed type
                *) log_warning "Unknown generation type '$type' for $varName" ;;
            esac

            if [[ -n "$newValue" ]]; then
                processed_line="${varName}=\"${newValue}\"" # Quote generated values
                generated_values["$varName"]="$newValue"    # Store newly generated
            else
                # Keep original line structure but ensure value is empty if generation failed
                # but it was in VARS_TO_GENERATE
                processed_line="${varName}=\""
                generated_values["$varName"]="" # Explicitly mark as empty in generated_values
            fi
        # For variables from the template that are not in VARS_TO_GENERATE and not already in generated_values
        # store their template value if it's a direct assignment (not a ${...} substitution)
        # This allows them to be used in later ${VAR} substitutions if they are referenced.
        else
            # This 'else' block is for lines from template not covered by existing values or VARS_TO_GENERATE.
            # Check if it is one of the user input vars - these are handled by found_vars later if not in template.
            is_user_input_var=0 # Reset for each line
    user_input_vars=("FLOWISE_USERNAME" "DASHBOARD_USERNAME" "LETSENCRYPT_EMAIL" "RUN_N8N_IMPORT" "PROMETHEUS_USERNAME" "SEARXNG_USERNAME" "OPENAI_API_KEY" "LANGFUSE_INIT_USER_EMAIL" "N8N_WORKER_COUNT" "WEAVIATE_USERNAME" "NEO4J_AUTH_USERNAME" "COMFYUI_USERNAME" "RAGAPP_USERNAME" "PADDLEOCR_USERNAME" "LT_USERNAME" "LIGHTRAG_USERNAME" "WAHA_DASHBOARD_USERNAME" "WHATSAPP_SWAGGER_USERNAME")
            for uivar in "${user_input_vars[@]}"; do
                if [[ "$varName" == "$uivar" ]]; then
                    is_user_input_var=1
                    # Mark as found if it's in template, value taken from generated_values if already set or blank
                    found_vars["$varName"]=1 
                    if [[ -v generated_values[$varName] ]]; then # if it was set (even to empty by user)
                        processed_line="${varName}=\"${generated_values[$varName]}\""
                    else # Not set in generated_values, keep template's default if any, or make it empty
                        if [[ "$currentValue" =~ ^\$\{.*\} || -z "$currentValue" ]]; then # if template is ${VAR} or empty
                            processed_line="${varName}=\"\""
                        else # template has a default simple value
                            processed_line="${varName}=\"$currentValue\"" # Use template's default, and quote it
                        fi
                    fi
                    break
                fi
            done

            if [[ $is_user_input_var -eq 0 ]]; then # Not a user input var, not in VARS_TO_GENERATE, not in existing
                trimmed_value=$(echo "$currentValue" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'//")
                if [[ -n "$varName" && -n "$trimmed_value" && "$trimmed_value" != "\${INSTANCE_DOMAIN}" && "$trimmed_value" != "\${SUBDOMAIN_WILDCARD_CERT}" && ! "$trimmed_value" =~ ^\\$\\{ ]]; then # Check for other placeholders
                    # Only store if not already in generated_values and not a placeholder reference
                    if [[ -z "${generated_values[$varName]}" ]]; then
                        generated_values["$varName"]="$trimmed_value"
                    fi
                fi
                # processed_line remains as is (from template, after domain sub) for these cases
            fi
        fi
    fi
    echo "$processed_line" >> "$TMP_ENV_FILE"
done < "$TEMPLATE_FILE"

# Generate placeholder Supabase keys (always generate these)

# Function to create a JWT token
create_jwt() {
    local role=$1
    local jwt_secret=$2
    local now=$(date +%s)
    local exp=$((now + 315360000)) # 10 years from now (seconds)
    
    # Create header (alg=HS256, typ=JWT)
    local header='{"alg":"HS256","typ":"JWT"}'
    # Create payload with role, issued at time, and expiry
    local payload="{\"role\":\"$role\",\"iss\":\"supabase\",\"iat\":$now,\"exp\":$exp}"
    
    # Base64url encode header and payload
    local b64_header=$(echo -n "$header" | base64 -w 0 | tr '/+' '_-' | tr -d '=')
    local b64_payload=$(echo -n "$payload" | base64 -w 0 | tr '/+' '_-' | tr -d '=')
    
    # Create signature
    local signature_input="$b64_header.$b64_payload"
    local signature=$(echo -n "$signature_input" | openssl dgst -sha256 -hmac "$jwt_secret" -binary | base64 -w 0 | tr '/+' '_-' | tr -d '=')
    
    # Combine to form JWT
    echo -n "$b64_header.$b64_payload.$signature" # Use echo -n to avoid trailing newline
}

# Get JWT secret from previously generated values
JWT_SECRET_TO_USE="${generated_values["JWT_SECRET"]}"

if [[ -z "$JWT_SECRET_TO_USE" ]]; then
    # This should ideally have been generated by VARS_TO_GENERATE if it was missing
    # and JWT_SECRET is in VARS_TO_GENERATE. For safety, generate if truly empty.
    log_warning "JWT_SECRET was empty, attempting to generate it now."
    # Assuming JWT_SECRET definition is 'base64:64'
    JWT_SECRET_TO_USE=$(gen_base64 64)
    generated_values["JWT_SECRET"]="$JWT_SECRET_TO_USE"
fi

# Generate the actual JWT tokens using the JWT_SECRET_TO_USE, if not already set
if [[ -z "${generated_values[ANON_KEY]}" ]]; then
    generated_values["ANON_KEY"]=$(create_jwt "anon" "$JWT_SECRET_TO_USE")
fi

if [[ -z "${generated_values[SERVICE_ROLE_KEY]}" ]]; then
    generated_values["SERVICE_ROLE_KEY"]=$(create_jwt "service_role" "$JWT_SECRET_TO_USE")
fi

# Add any custom variables that weren't found in the template
for var in "FLOWISE_USERNAME" "DASHBOARD_USERNAME" "LETSENCRYPT_EMAIL" "RUN_N8N_IMPORT" "OPENAI_API_KEY" "PROMETHEUS_USERNAME" "SEARXNG_USERNAME" "LANGFUSE_INIT_USER_EMAIL" "N8N_WORKER_COUNT" "WEAVIATE_USERNAME" "NEO4J_AUTH_USERNAME" "COMFYUI_USERNAME" "RAGAPP_USERNAME" "PADDLEOCR_USERNAME" "LT_USERNAME" "LIGHTRAG_USERNAME" "WAHA_DASHBOARD_USERNAME" "WHATSAPP_SWAGGER_USERNAME" "DOCLING_USERNAME"; do
    if [[ ${found_vars["$var"]} -eq 0 && -v generated_values["$var"] ]]; then
        # Before appending, check if it's already in TMP_ENV_FILE to avoid duplicates
        if ! grep -q -E "^${var}=" "$TMP_ENV_FILE"; then
            echo "${var}=\"${generated_values[$var]}\"" >> "$TMP_ENV_FILE" # Ensure quoting
        fi
    fi
done

# --- WAHA API KEY (sha512) --- (moved after .env write to avoid overwrite)

# Second pass: Substitute generated values referenced like ${VAR}
# We'll process the substitutions line by line to avoid escaping issues

# Copy the temporary file to the output
cp "$TMP_ENV_FILE" "$OUTPUT_FILE"

log_info "Applying variable substitutions..."

# Process each generated value
for key in "${!generated_values[@]}"; do
    value="${generated_values[$key]}"
    
    # Create a temporary file for this value to avoid escaping issues
    value_file=$(mktemp)
    echo -n "$value" > "$value_file"
    
    # Create a new temporary file for the output
    new_output=$(mktemp)
    
    # Process each line in the file
    while IFS= read -r line; do
        # Replace ${KEY} format
        if [[ "$line" == *"\${$key}"* ]]; then
            placeholder="\${$key}"
            replacement=$(cat "$value_file")
            line="${line//$placeholder/$replacement}"
        fi
        
        # Replace $KEY format
        if [[ "$line" == *"$"$key* ]]; then
            placeholder="$"$key
            replacement=$(cat "$value_file")
            line="${line//$placeholder/$replacement}"
        fi
        
        # Handle specific cases
        if [[ "$key" == "ANON_KEY" && "$line" == "ANON_KEY="* ]]; then
            line="ANON_KEY=\"$(cat "$value_file")\""
        fi
        
        if [[ "$key" == "SERVICE_ROLE_KEY" && "$line" == "SERVICE_ROLE_KEY="* ]]; then
            line="SERVICE_ROLE_KEY=\"$(cat "$value_file")\""
        fi
        
        if [[ "$key" == "ANON_KEY" && "$line" == "SUPABASE_ANON_KEY="* ]]; then
            line="SUPABASE_ANON_KEY=\"$(cat "$value_file")\""
        fi
        
        if [[ "$key" == "SERVICE_ROLE_KEY" && "$line" == "SUPABASE_SERVICE_ROLE_KEY="* ]]; then
            line="SUPABASE_SERVICE_ROLE_KEY=\"$(cat "$value_file")\""
        fi
        
        if [[ "$key" == "JWT_SECRET" && "$line" == "SUPABASE_JWT_SECRET="* ]]; then
            line="SUPABASE_JWT_SECRET=\"$(cat "$value_file")\""
        fi
        
        if [[ "$key" == "POSTGRES_PASSWORD" && "$line" == "SUPABASE_POSTGRES_PASSWORD="* ]]; then
            line="SUPABASE_POSTGRES_PASSWORD=\"$(cat "$value_file")\""
        fi
        
        # Write the processed line to the new file
        echo "$line" >> "$new_output"
    done < "$OUTPUT_FILE"
    
    # Replace the output file with the new version
    mv "$new_output" "$OUTPUT_FILE"
    
    # Clean up
    rm -f "$value_file"
done

# --- WAHA API KEY (sha512) --- ensure after .env write/substitutions ---
# Generate plaintext API key if missing, then compute sha512:HEX and store in WAHA_API_KEY
if [[ -z "${generated_values[WAHA_API_KEY_PLAIN]}" ]]; then
    generated_values[WAHA_API_KEY_PLAIN]="$(gen_base64 48 | tr -d '\n' | tr '/+' 'AZ')"
fi

PLAINTEXT_KEY="${generated_values[WAHA_API_KEY_PLAIN]}"
if [[ -n "$PLAINTEXT_KEY" ]]; then
    SHA_HEX="$(printf "%s" "$PLAINTEXT_KEY" | openssl dgst -sha512 | awk '{print $2}')"
    if [[ -n "$SHA_HEX" ]]; then
        generated_values[WAHA_API_KEY]="sha512:${SHA_HEX}"
    fi
fi

_update_or_add_env_var "WAHA_API_KEY_PLAIN" "${generated_values[WAHA_API_KEY_PLAIN]}"
_update_or_add_env_var "WAHA_API_KEY" "${generated_values[WAHA_API_KEY]}"

# Hash passwords using caddy with bcrypt
PROMETHEUS_PLAIN_PASS="${generated_values["PROMETHEUS_PASSWORD"]}"
SEARXNG_PLAIN_PASS="${generated_values["SEARXNG_PASSWORD"]}"

# --- PROMETHEUS ---
# Try to get existing hash from memory (populated from .env if it was there)
FINAL_PROMETHEUS_HASH="${generated_values[PROMETHEUS_PASSWORD_HASH]}"

# If no hash in memory, but we have a plain password, generate a new hash
if [[ -z "$FINAL_PROMETHEUS_HASH" && -n "$PROMETHEUS_PLAIN_PASS" ]]; then
    NEW_HASH=$(_generate_and_get_hash "$PROMETHEUS_PLAIN_PASS")
    if [[ -n "$NEW_HASH" ]]; then
        FINAL_PROMETHEUS_HASH="$NEW_HASH"
        generated_values["PROMETHEUS_PASSWORD_HASH"]="$NEW_HASH" # Update memory for consistency
    fi
fi
# Update the .env file with the final determined hash (could be empty if no plain pass or hash failed)
_update_or_add_env_var "PROMETHEUS_PASSWORD_HASH" "$FINAL_PROMETHEUS_HASH"

# --- SEARXNG ---
FINAL_SEARXNG_HASH="${generated_values[SEARXNG_PASSWORD_HASH]}"

if [[ -z "$FINAL_SEARXNG_HASH" && -n "$SEARXNG_PLAIN_PASS" ]]; then
    NEW_HASH=$(_generate_and_get_hash "$SEARXNG_PLAIN_PASS")
    if [[ -n "$NEW_HASH" ]]; then
        FINAL_SEARXNG_HASH="$NEW_HASH"
        generated_values["SEARXNG_PASSWORD_HASH"]="$NEW_HASH"
    fi
fi
_update_or_add_env_var "SEARXNG_PASSWORD_HASH" "$FINAL_SEARXNG_HASH"

# --- COMFYUI ---
COMFYUI_PLAIN_PASS="${generated_values["COMFYUI_PASSWORD"]}"
FINAL_COMFYUI_HASH="${generated_values[COMFYUI_PASSWORD_HASH]}"
if [[ -z "$FINAL_COMFYUI_HASH" && -n "$COMFYUI_PLAIN_PASS" ]]; then
    NEW_HASH=$(_generate_and_get_hash "$COMFYUI_PLAIN_PASS")
    if [[ -n "$NEW_HASH" ]]; then
        FINAL_COMFYUI_HASH="$NEW_HASH"
        generated_values["COMFYUI_PASSWORD_HASH"]="$NEW_HASH"
    fi
fi
_update_or_add_env_var "COMFYUI_PASSWORD_HASH" "$FINAL_COMFYUI_HASH"

# --- PADDLEOCR ---
PADDLEOCR_PLAIN_PASS="${generated_values["PADDLEOCR_PASSWORD"]}"
FINAL_PADDLEOCR_HASH="${generated_values[PADDLEOCR_PASSWORD_HASH]}"
if [[ -z "$FINAL_PADDLEOCR_HASH" && -n "$PADDLEOCR_PLAIN_PASS" ]]; then
    NEW_HASH=$(_generate_and_get_hash "$PADDLEOCR_PLAIN_PASS")
    if [[ -n "$NEW_HASH" ]]; then
        FINAL_PADDLEOCR_HASH="$NEW_HASH"
        generated_values["PADDLEOCR_PASSWORD_HASH"]="$NEW_HASH"
    fi
fi
_update_or_add_env_var "PADDLEOCR_PASSWORD_HASH" "$FINAL_PADDLEOCR_HASH"

# --- RAGAPP ---
RAGAPP_PLAIN_PASS="${generated_values["RAGAPP_PASSWORD"]}"
FINAL_RAGAPP_HASH="${generated_values[RAGAPP_PASSWORD_HASH]}"
if [[ -z "$FINAL_RAGAPP_HASH" && -n "$RAGAPP_PLAIN_PASS" ]]; then
    NEW_HASH=$(_generate_and_get_hash "$RAGAPP_PLAIN_PASS")
    if [[ -n "$NEW_HASH" ]]; then
        FINAL_RAGAPP_HASH="$NEW_HASH"
        generated_values["RAGAPP_PASSWORD_HASH"]="$NEW_HASH"
    fi
fi
_update_or_add_env_var "RAGAPP_PASSWORD_HASH" "$FINAL_RAGAPP_HASH"

# --- LIBRETRANSLATE ---
LT_PLAIN_PASS="${generated_values["LT_PASSWORD"]}"
FINAL_LT_HASH="${generated_values[LT_PASSWORD_HASH]}"
if [[ -z "$FINAL_LT_HASH" && -n "$LT_PLAIN_PASS" ]]; then
    NEW_HASH=$(_generate_and_get_hash "$LT_PLAIN_PASS")
    if [[ -n "$NEW_HASH" ]]; then
        FINAL_LT_HASH="$NEW_HASH"
        generated_values["LT_PASSWORD_HASH"]="$NEW_HASH"
    fi
fi
_update_or_add_env_var "LT_PASSWORD_HASH" "$FINAL_LT_HASH"

# --- DOCLING ---
DOCLING_PLAIN_PASS="${generated_values["DOCLING_PASSWORD"]}"
FINAL_DOCLING_HASH="${generated_values[DOCLING_PASSWORD_HASH]}"
if [[ -z "$FINAL_DOCLING_HASH" && -n "$DOCLING_PLAIN_PASS" ]]; then
    NEW_HASH=$(_generate_and_get_hash "$DOCLING_PLAIN_PASS")
    if [[ -n "$NEW_HASH" ]]; then
        FINAL_DOCLING_HASH="$NEW_HASH"
        generated_values["DOCLING_PASSWORD_HASH"]="$NEW_HASH"
    fi
fi
_update_or_add_env_var "DOCLING_PASSWORD_HASH" "$FINAL_DOCLING_HASH"

if [ $? -eq 0 ]; then # This $? reflects the status of the last mv command from the last _update_or_add_env_var call.
    # For now, assuming if we reached here and mv was fine, primary operations were okay.
    echo ".env file generated successfully in the project root ($OUTPUT_FILE)."
else
    log_error "Failed to generate .env file." >&2
    rm -f "$OUTPUT_FILE" # Clean up potentially broken output file
    exit 1
fi

# Uninstall caddy
apt remove -y caddy

exit 0