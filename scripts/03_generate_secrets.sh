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
    ["LOGFLARE_LOGGER_BACKEND_API_KEY"]="secret:64" # base64 encoded, 48 bytes -> 64 chars
    ["LOGFLARE_API_KEY"]="secret:64" # base64 encoded, 48 bytes -> 64 chars
    ["PROMETHEUS_PASSWORD"]="password:32" # Added Prometheus password
    ["SEARXNG_PASSWORD"]="password:32" # Added SearXNG admin password
    ["LETTA_SERVER_PASSWORD"]="password:32" # Added Letta server password
    ["LANGFUSE_INIT_USER_PASSWORD"]="password:32"
    ["LANGFUSE_INIT_PROJECT_PUBLIC_KEY"]="langfuse_pk:32"
    ["LANGFUSE_INIT_PROJECT_SECRET_KEY"]="langfuse_sk:32"
)

# Check if .env file already exists
if [ -f "$OUTPUT_FILE" ]; then
    log_info "$OUTPUT_FILE already exists. Reading existing values and will only fill missing ones."
    declare -A existing_env_vars # Declare here if only used after this block
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -n "$line" && ! "$line" =~ ^\\s*# && "$line" == *"="* ]]; then
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
else
    log_info "No existing $OUTPUT_FILE found. Will generate a new one."
    declare -A existing_env_vars # Ensure it's declared even if file doesn't exist
fi

# Install Caddy
log_info "Installing Caddy..."
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt install -y caddy

# Check for caddy
if ! command -v caddy &> /dev/null; then
    log_error "caddy could not be found. Please ensure it is installed and available in your PATH." >&2
    exit 1
fi

# Prompt for the domain name
while true; do
    echo ""
    read -p "Enter the primary domain name for your services (e.g., example.com): " DOMAIN

    # Validate domain input
    if [[ -z "$DOMAIN" ]]; then
        log_error "Domain name cannot be empty." >&2
        continue # Ask again
    fi

    # Basic check for likely invalid domain characters (very permissive)
    if [[ "$DOMAIN" =~ [^a-zA-Z0-9.-] ]]; then
        log_warning "Warning: Domain name contains potentially invalid characters: '$DOMAIN'" >&2
    fi

    echo ""
    read -p "Are you sure '$DOMAIN' is correct? (y/N): " confirm_domain
    if [[ "$confirm_domain" =~ ^[Yy]$ ]]; then
        break # Confirmed, exit loop
    else
        log_info "Please try entering the domain name again."
    fi
done

# Prompt for user email
echo "Please enter your email address. This email will be used for:"
echo "   - Login to Flowise"
echo "   - Login to Supabase"
echo "   - Login to SearXNG"
echo "   - Login to Grafana"
echo "   - Login to Prometheus"
echo "   - SSL certificate generation with Let's Encrypt"

if [[ -n "${existing_env_vars[LETSENCRYPT_EMAIL]}" ]]; then
    USER_EMAIL="${existing_env_vars[LETSENCRYPT_EMAIL]}"
    log_info "Using existing email from .env: $USER_EMAIL"
else
    while true; do
        echo ""
        read -p "Email: " USER_EMAIL

        # Validate email input
        if [[ -z "$USER_EMAIL" ]]; then
            log_error "Email cannot be empty." >&2
            continue # Ask again
        fi

        # Basic email format validation
        if [[ ! "$USER_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            log_warning "Warning: Email format appears to be invalid: '$USER_EMAIL'" >&2
        fi

        echo ""
        read -p "Are you sure '$USER_EMAIL' is correct? (y/N): " confirm_email
        if [[ "$confirm_email" =~ ^[Yy]$ ]]; then
            break # Confirmed, exit loop
        else
            log_info "Please try entering the email address again."
        fi
    done
fi

# Prompt for OpenAI API key (optional)
echo "OpenAI API Key (optional). This key will be used for:"
echo "   - Supabase: AI services to help with writing SQL queries, statements, and policies"
echo "   - Crawl4AI: Default LLM configuration for web crawling capabilities"
echo "   You can skip this by leaving it empty."

if [[ -v existing_env_vars[OPENAI_API_KEY] ]]; then # -v checks if variable is set (even if empty)
    OPENAI_API_KEY="${existing_env_vars[OPENAI_API_KEY]}"
    if [[ -n "$OPENAI_API_KEY" ]]; then
      log_info "Using existing OpenAI API Key from .env."
    else
      log_info "Found empty OpenAI API Key in .env. You can provide one now or leave empty."
      echo ""
      read -p "OpenAI API Key: " OPENAI_API_KEY # Allow update if it was empty
    fi
else
    echo ""
    read -p "OpenAI API Key: " OPENAI_API_KEY
fi

# Ask if user wants to import ready-made workflow for n8n
echo "Do you want to import 300 ready-made workflows for n8n? This process may take about 30 minutes to complete."
if [[ -n "${existing_env_vars[RUN_N8N_IMPORT]}" ]]; then
    RUN_N8N_IMPORT="${existing_env_vars[RUN_N8N_IMPORT]}"
    log_info "Using existing RUN_N8N_IMPORT value from .env: $RUN_N8N_IMPORT"
else
    echo ""
    read -p "Import workflows? (y/n): " import_workflow
    if [[ "$import_workflow" =~ ^[Yy]$ ]]; then
        RUN_N8N_IMPORT="true"
    else
        RUN_N8N_IMPORT="false"
    fi
fi

# Prompt for number of n8n workers
echo "" # Add a newline for better formatting
log_info "Configuring n8n worker count..."
if [[ -n "${existing_env_vars[N8N_WORKER_COUNT]}" ]]; then
    N8N_WORKER_COUNT_CURRENT="${existing_env_vars[N8N_WORKER_COUNT]}"
    log_info "Found existing N8N_WORKER_COUNT in .env: $N8N_WORKER_COUNT_CURRENT"
    echo ""
    read -p "Do you want to change the number of n8n workers? Current: $N8N_WORKER_COUNT_CURRENT. (Enter new number, or press Enter to keep current): " N8N_WORKER_COUNT_INPUT_RAW
    if [[ -z "$N8N_WORKER_COUNT_INPUT_RAW" ]]; then
        N8N_WORKER_COUNT="$N8N_WORKER_COUNT_CURRENT"
        log_info "Keeping N8N_WORKER_COUNT at $N8N_WORKER_COUNT."
    else
        # Validate the new input
        if [[ "$N8N_WORKER_COUNT_INPUT_RAW" =~ ^0*[1-9][0-9]*$ ]]; then
            N8N_WORKER_COUNT_TEMP="$((10#$N8N_WORKER_COUNT_INPUT_RAW))" # Sanitize (e.g. 01 -> 1)
            if [[ "$N8N_WORKER_COUNT_TEMP" -ge 1 ]]; then
                 echo ""
                 read -p "Update n8n workers to $N8N_WORKER_COUNT_TEMP? (y/N): " confirm_change
                 if [[ "$confirm_change" =~ ^[Yy]$ ]]; then
                    N8N_WORKER_COUNT="$N8N_WORKER_COUNT_TEMP"
                    log_info "N8N_WORKER_COUNT set to $N8N_WORKER_COUNT."
                 else
                    N8N_WORKER_COUNT="$N8N_WORKER_COUNT_CURRENT"
                    log_info "Change declined. Keeping N8N_WORKER_COUNT at $N8N_WORKER_COUNT."
                 fi
            else # Should not happen with regex but as a safeguard
                log_warning "Invalid input '$N8N_WORKER_COUNT_INPUT_RAW'. Number must be positive. Keeping $N8N_WORKER_COUNT_CURRENT."
                N8N_WORKER_COUNT="$N8N_WORKER_COUNT_CURRENT"
            fi
        else
            log_warning "Invalid input '$N8N_WORKER_COUNT_INPUT_RAW'. Please enter a positive integer. Keeping $N8N_WORKER_COUNT_CURRENT."
            N8N_WORKER_COUNT="$N8N_WORKER_COUNT_CURRENT"
        fi
    fi
else
    while true; do
        echo ""
        read -p "Enter the number of n8n workers to run (e.g., 1, 2, 3; default is 1): " N8N_WORKER_COUNT_INPUT_RAW
        N8N_WORKER_COUNT_CANDIDATE="${N8N_WORKER_COUNT_INPUT_RAW:-1}" # Default to 1 if empty

        if [[ "$N8N_WORKER_COUNT_CANDIDATE" =~ ^0*[1-9][0-9]*$ ]]; then
            N8N_WORKER_COUNT_VALIDATED="$((10#$N8N_WORKER_COUNT_CANDIDATE))"
            if [[ "$N8N_WORKER_COUNT_VALIDATED" -ge 1 ]]; then
                echo ""
                read -p "Run $N8N_WORKER_COUNT_VALIDATED n8n worker(s)? (y/N): " confirm_workers
                if [[ "$confirm_workers" =~ ^[Yy]$ ]]; then
                    N8N_WORKER_COUNT="$N8N_WORKER_COUNT_VALIDATED"
                    log_info "N8N_WORKER_COUNT set to $N8N_WORKER_COUNT."
                    break
                else
                    log_info "Please try entering the number of workers again."
                fi
            else # Should not be reached if regex is correct
                log_error "Number of workers must be a positive integer." >&2
            fi
        else
            log_error "Invalid input '$N8N_WORKER_COUNT_CANDIDATE'. Please enter a positive integer (e.g., 1, 2)." >&2
        fi
    done
fi
# Ensure N8N_WORKER_COUNT is definitely set (should be by logic above)
N8N_WORKER_COUNT="${N8N_WORKER_COUNT:-1}"

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

# --- Main Logic ---

if [ ! -f "$TEMPLATE_FILE" ]; then
    log_error "Template file not found at $TEMPLATE_FILE" >&2
    exit 1
fi

# Associative array to store generated values
declare -A generated_values

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
generated_values["RUN_N8N_IMPORT"]="$RUN_N8N_IMPORT"
generated_values["PROMETHEUS_USERNAME"]="$USER_EMAIL"
generated_values["SEARXNG_USERNAME"]="$USER_EMAIL"
generated_values["LANGFUSE_INIT_USER_EMAIL"]="$USER_EMAIL"
generated_values["N8N_WORKER_COUNT"]="$N8N_WORKER_COUNT"
if [[ -n "$OPENAI_API_KEY" ]]; then
    generated_values["OPENAI_API_KEY"]="$OPENAI_API_KEY"
fi

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
            user_input_vars=("FLOWISE_USERNAME" "DASHBOARD_USERNAME" "LETSENCRYPT_EMAIL" "RUN_N8N_IMPORT" "PROMETHEUS_USERNAME" "SEARXNG_USERNAME" "OPENAI_API_KEY" "LANGFUSE_INIT_USER_EMAIL" "N8N_WORKER_COUNT")
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
                            # Don't add to generated_values here, let the original logic handle it if needed
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
log_info "Generating Supabase JWT keys..."

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
    log_info "Generating ANON_KEY..."
    generated_values["ANON_KEY"]=$(create_jwt "anon" "$JWT_SECRET_TO_USE")
else
    log_info "Using existing ANON_KEY."
fi

if [[ -z "${generated_values[SERVICE_ROLE_KEY]}" ]]; then
    log_info "Generating SERVICE_ROLE_KEY..."
    generated_values["SERVICE_ROLE_KEY"]=$(create_jwt "service_role" "$JWT_SECRET_TO_USE")
else
    log_info "Using existing SERVICE_ROLE_KEY."
fi

# Add any custom variables that weren't found in the template
for var in "FLOWISE_USERNAME" "DASHBOARD_USERNAME" "LETSENCRYPT_EMAIL" "RUN_N8N_IMPORT" "OPENAI_API_KEY" "PROMETHEUS_USERNAME" "SEARXNG_USERNAME" "LANGFUSE_INIT_USER_EMAIL" "N8N_WORKER_COUNT"; do
    if [[ ${found_vars["$var"]} -eq 0 && -v generated_values["$var"] ]]; then
        # Before appending, check if it's already in TMP_ENV_FILE to avoid duplicates
        if ! grep -q -E "^${var}=" "$TMP_ENV_FILE"; then
            echo "${var}=\"${generated_values[$var]}\"" >> "$TMP_ENV_FILE" # Ensure quoting
        fi
    fi
done

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

# Hash passwords using caddy with bcrypt
log_info "Hashing passwords with caddy using bcrypt..."
PROMETHEUS_PLAIN_PASS="${generated_values["PROMETHEUS_PASSWORD"]}"
SEARXNG_PLAIN_PASS="${generated_values["SEARXNG_PASSWORD"]}"

if [[ -n "${generated_values[PROMETHEUS_PASSWORD_HASH]}" ]]; then
    log_info "PROMETHEUS_PASSWORD_HASH already exists. Skipping re-hashing."
elif [[ -n "$PROMETHEUS_PLAIN_PASS" ]]; then
    PROMETHEUS_HASH=$(caddy hash-password --algorithm bcrypt --plaintext "$PROMETHEUS_PLAIN_PASS" 2>/dev/null)
    if [[ $? -eq 0 && -n "$PROMETHEUS_HASH" ]]; then
        echo "PROMETHEUS_PASSWORD_HASH='$PROMETHEUS_HASH'" >> "$OUTPUT_FILE"
        generated_values["PROMETHEUS_PASSWORD_HASH"]="$PROMETHEUS_HASH" # Store for consistency, though primarily written to file
    else
        log_warning "Failed to hash Prometheus password using caddy."
    fi
else
    log_warning "Prometheus password was not generated or found, skipping hash."
fi

if [[ -n "${generated_values[SEARXNG_PASSWORD_HASH]}" ]]; then
    log_info "SEARXNG_PASSWORD_HASH already exists. Skipping re-hashing."
elif [[ -n "$SEARXNG_PLAIN_PASS" ]]; then
    SEARXNG_HASH=$(caddy hash-password --algorithm bcrypt --plaintext "$SEARXNG_PLAIN_PASS" 2>/dev/null)
    if [[ $? -eq 0 && -n "$SEARXNG_HASH" ]]; then
        echo "SEARXNG_PASSWORD_HASH='$SEARXNG_HASH'" >> "$OUTPUT_FILE"
        generated_values["SEARXNG_PASSWORD_HASH"]="$SEARXNG_HASH"
    else
        log_warning "Failed to hash SearXNG password using caddy."
    fi
else
    log_warning "SearXNG password was not generated or found, skipping hash."
fi

if [ $? -eq 0 ]; then
    log_success ".env file generated successfully in the project root ($OUTPUT_FILE)."
else
    log_error "Failed to generate .env file." >&2
    rm -f "$OUTPUT_FILE" # Clean up potentially broken output file
    exit 1
fi

# Uninstall caddy
log_info "Uninstalling caddy..."
apt remove -y caddy

exit 0 