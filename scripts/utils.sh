#!/bin/bash

# Logging function that frames a message with a border and adds a timestamp
log_message() {
    local message="$1"
    local combined_message="${message}"
    local length=${#combined_message}
    local border_length=$((length + 4))
    
    # Create the top border
    local border=""
    for ((i=0; i<border_length; i++)); do
        border="${border}─"
    done
    
    # Display the framed message with timestamp
    echo "╭${border}╮"
    echo "│ ${combined_message}   │"
    echo "╰${border}╯"
}

# Example usage:
# log_message "This is a test message"

log_success() {
    local message="$1"
    local timestamp=$(date +%H:%M:%S)
    local combined_message="[SUCCESS] ${timestamp}: ${message}"
    log_message "${combined_message}"
}

log_error() {
    local message="$1"
    local timestamp=$(date +%H:%M:%S)
    local combined_message="[ERROR] ${timestamp}: ${message}"
    log_message "${combined_message}"
}

log_warning() {
    local message="$1"
    local timestamp=$(date +%H:%M:%S)
    local combined_message="[WARNING] ${timestamp}: ${message}"
    log_message "${combined_message}"
}

log_info() {
    local message="$1"
    local timestamp=$(date +%H:%M:%S)
    local combined_message="[INFO] ${timestamp}: ${message}"
    log_message "${combined_message}"
}

# --- Whiptail helpers ---
# Ensure whiptail is available
require_whiptail() {
    if ! command -v whiptail >/dev/null 2>&1; then
        log_error "'whiptail' is not installed. Install with: sudo apt-get install -y whiptail"
        exit 1
    fi
}

# Input box. Usage: wt_input "Title" "Prompt" "default"
# Echoes the input on success; returns 0 on OK, 1 on Cancel
wt_input() {
    local title="$1"
    local prompt="$2"
    local default_value="$3"
    local result
    result=$(whiptail --title "$title" --inputbox "$prompt" 15 80 "$default_value" 3>&1 1>&2 2>&3)
    local status=$?
    if [ $status -ne 0 ]; then
        return 1
    fi
    echo "$result"
    return 0
}

# Password box. Usage: wt_password "Title" "Prompt"
# Echoes the input on success; returns 0 on OK, 1 on Cancel
wt_password() {
    local title="$1"
    local prompt="$2"
    local result
    result=$(whiptail --title "$title" --passwordbox "$prompt" 15 80 3>&1 1>&2 2>&3)
    local status=$?
    if [ $status -ne 0 ]; then
        return 1
    fi
    echo "$result"
    return 0
}

# Yes/No box. Usage: wt_yesno "Title" "Prompt" "default"  (default: yes|no)
# Returns 0 for Yes, 1 for No/Cancel
wt_yesno() {
    local title="$1"
    local prompt="$2"
    local default_choice="$3"
    if [ "$default_choice" = "yes" ]; then
        whiptail --title "$title" --yesno "$prompt" 10 80
    else
        whiptail --title "$title" --defaultno --yesno "$prompt" 10 80
    fi
}

# Message box. Usage: wt_msg "Title" "Message"
wt_msg() {
    local title="$1"
    local message="$2"
    whiptail --title "$title" --msgbox "$message" 10 80
}

