#!/bin/bash
# =============================================================================
# 00_check_prerequisites.sh - Check prerequisites for local installation
# =============================================================================
# Verifies that required tools are installed for local development mode.
# Required: Docker, Docker Compose, whiptail, openssl, git
#
# Usage: bash scripts/00_check_prerequisites.sh
# =============================================================================

set -e

source "$(dirname "$0")/utils.sh"
init_paths

log_subheader "Checking Prerequisites for Local Installation"

MISSING_DEPS=()

# Check Docker
log_info "Checking Docker..."
if ! command -v docker &> /dev/null; then
    MISSING_DEPS+=("docker")
    print_error "Docker is not installed"
    case "$(uname)" in
        Darwin)
            log_info "  Install Docker Desktop: https://www.docker.com/products/docker-desktop"
            ;;
        Linux)
            log_info "  Install Docker: https://docs.docker.com/engine/install/"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            log_info "  Install Docker Desktop for Windows: https://www.docker.com/products/docker-desktop"
            log_info "  Then enable WSL2 integration in Docker Desktop settings"
            ;;
    esac
else
    docker_version=$(docker --version 2>/dev/null || echo "unknown")
    print_ok "Docker is installed: $docker_version"

    # Check Docker daemon
    if ! docker info > /dev/null 2>&1; then
        MISSING_DEPS+=("docker-daemon")
        print_error "Docker daemon is not running"
        case "$(uname)" in
            Darwin)
                log_info "  Start Docker Desktop from Applications"
                ;;
            Linux)
                log_info "  Start Docker: sudo systemctl start docker"
                ;;
        esac
    else
        print_ok "Docker daemon is running"
    fi
fi

# Check Docker Compose
log_info "Checking Docker Compose..."
if ! docker compose version &> /dev/null 2>&1; then
    MISSING_DEPS+=("docker-compose")
    print_error "Docker Compose plugin is not installed"
    log_info "  Docker Compose should be included with Docker Desktop"
    log_info "  Or install: https://docs.docker.com/compose/install/"
else
    compose_version=$(docker compose version 2>/dev/null || echo "unknown")
    print_ok "Docker Compose is installed: $compose_version"
fi

# Check whiptail
log_info "Checking whiptail..."
if ! command -v whiptail &> /dev/null; then
    MISSING_DEPS+=("whiptail")
    print_error "whiptail is not installed"
    case "$(uname)" in
        Darwin)
            log_info "  Install with: brew install newt"
            ;;
        Linux)
            if command -v apt-get &> /dev/null; then
                log_info "  Install with: sudo apt-get install -y whiptail"
            elif command -v yum &> /dev/null; then
                log_info "  Install with: sudo yum install -y newt"
            elif command -v pacman &> /dev/null; then
                log_info "  Install with: sudo pacman -S libnewt"
            else
                log_info "  Install the 'newt' or 'whiptail' package for your distribution"
            fi
            ;;
    esac
else
    print_ok "whiptail is installed"
fi

# Check openssl
log_info "Checking openssl..."
if ! command -v openssl &> /dev/null; then
    MISSING_DEPS+=("openssl")
    print_error "openssl is not installed"
    case "$(uname)" in
        Darwin)
            log_info "  openssl should be pre-installed on macOS"
            log_info "  Or install with: brew install openssl"
            ;;
        Linux)
            if command -v apt-get &> /dev/null; then
                log_info "  Install with: sudo apt-get install -y openssl"
            elif command -v yum &> /dev/null; then
                log_info "  Install with: sudo yum install -y openssl"
            else
                log_info "  Install openssl for your distribution"
            fi
            ;;
    esac
else
    openssl_version=$(openssl version 2>/dev/null || echo "unknown")
    print_ok "openssl is installed: $openssl_version"
fi

# Check git
log_info "Checking git..."
if ! command -v git &> /dev/null; then
    MISSING_DEPS+=("git")
    print_error "git is not installed"
    log_info "  Install git: https://git-scm.com/downloads"
else
    git_version=$(git --version 2>/dev/null || echo "unknown")
    print_ok "git is installed: $git_version"
fi

# Check Python3 and PyYAML (required for start_services.py)
log_info "Checking Python3..."
if ! command -v python3 &> /dev/null; then
    MISSING_DEPS+=("python3")
    print_error "Python3 is not installed"
    log_info "  Install Python3: https://www.python.org/downloads/"
else
    python_version=$(python3 --version 2>/dev/null || echo "unknown")
    print_ok "Python3 is installed: $python_version"

    # Check and install required Python modules
    PYTHON_MODULES=("yaml:pyyaml" "dotenv:python-dotenv")
    for module_pair in "${PYTHON_MODULES[@]}"; do
        import_name="${module_pair%%:*}"
        package_name="${module_pair##*:}"
        log_info "Checking Python module: $package_name..."
        if ! python3 -c "import $import_name" 2>/dev/null; then
            print_warning "$package_name not found. Installing..."
            if python3 -m pip install --user "$package_name" 2>/dev/null; then
                print_ok "$package_name installed successfully"
            else
                MISSING_DEPS+=("$package_name")
                print_error "Failed to install $package_name"
                log_info "  Install manually: pip3 install $package_name"
            fi
        else
            print_ok "$package_name is available"
        fi
    done
fi

# Summary
echo ""
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    log_error "Missing dependencies: ${MISSING_DEPS[*]}"
    log_info "Please install the missing dependencies and try again."
    exit 1
else
    log_success "All prerequisites are satisfied!"
fi

exit 0
