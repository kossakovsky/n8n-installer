#!/bin/bash

# Zed Native Installation Script for Enhanced n8n-installer
# This script installs Zed editor and development tools directly in the VM
# Eliminates desktop containerization overhead while maintaining full functionality

set -e

# Source utilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/utils.sh" ]; then
    source "$SCRIPT_DIR/utils.sh"
else
    # Basic logging functions if utils.sh not available
    log_info() { echo "[INFO] $1"; }
    log_success() { echo "[SUCCESS] $1"; }
    log_warning() { echo "[WARNING] $1"; }
    log_error() { echo "[ERROR] $1"; }
fi

# Configuration
ZED_INSTALL_DIR="/opt/zed"
ZED_CONFIG_DIR="$HOME/.config/zed"
ZED_PROJECTS_DIR="$HOME/Projects"

# Function to detect system architecture
detect_architecture() {
    local arch
    arch=$(uname -m)
    case $arch in
        x86_64) echo "x86_64" ;;
        aarch64) echo "aarch64" ;;
        arm64) echo "aarch64" ;;
        *) 
            log_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

# Function to check if running in supported environment
check_environment() {
    log_info "Checking environment compatibility..."
    
    # Check OS
    if [ ! -f /etc/os-release ]; then
        log_error "Cannot detect operating system"
        exit 1
    fi
    
    source /etc/os-release
    
    case "$ID" in
        ubuntu|debian|pop|elementary)
            log_info "Detected compatible OS: $PRETTY_NAME"
            ;;
        *)
            log_warning "OS not explicitly supported: $PRETTY_NAME"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            ;;
    esac
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_warning "Running as root. Some configurations will be applied system-wide."
    fi
    
    # Check available disk space (need at least 2GB)
    local available_space
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 2097152 ]; then # 2GB in KB
        log_warning "Low disk space detected. At least 2GB recommended."
    fi
}

# Function to install system dependencies
install_dependencies() {
    log_info "Installing system dependencies..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    # Update package list
    apt-get update -qq
    
    # Install essential development tools
    apt-get install -y --no-install-recommends \
        curl \
        wget \
        git \
        build-essential \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common \
        apt-transport-https \
        unzip \
        tar \
        gzip \
        fontconfig \
        libfontconfig1-dev \
        libfreetype6-dev \
        libx11-dev \
        libxrandr2 \
        libxi6 \
        libgl1-mesa-glx \
        libasound2-dev \
        pkg-config \
        libssl-dev \
        zsh \
        tmux \
        ripgrep \
        fd-find \
        bat \
        exa \
        fzf \
        jq \
        tree \
        htop \
        neofetch
    
    log_success "System dependencies installed"
}

# Function to install Node.js and npm for language servers
install_nodejs() {
    log_info "Installing Node.js and npm..."
    
    # Install Node.js 20.x LTS
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
    
    # Verify installation
    node_version=$(node --version)
    npm_version=$(npm --version)
    
    log_success "Node.js $node_version and npm $npm_version installed"
}

# Function to install Python development tools
install_python_tools() {
    log_info "Installing Python development environment..."
    
    apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        python3-setuptools \
        python3-wheel
    
    # Install Python language server and tools
    pip3 install --no-cache-dir --break-system-packages \
        'python-lsp-server[all]' \
        black \
        pylint \
        mypy \
        flake8 \
        isort \
        autopep8
    
    log_success "Python development tools installed"
}

# Function to install Rust toolchain
install_rust() {
    log_info "Installing Rust toolchain..."
    
    # Install Rust using rustup
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    
    # Source Rust environment
    source "$HOME/.cargo/env"
    
    # Install rust-analyzer
    rustup component add rust-analyzer
    
    # Install additional useful tools
    cargo install ripgrep fd-find bat exa
    
    log_success "Rust toolchain and tools installed"
}

# Function to install language servers
install_language_servers() {
    log_info "Installing language servers for IDE features..."
    
    # TypeScript/JavaScript language server
    npm install -g typescript typescript-language-server
    
    # JSON language server
    npm install -g vscode-json-languageserver
    
    # YAML language server
    npm install -g yaml-language-server
    
    # Dockerfile language server
    npm install -g dockerfile-language-server-nodejs
    
    # Markdown language server
    npm install -g @vscode/markdown-language-server
    
    # CSS/HTML language servers
    npm install -g vscode-css-languageserver-bin
    npm install -g vscode-html-languageserver-bin
    
    log_success "Language servers installed"
}

# Function to install JetBrains Mono font
install_fonts() {
    log_info "Installing JetBrains Mono font..."
    
    local font_dir="/usr/share/fonts/truetype/jetbrains-mono"
    
    if [ ! -d "$font_dir" ]; then
        mkdir -p "$font_dir"
        
        # Download JetBrains Mono
        local font_url="https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
        local temp_zip="/tmp/jetbrains-mono.zip"
        
        wget -q "$font_url" -O "$temp_zip"
        unzip -q "$temp_zip" -d /tmp/jetbrains-mono
        
        # Install fonts
        cp /tmp/jetbrains-mono/fonts/ttf/*.ttf "$font_dir/"
        
        # Update font cache
        fc-cache -f -v
        
        # Cleanup
        rm -rf /tmp/jetbrains-mono*
        
        log_success "JetBrains Mono font installed"
    else
        log_info "JetBrains Mono font already installed"
    fi
}

# Function to download and install Zed editor
install_zed() {
    log_info "Installing Zed editor..."
    
    local arch
    arch=$(detect_architecture)
    
    # Get latest release information
    local release_info
    release_info=$(curl -s https://api.github.com/repos/zed-industries/zed/releases/latest)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to fetch Zed release information"
        exit 1
    fi
    
    local version
    version=$(echo "$release_info" | jq -r '.tag_name')
    
    local download_url
    if [ "$arch" = "x86_64" ]; then
        download_url=$(echo "$release_info" | jq -r '.assets[] | select(.name | contains("linux-x86_64.tar.gz")) | .browser_download_url')
    elif [ "$arch" = "aarch64" ]; then
        download_url=$(echo "$release_info" | jq -r '.assets[] | select(.name | contains("linux-aarch64.tar.gz")) | .browser_download_url')
    fi
    
    if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
        log_error "Could not find Zed download URL for architecture: $arch"
        exit 1
    fi
    
    log_info "Downloading Zed $version for $arch..."
    
    # Download Zed
    local temp_dir
    temp_dir=$(mktemp -d)
    local zed_archive="$temp_dir/zed.tar.gz"
    
    wget -q "$download_url" -O "$zed_archive"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to download Zed"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Extract and install
    mkdir -p "$ZED_INSTALL_DIR"
    tar -xzf "$zed_archive" -C "$temp_dir"
    
    # Find the extracted directory (it might have a version-specific name)
    local extracted_dir
    extracted_dir=$(find "$temp_dir" -type d -name "zed*" | head -n 1)
    
    if [ -z "$extracted_dir" ]; then
        log_error "Could not find extracted Zed directory"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Copy files to installation directory
    cp -r "$extracted_dir"/* "$ZED_INSTALL_DIR/"
    
    # Make Zed executable
    chmod +x "$ZED_INSTALL_DIR/bin/zed"
    
    # Create symlink in /usr/local/bin
    ln -sf "$ZED_INSTALL_DIR/bin/zed" /usr/local/bin/zed
    
    # Create desktop entry
    create_zed_desktop_entry
    
    # Cleanup
    rm -rf "$temp_dir"
    
    log_success "Zed $version installed successfully"
}

# Function to create desktop entry
create_zed_desktop_entry() {
    log_info "Creating Zed desktop entry..."
    
    local desktop_entry="/usr/share/applications/zed.desktop"
    
    cat > "$desktop_entry" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Zed
Comment=A high-performance, multiplayer code editor
Exec=/usr/local/bin/zed %F
Icon=$ZED_INSTALL_DIR/share/icons/hicolor/512x512/apps/zed.png
Terminal=false
Categories=Development;TextEditor;
StartupWMClass=zed
MimeType=text/plain;text/x-chdr;text/x-csrc;text/x-c++hdr;text/x-c++src;text/x-java;text/x-dsrc;text/x-pascal;text/x-perl;text/x-python;application/x-php;application/x-httpd-php3;application/x-httpd-php4;application/x-httpd-php5;application/xml;text/html;text/css;text/x-sql;text/x-diff;
EOF
    
    chmod 644 "$desktop_entry"
    
    log_success "Desktop entry created"
}

# Function to create Zed configuration for development
create_zed_config() {
    log_info "Creating Zed configuration for AI development..."
    
    local config_dir="$ZED_CONFIG_DIR"
    mkdir -p "$config_dir"
    
    # Create settings.json
    cat > "$config_dir/settings.json" << 'EOF'
{
  "theme": "Ayu Dark",
  "buffer_font_family": "JetBrains Mono",
  "buffer_font_size": 14,
  "ui_font_size": 16,
  "preferred_line_length": 100,
  "soft_wrap": "preferred_line_length",
  "tab_size": 2,
  "hard_tabs": false,
  "show_whitespaces": "selection",
  "relative_line_numbers": false,
  "vim_mode": false,
  "autosave": "on_focus_change",
  "format_on_save": "on",
  "seed_search_query_from_cursor": "always",
  "use_autoclose": true,
  "cursor_blink": false,
  "show_completions_on_input": true,
  "show_completion_documentation": true,
  "completion_documentation_secondary_query_debounce": 300,
  "terminal": {
    "shell": {
      "program": "/bin/zsh"
    },
    "working_directory": "current_project_directory",
    "blinking": "terminal_controlled",
    "alternate_scroll": "off"
  },
  "project_panel": {
    "dock": "left",
    "default_width": 240
  },
  "outline_panel": {
    "dock": "right"
  },
  "collaboration_panel": {
    "dock": "left"
  },
  "git": {
    "inline_blame": {
      "enabled": true
    },
    "git_gutter": "tracked_files"
  },
  "lsp": {
    "rust-analyzer": {
      "binary": {
        "path": "/usr/local/bin/rust-analyzer"
      },
      "initialization_options": {
        "checkOnSave": {
          "command": "clippy"
        }
      }
    },
    "typescript-language-server": {
      "binary": {
        "path": "/usr/local/bin/typescript-language-server"
      }
    },
    "python-lsp-server": {
      "binary": {
        "path": "/usr/local/bin/pylsp"
      }
    },
    "yaml-language-server": {
      "binary": {
        "path": "/usr/local/bin/yaml-language-server"
      }
    },
    "json-language-server": {
      "binary": {
        "path": "/usr/local/bin/vscode-json-languageserver"
      }
    }
  },
  "languages": {
    "JavaScript": {
      "language_servers": ["typescript-language-server"],
      "format_on_save": "on",
      "formatter": "prettier",
      "tab_size": 2
    },
    "TypeScript": {
      "language_servers": ["typescript-language-server"],
      "format_on_save": "on",
      "formatter": "prettier",
      "tab_size": 2
    },
    "TSX": {
      "language_servers": ["typescript-language-server"],
      "format_on_save": "on",
      "formatter": "prettier",
      "tab_size": 2
    },
    "Python": {
      "language_servers": ["python-lsp-server"],
      "format_on_save": "on",
      "formatter": "black",
      "tab_size": 4
    },
    "Rust": {
      "language_servers": ["rust-analyzer"],
      "format_on_save": "on",
      "tab_size": 4
    },
    "JSON": {
      "language_servers": ["json-language-server"],
      "format_on_save": "on",
      "tab_size": 2
    },
    "YAML": {
      "language_servers": ["yaml-language-server"],
      "format_on_save": "on",
      "tab_size": 2
    },
    "Dockerfile": {
      "language_servers": ["docker-langserver"],
      "tab_size": 2
    },
    "Markdown": {
      "format_on_save": "on",
      "tab_size": 2,
      "soft_wrap": "preferred_line_length"
    }
  },
  "assistant": {
    "enabled": true,
    "button": true,
    "dock": "right"
  },
  "chat_panel": {
    "dock": "right"
  },
  "notification_panel": {
    "dock": "bottom"
  }
}
EOF
    
    # Create keymap.json
    cat > "$config_dir/keymap.json" << 'EOF'
[
  {
    "context": "Editor",
    "bindings": {
      "ctrl-shift-p": "command_palette::Toggle",
      "ctrl-p": "file_finder::Toggle",
      "ctrl-shift-f": "project_search::ToggleFocus",
      "ctrl-`": "terminal_panel::ToggleFocus",
      "ctrl-shift-e": "project_panel::ToggleFocus",
      "ctrl-shift-o": "outline::Toggle",
      "ctrl-shift-a": "assistant::ToggleFocus",
      "ctrl-j": "editor::JoinLines",
      "ctrl-d": "editor::SelectNext",
      "ctrl-shift-l": "editor::SelectAll",
      "alt-up": "editor::MoveLineUp",
      "alt-down": "editor::MoveLineDown",
      "ctrl-shift-k": "editor::DeleteLine",
      "ctrl-/": "editor::ToggleComments",
      "ctrl-shift-/": "editor::ToggleBlockComment",
      "ctrl-b": "workspace::ToggleLeftDock",
      "ctrl-shift-c": "collab_panel::ToggleFocus",
      "f2": "editor::Rename",
      "f12": "editor::GoToDefinition",
      "shift-f12": "editor::GoToReferences",
      "ctrl-space": "editor::ShowCompletions"
    }
  },
  {
    "context": "Terminal",
    "bindings": {
      "ctrl-shift-c": "terminal::Copy",
      "ctrl-shift-v": "terminal::Paste",
      "ctrl-shift-t": "workspace::NewTerminal"
    }
  },
  {
    "context": "ProjectPanel",
    "bindings": {
      "a": "project_panel::NewFile",
      "shift-a": "project_panel::NewDirectory",
      "d": "project_panel::Delete",
      "r": "project_panel::Rename"
    }
  }
]
EOF
    
    # Set proper ownership if not running as root
    if [ "$EUID" -ne 0 ]; then
        chown -R "$(whoami)":"$(whoami)" "$config_dir"
    fi
    
    log_success "Zed configuration created"
}

# Function to create development directories
create_dev_environment() {
    log_info "Setting up development environment..."
    
    # Create project directories
    mkdir -p "$ZED_PROJECTS_DIR"/{n8n-workflows,ai-experiments,docker-configs,scripts,knowledge-base}
    
    # Create a welcome project
    local welcome_dir="$ZED_PROJECTS_DIR/welcome-to-zed"
    mkdir -p "$welcome_dir"
    
    cat > "$welcome_dir/README.md" << 'EOF'
# Welcome to Zed Editor in your n8n-installer Environment!

## 🎉 Your AI Development Environment is Ready

This Zed installation is optimized for AI and automation development with:

### ⚡ Pre-configured Language Servers
- **TypeScript/JavaScript** - Full IntelliSense and formatting
- **Python** - Black formatting, pylint, mypy
- **Rust** - rust-analyzer with clippy integration
- **JSON/YAML** - Schema validation and formatting
- **Dockerfile** - Syntax highlighting and validation

### 🧠 AI Integration Features
- **Assistant Panel** - AI-powered code assistance (Ctrl+Shift+A)
- **Real-time Collaboration** - Built-in collaborative editing
- **Smart Completions** - Context-aware code suggestions
- **Fast Search** - Instant file and symbol search

### 🔧 Development Workflow
- **Terminal Integration** - Built-in terminal (Ctrl+`)
- **Git Integration** - Inline blame and git gutter
- **Project Management** - Efficient project panel (Ctrl+Shift+E)
- **Command Palette** - Quick action access (Ctrl+Shift+P)

### 📁 Project Structure
Your projects are organized in `~/Projects/`:
- `n8n-workflows/` - n8n automation workflows
- `ai-experiments/` - AI model experiments and scripts
- `docker-configs/` - Docker and compose configurations
- `scripts/` - Utility scripts and tools
- `knowledge-base/` - Documentation and notes

### 🚀 Quick Start Tips
1. Open the project panel: `Ctrl+Shift+E`
2. Quick file search: `Ctrl+P`
3. Global search: `Ctrl+Shift+F`
4. Command palette: `Ctrl+Shift+P`
5. Toggle terminal: `Ctrl+``

### 🌐 Service Integration
Your Zed environment integrates with:
- **n8n** - Workflow automation platform
- **AppFlowy/Affine** - Knowledge management
- **Docker** - Container development
- **Git** - Version control

### 💡 Next Steps
1. Explore the different project directories
2. Open your first n8n workflow for editing
3. Try the AI assistant features
4. Set up your Git configuration
5. Start building amazing automation workflows!

Happy coding! 🎨
EOF
    
    # Create a sample Python script
    cat > "$welcome_dir/example.py" << 'EOF'
#!/usr/bin/env python3
"""
Example Python script for n8n-installer environment
This demonstrates the development experience with Zed editor
"""

import json
import asyncio
from typing import Dict, Any


async def process_n8n_data(data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Example function that processes n8n workflow data
    
    Args:
        data: Input data from n8n workflow
        
    Returns:
        Processed data dictionary
    """
    # Simulate some async processing
    await asyncio.sleep(0.1)
    
    return {
        "processed": True,
        "input_keys": list(data.keys()),
        "timestamp": "2024-01-01T00:00:00Z",
        "message": "Data processed successfully with Zed + Python!"
    }


def main() -> None:
    """Main function demonstrating the development environment"""
    sample_data = {
        "workflow_id": "example-workflow",
        "execution_id": "12345",
        "data": {"key": "value"}
    }
    
    # Run async function
    result = asyncio.run(process_n8n_data(sample_data))
    
    # Pretty print result
    print(json.dumps(result, indent=2))
    print("\n🎉 Zed editor is working perfectly with Python!")
    print("✨ Features available:")
    print("  - Type checking with mypy")
    print("  - Code formatting with black")
    print("  - Linting with pylint")
    print("  - Full IntelliSense support")


if __name__ == "__main__":
    main()
EOF
    
    # Create a sample TypeScript file
    cat > "$welcome_dir/example.ts" << 'EOF'
/**
 * Example TypeScript file for n8n-installer environment
 * Demonstrates the development experience with Zed editor
 */

interface N8nWorkflowData {
  workflowId: string;
  executionId: string;
  data: Record<string, any>;
}

interface ProcessedResult {
  processed: boolean;
  inputKeys: string[];
  timestamp: string;
  message: string;
}

async function processN8nData(data: N8nWorkflowData): Promise<ProcessedResult> {
  // Simulate some async processing
  await new Promise(resolve => setTimeout(resolve, 100));
  
  return {
    processed: true,
    inputKeys: Object.keys(data.data),
    timestamp: new Date().toISOString(),
    message: "Data processed successfully with Zed + TypeScript!"
  };
}

async function main(): Promise<void> {
  const sampleData: N8nWorkflowData = {
    workflowId: "example-workflow",
    executionId: "12345",
    data: { key: "value" }
  };
  
  const result = await processN8nData(sampleData);
  
  console.log(JSON.stringify(result, null, 2));
  console.log("\n🎉 Zed editor is working perfectly with TypeScript!");
  console.log("✨ Features available:");
  console.log("  - Full type checking");
  console.log("  - IntelliSense and auto-completion");
  console.log("  - Integrated debugging support");
  console.log("  - Modern ES modules support");
}

// Run if this file is executed directly
if (require.main === module) {
  main().catch(console.error);
}

export { processN8nData, N8nWorkflowData, ProcessedResult };
EOF
    
    # Set proper ownership
    if [ "$EUID" -ne 0 ]; then
        chown -R "$(whoami)":"$(whoami)" "$ZED_PROJECTS_DIR"
    fi
    
    log_success "Development environment created"
}

# Function to configure shell environment
configure_shell() {
    log_info "Configuring shell environment..."
    
    local shell_config
    if [ -n "$ZSH_VERSION" ] || command -v zsh &> /dev/null; then
        shell_config="$HOME/.zshrc"
        # Install Oh My Zsh if not present
        if [ ! -d "$HOME/.oh-my-zsh" ]; then
            sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        fi
    else
        shell_config="$HOME/.bashrc"
    fi
    
    # Add development aliases and environment setup
    cat >> "$shell_config" << 'EOF'

# === Zed Editor & Development Environment ===
export EDITOR="zed"
export PATH="$HOME/.cargo/bin:$PATH"

# Development aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias tree='tree -C'
alias cat='bat --style=auto'
alias ls='exa --color=auto'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gd='git diff'

# Docker aliases  
alias dc='docker-compose'
alias dps='docker ps'
alias dlogs='docker logs'

# Editor shortcuts
alias edit='zed'
alias ze='zed'
alias code='zed'

# n8n development helpers
alias n8n-logs='docker logs n8n'
alias n8n-restart='docker restart n8n'
alias services-status='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# Project shortcuts
alias projects='cd ~/Projects && ls -la'
alias workflows='cd ~/Projects/n8n-workflows'
alias experiments='cd ~/Projects/ai-experiments'

# Quick navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# System information
alias sysinfo='neofetch'
alias diskusage='df -h'
alias meminfo='free -h'

echo "🎨 Zed development environment loaded!"
echo "💡 Type 'zed .' to open current directory in Zed"
echo "📁 Type 'projects' to navigate to your project directories"
EOF
    
    log_success "Shell environment configured"
}

# Function to create quick setup script
create_setup_script() {
    log_info "Creating development setup script..."
    
    local setup_script="$HOME/setup-dev-session.sh"
    
    cat > "$setup_script" << 'EOF'
#!/bin/bash

# Quick Development Session Setup Script
# This script sets up a productive development session

echo "🚀 Setting up your development session..."

# Navigate to projects directory
cd ~/Projects || exit 1

# Show system information
echo "📊 System Information:"
neofetch --config off --colors 4 1 8 6 7 7

echo ""
echo "🐳 Docker Services Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -10

echo ""
echo "📁 Available Projects:"
ls -la ~/Projects/

echo ""
echo "🎨 Development Environment Ready!"
echo ""
echo "Quick Commands:"
echo "  zed .           - Open current directory in Zed"
echo "  zed ~/Projects  - Open projects directory"
echo "  workflows       - Go to n8n workflows"
echo "  experiments     - Go to AI experiments"
echo "  services-status - Check Docker services"
echo ""
echo "Happy coding! ✨"
EOF
    
    chmod +x "$setup_script"
    
    # Create desktop shortcut if desktop environment is available
    if [ -n "$DISPLAY" ] && command -v desktop-file-install &> /dev/null; then
        local desktop_file="$HOME/Desktop/Development-Session.desktop"
        cat > "$desktop_file" << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=🚀 Development Session
Comment=Quick setup for development environment
Exec=/bin/bash -c "$HOME/setup-dev-session.sh; exec $SHELL"
Icon=utilities-terminal
Terminal=true
Categories=Development;
EOF
        chmod +x "$desktop_file"
    fi
    
    log_success "Setup script created: $setup_script"
}

# Function to verify installation
verify_installation() {
    log_info "Verifying Zed installation..."
    
    # Check if Zed binary exists and is executable
    if [ ! -x "/usr/local/bin/zed" ]; then
        log_error "Zed binary not found or not executable"
        return 1
    fi
    
    # Check if configuration directory exists
    if [ ! -d "$ZED_CONFIG_DIR" ]; then
        log_error "Zed configuration directory not found"
        return 1
    fi
    
    # Try to get version information
    local version_output
    if ! version_output=$(zed --version 2>/dev/null); then
        log_warning "Could not get Zed version information"
    else
        log_success "Zed installation verified: $version_output"
    fi
    
    # Check language servers
    log_info "Checking language servers..."
    
    local servers=("typescript-language-server" "pylsp" "rust-analyzer")
    for server in "${servers[@]}"; do
        if command -v "$server" &> /dev/null; then
            log_success "$server is available"
        else
            log_warning "$server not found in PATH"
        fi
    done
    
    return 0
}

# Function to show completion message
show_completion_message() {
    echo ""
    echo "="*80
    echo "🎉 ZED EDITOR INSTALLATION COMPLETE!"
    echo "="*80
    echo ""
    echo "🎨 EDITOR ACCESS:"
    echo "   Command: zed"
    echo "   Desktop: Search for 'Zed' in applications menu"
    echo "   Terminal: Type 'zed .' to open current directory"
    echo ""
    echo "📁 PROJECT STRUCTURE:"
    echo "   ~/Projects/n8n-workflows/     - n8n automation workflows"
    echo "   ~/Projects/ai-experiments/    - AI model experiments"
    echo "   ~/Projects/docker-configs/    - Docker configurations"
    echo "   ~/Projects/scripts/           - Utility scripts"
    echo "   ~/Projects/knowledge-base/    - Documentation"
    echo ""
    echo "⚡ LANGUAGE SUPPORT:"
    echo "   ✅ TypeScript/JavaScript with full IntelliSense"
    echo "   ✅ Python with black, pylint, mypy"
    echo "   ✅ Rust with rust-analyzer"
    echo "   ✅ JSON/YAML with schema validation"
    echo "   ✅ Dockerfile support"
    echo ""
    echo "🔧 DEVELOPMENT FEATURES:"
    echo "   🤖 AI Assistant (Ctrl+Shift+A)"
    echo "   🔍 Instant search (Ctrl+P)"
    echo "   📺 Integrated terminal (Ctrl+\`)"
    echo "   🔄 Real-time collaboration"
    echo "   📊 Git integration with inline blame"
    echo ""
    echo "💡 QUICK START:"
    echo "   1. Open terminal and type: zed ~/Projects/welcome-to-zed"
    echo "   2. Explore the welcome project and examples"
    echo "   3. Try the command palette: Ctrl+Shift+P"
    echo "   4. Start your first n8n workflow project!"
    echo ""
    echo "🚀 Your native AI development environment is ready!"
    echo "="*80
}

# Main installation function
main() {
    echo "🎨 Zed Native Installation for Enhanced n8n-installer"
    echo "=================================================="
    echo ""
    
    # Check if running as root for system installation
    if [ "$EUID" -ne 0 ]; then
        log_warning "Not running as root. Some features may require manual configuration."
        read -p "Continue with user installation? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    check_environment
    install_dependencies
    install_nodejs
    install_python_tools
    install_rust
    install_language_servers
    install_fonts
    install_zed
    create_zed_config
    create_dev_environment
    configure_shell
    create_setup_script
    
    if verify_installation; then
        show_completion_message
    else
        log_error "Installation verification failed. Please check the logs above."
        exit 1
    fi
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
