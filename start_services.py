#!/usr/bin/env python3
"""
Start_services.py for n8n-installer + Workspace Integration

This script starts the complete unified workspace including:
- Core n8n-installer services (n8n, Flowise, monitoring, etc.)
- Knowledge management services (AppFlowy, Affine)
- Container management (Portainer)
- Native Zed editor installation
- Unified domain routing via Caddy

Features:
- Shared PostgreSQL database for all services
- Consolidated Redis caching
- Enhanced service health monitoring
- Zed native installation option
- Workspace project structure setup
"""

import os
import subprocess
import shutil
import time
import argparse
import platform
import sys
import json
import tempfile
from pathlib import Path
from dotenv import dotenv_values
from typing import List, Dict, Any, Optional

def show_banner():
    """Enhanced banner for the unified workspace"""
    print("\n" + "="*90)
    print("🚀 ENHANCED n8n-INSTALLER + WORKSPACE-IN-A-BOX")
    print("="*90)
    print("🧠 AI Automation + 📝 Knowledge Management + 🎨 Native Development")
    print()
    print("Features:")
    print("  ⚡ Zed Editor - Lightning-fast native development")
    print("  🧠 n8n Workflows - AI automation platform") 
    print("  📝 AppFlowy & Affine - Knowledge management")
    print("  🐳 Portainer - Container management")
    print("  🔍 Monitoring & Observability - Grafana, Langfuse")
    print("  🗄️ Unified Database - Shared PostgreSQL for optimal performance")
    print("="*90 + "\n")

def check_prerequisites():
    """Enhanced prerequisite checking"""
    print("🔍 Checking system prerequisites...")
    
    required_commands = {
        'docker': 'Docker container platform',
        'docker-compose': 'Docker Compose for multi-container apps', 
        'curl': 'Command-line HTTP client',
        'git': 'Version control system'
    }
    
    missing_commands = []
    
    for cmd, description in required_commands.items():
        try:
            result = subprocess.run([cmd, '--version'], 
                                  capture_output=True, check=True, timeout=10)
            print(f"  ✅ {cmd}: Available")
        except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
            missing_commands.append(f"{cmd} ({description})")
            print(f"  ❌ {cmd}: Missing")
    
    if missing_commands:
        print(f"\n❌ Missing required commands:")
        for cmd in missing_commands:
            print(f"   - {cmd}")
        print("\nPlease install the missing prerequisites and try again.")
        print("For Ubuntu/Debian: sudo apt update && sudo apt install docker.io docker-compose curl git")
        sys.exit(1)
    
    # Check Docker daemon
    try:
        subprocess.run(['docker', 'info'], capture_output=True, check=True, timeout=10)
        print("  ✅ Docker daemon: Running")
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        print("  ❌ Docker daemon: Not running")
        print("\nPlease start Docker daemon: sudo systemctl start docker")
        sys.exit(1)
    
    # Check available memory
    try:
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                if line.startswith('MemAvailable:'):
                    mem_available = int(line.split()[1]) // 1024  # Convert to MB
                    if mem_available < 4096:  # Less than 4GB
                        print(f"  ⚠️  Available memory: {mem_available}MB (4GB+ recommended)")
                    else:
                        print(f"  ✅ Available memory: {mem_available}MB")
                    break
    except:
        print("  ⚠️  Could not check available memory")
    
    # Check disk space
    disk_usage = shutil.disk_usage('/')
    free_gb = disk_usage.free // (1024**3)
    if free_gb < 20:
        print(f"  ⚠️  Free disk space: {free_gb}GB (20GB+ recommended)")
    else:
        print(f"  ✅ Free disk space: {free_gb}GB")
    
    print("✅ All prerequisites met!\n")

def get_enabled_services() -> Dict[str, bool]:
    """Check which services are enabled in .env configuration"""
    env_values = dotenv_values(".env")
    compose_profiles = env_values.get("COMPOSE_PROFILES", "")
    
    services = {
        'n8n': 'n8n' in compose_profiles,
        'flowise': 'flowise' in compose_profiles,
        'open-webui': 'open-webui' in compose_profiles,
        'appflowy': 'appflowy' in compose_profiles,
        'affine': 'affine' in compose_profiles,
        'portainer': 'portainer' in compose_profiles,
        'supabase': 'supabase' in compose_profiles,
        'qdrant': 'qdrant' in compose_profiles,
        'weaviate': 'weaviate' in compose_profiles,
        'neo4j': 'neo4j' in compose_profiles,
        'monitoring': 'monitoring' in compose_profiles,
        'langfuse': 'langfuse' in compose_profiles,
        'searxng': 'searxng' in compose_profiles,
        'crawl4ai': 'crawl4ai' in compose_profiles,
        'letta': 'letta' in compose_profiles,
        'ollama': any(profile in compose_profiles for profile in ['cpu', 'gpu-nvidia', 'gpu-amd'])
    }
    
    return services

def check_zed_installation() -> bool:
    """Check if Zed editor is installed"""
    return shutil.which('zed') is not None

def install_zed_native(force_reinstall: bool = False):
    """Install Zed editor natively using the installation script"""
    if check_zed_installation() and not force_reinstall:
        print("✅ Zed editor already installed")
        return
    
    print("🎨 Installing Zed editor natively...")
    
    # Check if the Zed installation script exists
    script_path = Path("scripts/install_zed_native.sh")
    if not script_path.exists():
        print("❌ Zed installation script not found at scripts/install_zed_native.sh")
        print("   Skipping Zed installation. You can install it manually later.")
        return
    
    try:
        # Make script executable
        script_path.chmod(0o755)
        
        # Run the installation script
        print("   Running Zed installation script...")
        result = subprocess.run(['sudo', 'bash', str(script_path)], 
                              check=True, capture_output=False)
        
        if result.returncode == 0:
            print("✅ Zed editor installed successfully!")
        else:
            print("⚠️  Zed installation completed with warnings")
            
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to install Zed editor: {e}")
        print("   You can install Zed manually later using: scripts/install_zed_native.sh")
    except Exception as e:
        print(f"❌ Unexpected error during Zed installation: {e}")

def setup_workspace_directories():
    """Create workspace directory structure"""
    print("📁 Setting up workspace directories...")
    
    directories = [
        "shared",
        "desktop-shared", 
        "scripts",
        "n8n/templates",
        "n8n/tools",
        "docs",
        Path.home() / "Projects" / "n8n-workflows",
        Path.home() / "Projects" / "ai-experiments", 
        Path.home() / "Projects" / "docker-configs",
        Path.home() / "Projects" / "scripts",
        Path.home() / "Projects" / "knowledge-base"
    ]
    
    for directory in directories:
        Path(directory).mkdir(parents=True, exist_ok=True)
        print(f"  ✅ Created: {directory}")
    
    print("✅ Workspace directories ready!")

def clone_supabase_repo():
    """Clone the Supabase repository using sparse checkout if not already present."""
    enabled_services = get_enabled_services()
    if not enabled_services.get('supabase', False):
        print("📦 Supabase not enabled, skipping repository clone")
        return
    
    if not os.path.exists("supabase"):
        print("📦 Cloning the Supabase repository...")
        try:
            subprocess.run([
                "git", "clone", "--filter=blob:none", "--no-checkout",
                "https://github.com/supabase/supabase.git"
            ], check=True, capture_output=True)
            
            os.chdir("supabase")
            subprocess.run(["git", "sparse-checkout", "init", "--cone"], check=True)
            subprocess.run(["git", "sparse-checkout", "set", "docker"], check=True)
            subprocess.run(["git", "checkout", "master"], check=True)
            os.chdir("..")
            print("✅ Supabase repository cloned successfully")
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to clone Supabase repository: {e}")
            return
    else:
        print("📦 Updating Supabase repository...")
        try:
            os.chdir("supabase")
            subprocess.run(["git", "pull"], check=True, capture_output=True)
            os.chdir("..")
            print("✅ Supabase repository updated")
        except subprocess.CalledProcessError as e:
            print(f"⚠️  Could not update Supabase repository: {e}")

def prepare_supabase_env():
    """Copy .env to .env in supabase/docker."""
    enabled_services = get_enabled_services()
    if not enabled_services.get('supabase', False):
        return
    
    env_path = os.path.join("supabase", "docker", ".env")
    env_source_path = ".env"
    
    if os.path.exists(env_source_path):
        print("🔧 Configuring Supabase environment...")
        shutil.copyfile(env_source_path, env_path)
        print("✅ Supabase environment configured")
    else:
        print("⚠️  .env file not found. Please create one from .env.example")

def generate_searxng_secret_key():
    """Generate a secret key for SearXNG based on the current platform."""
    enabled_services = get_enabled_services()
    if not enabled_services.get('searxng', False):
        return
    
    print("🔐 Configuring SearXNG...")
    
    settings_path = Path("searxng/settings.yml")
    settings_base_path = Path("searxng/settings-base.yml")
    
    # Create searxng directory if it doesn't exist
    settings_path.parent.mkdir(exist_ok=True)
    
    if not settings_base_path.exists():
        print(f"⚠️  SearXNG base settings file not found at {settings_base_path}")
        # Create a basic settings file
        create_basic_searxng_settings(settings_path)
        return
    
    if not settings_path.exists():
        print("📝 Creating SearXNG settings.yml from base...")
        try:
            shutil.copyfile(settings_base_path, settings_path)
            print(f"✅ Created {settings_path}")
        except Exception as e:
            print(f"❌ Error creating settings.yml: {e}")
            create_basic_searxng_settings(settings_path)
            return

    print("🔑 Generating SearXNG secret key...")
    
    try:
        system = platform.system()
        
        if system == "Windows":
            # PowerShell command for Windows
            ps_command = [
                "powershell", "-Command",
                "$randomBytes = New-Object byte[] 32; " +
                "(New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes($randomBytes); " +
                "$secretKey = -join ($randomBytes | ForEach-Object { \"{0:x2}\" -f $_ }); " +
                f"(Get-Content {settings_path}) -replace 'ultrasecretkey', $secretKey | Set-Content {settings_path}"
            ]
            subprocess.run(ps_command, check=True)
        elif system == "Darwin":  # macOS
            openssl_cmd = ["openssl", "rand", "-hex", "32"]
            random_key = subprocess.check_output(openssl_cmd).decode('utf-8').strip()
            sed_cmd = ["sed", "-i", "", f"s|ultrasecretkey|{random_key}|g", str(settings_path)]
            subprocess.run(sed_cmd, check=True)
        else:  # Linux and other Unix-like systems
            openssl_cmd = ["openssl", "rand", "-hex", "32"]
            random_key = subprocess.check_output(openssl_cmd).decode('utf-8').strip()
            sed_cmd = ["sed", "-i", f"s|ultrasecretkey|{random_key}|g", str(settings_path)]
            subprocess.run(sed_cmd, check=True)
        
        print("✅ SearXNG secret key generated successfully")
    except Exception as e:
        print(f"⚠️  Error generating SearXNG secret key: {e}")

def create_basic_searxng_settings(settings_path: Path):
    """Create a basic SearXNG settings file"""
    basic_settings = """
# Basic SearXNG Settings
use_default_settings: true
server:
  secret_key: "ultrasecretkey"  # This will be replaced with a random key
  limiter: false
  image_proxy: true

search:
  safe_search: 0
  autocomplete: "google"
  default_lang: "en"
  formats:
    - html
    - json

engines:
  - name: google
    engine: google
    shortcut: g
    use_mobile_ui: false

outgoing:
  request_timeout: 4.0
  max_request_timeout: 10.0
"""
    
    try:
        with open(settings_path, 'w') as f:
            f.write(basic_settings)
        print(f"✅ Created basic SearXNG settings at {settings_path}")
    except Exception as e:
        print(f"❌ Failed to create basic SearXNG settings: {e}")

def setup_appflowy_storage():
    """Setup AppFlowy MinIO buckets and storage"""
    enabled_services = get_enabled_services()
    if not enabled_services.get('appflowy', False):
        return
    
    print("🗄️  Setting up AppFlowy storage...")
    # AppFlowy storage is automatically handled by the service containers
    # MinIO will create buckets on first startup
    print("✅ AppFlowy storage will be configured automatically")

def setup_affine_storage():
    """Setup Affine storage directories"""
    enabled_services = get_enabled_services()
    if not enabled_services.get('affine', False):
        return
    
    print("📁 Setting up Affine storage...")
    # Affine uses Docker volumes, no manual setup needed
    print("✅ Affine storage will be handled by Docker volumes")

def stop_existing_containers():
    """Stop and remove existing containers for the project"""
    print("🛑 Stopping existing containers...")
    
    # Stop services with various compose file configurations
    compose_commands = [
        ["docker-compose", "-p", "localai", "down"],
        ["docker", "compose", "-p", "localai", "down"],
        ["docker-compose", "-f", "docker-compose.yml", "down"],
        ["docker", "compose", "-f", "docker-compose.yml", "down"]
    ]
    
    for cmd in compose_commands:
        try:
            result = subprocess.run(cmd, capture_output=True, timeout=30)
            if result.returncode == 0:
                print(f"✅ Stopped containers using: {' '.join(cmd)}")
                break
        except (subprocess.TimeoutExpired, FileNotFoundError):
            continue
    
    # Clean up any orphaned containers
    try:
        subprocess.run(["docker", "container", "prune", "-f"], 
                      capture_output=True, timeout=10)
        print("✅ Cleaned up orphaned containers")
    except:
        pass

def start_shared_infrastructure():
    """Start shared infrastructure services first"""
    print("🏗️  Starting shared infrastructure...")
    
    cmd = [
        "docker", "compose", "-p", "localai",
        "-f", "docker-compose.yml",
        "up", "-d",
        "shared-postgres", "shared-redis", "caddy"
    ]
    
    try:
        subprocess.run(cmd, check=True, timeout=120)
        print("✅ Shared infrastructure started")
        
        # Wait for database to be ready
        print("⏳ Waiting for database initialization...")
        time.sleep(15)
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to start shared infrastructure: {e}")
        return False
    except subprocess.TimeoutExpired:
        print("❌ Timeout starting shared infrastructure")
        return False
    
    return True

def start_supabase():
    """Start the Supabase services if enabled"""
    enabled_services = get_enabled_services()
    if not enabled_services.get('supabase', False):
        return True
    
    print("📊 Starting Supabase services...")
    try:
        subprocess.run([
            "docker", "compose", "-p", "localai", 
            "-f", "supabase/docker/docker-compose.yml", 
            "up", "-d"
        ], check=True, timeout=180)
        
        print("✅ Supabase services started")
        print("⏳ Waiting for Supabase to initialize...")
        time.sleep(20)
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to start Supabase: {e}")
        return False
    except subprocess.TimeoutExpired:
        print("❌ Timeout starting Supabase")
        return False

def start_main_services():
    """Start the main application services"""
    print("🚀 Starting main application services...")
    
    cmd = ["docker", "compose", "-p", "localai", "-f", "docker-compose.yml", "up", "-d"]
    
    try:
        subprocess.run(cmd, check=True, timeout=300)
        print("✅ Main services started successfully")
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to start main services: {e}")
        return False
    except subprocess.TimeoutExpired:
        print("❌ Timeout starting main services")
        return False

def wait_for_services():
    """Enhanced service health checking"""
    enabled_services = get_enabled_services()
    
    # Define service endpoints for health checks
    services_to_check = []
    
    # Core services
    if enabled_services.get('n8n', False):
        services_to_check.append(("n8n", "localhost", "5678", 120))
    
    # Knowledge management services
    if enabled_services.get('appflowy', False):
        services_to_check.append(("AppFlowy", "localhost", "3080", 180))
    
    if enabled_services.get('affine', False):
        services_to_check.append(("Affine", "localhost", "3010", 180))
    
    # Container management
    if enabled_services.get('portainer', False):
        services_to_check.append(("Portainer", "localhost", "9000", 90))
    
    # AI services
    if enabled_services.get('flowise', False):
        services_to_check.append(("Flowise", "localhost", "3001", 120))
    
    if enabled_services.get('open-webui', False):
        services_to_check.append(("Open WebUI", "localhost", "8080", 120))
    
    # Infrastructure services
    if enabled_services.get('monitoring', False):
        services_to_check.append(("Grafana", "localhost", "3000", 120))
    
    if enabled_services.get('supabase', False):
        services_to_check.append(("Supabase", "localhost", "8000", 180))
    
    print("🔍 Checking service health...")
    
    failed_services = []
    
    for service_name, host, port, timeout in services_to_check:
        print(f"⏳ Waiting for {service_name} on {host}:{port}...")
        
        start_time = time.time()
        service_ready = False
        
        while time.time() - start_time < timeout:
            try:
                result = subprocess.run([
                    "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
                    f"http://{host}:{port}"
                ], capture_output=True, text=True, timeout=10)
                
                if result.returncode == 0:
                    status_code = result.stdout.strip()
                    if status_code.startswith(('200', '302', '401', '403')):
                        print(f"✅ {service_name} is ready! (HTTP {status_code})")
                        service_ready = True
                        break
                
            except (subprocess.TimeoutExpired, FileNotFoundError):
                pass
            
            time.sleep(5)
        
        if not service_ready:
            print(f"⚠️  {service_name} may not be ready yet (timeout after {timeout}s)")
            failed_services.append(service_name)
    
    if failed_services:
        print(f"\n⚠️  Some services may need more time to start: {', '.join(failed_services)}")
        print("   You can check their status later using: docker ps")
    
    return len(failed_services) == 0

def check_service_logs():
    """Check service logs for any critical errors"""
    print("📋 Checking service logs for errors...")
    
    enabled_services = get_enabled_services()
    critical_services = []
    
    if enabled_services.get('n8n', False):
        critical_services.append('n8n')
    if enabled_services.get('appflowy', False):
        critical_services.extend(['appflowy-cloud', 'appflowy-web'])
    if enabled_services.get('affine', False):
        critical_services.append('affine')
    
    issues_found = []
    
    for service in critical_services:
        try:
            result = subprocess.run([
                "docker", "logs", "--tail", "50", service
            ], capture_output=True, text=True, timeout=10)
            
            if result.returncode == 0:
                logs = result.stderr + result.stdout
                # Check for common error patterns
                error_patterns = [
                    'ERROR', 'FATAL', 'CRITICAL', 'Exception', 'failed to connect', 'connection refused'
                ]
                
                errors = []
                for line in logs.split('\n')[-20:]:  # Check last 20 lines
                    for pattern in error_patterns:
                        if pattern.lower() in line.lower():
                            errors.append(line.strip())
                            break
                
                if errors:
                    issues_found.append((service, errors[:3]))  # Max 3 errors per service
                else:
                    print(f"  ✅ {service}: No critical errors")
            
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
            print(f"  ⚠️  Could not check logs for {service}")
    
    if issues_found:
        print("\n⚠️  Found potential issues in service logs:")
        for service, errors in issues_found:
            print(f"   {service}:")
            for error in errors:
                print(f"     - {error}")
        print("\nThese may be temporary startup issues. Monitor with: docker logs <service_name>")
    
    return len(issues_found) == 0

def show_service_urls():
    """Display service URLs and access information"""
    enabled_services = get_enabled_services()
    env_values = dotenv_values(".env")
    
    domain = env_values.get("USER_DOMAIN_NAME", "localhost")
    use_https = domain != "localhost"
    protocol = "https" if use_https else "http"
    
    print("\n" + "="*90)
    print("🌐 SERVICE ACCESS INFORMATION")
    print("="*90)
    
    # Core Services
    print("\n🧠 CORE AI AUTOMATION:")
    if enabled_services.get('n8n', False):
        n8n_url = f"{protocol}://{env_values.get('N8N_HOSTNAME', f'{domain}:5678')}"
        print(f"   🧠 n8n Workflows:      {n8n_url}")
    
    if enabled_services.get('flowise', False):
        flowise_url = f"{protocol}://{env_values.get('FLOWISE_HOSTNAME', f'{domain}:3001')}"
        print(f"   🤖 Flowise AI Builder: {flowise_url}")
    
    if enabled_services.get('open-webui', False):
        webui_url = f"{protocol}://{env_values.get('WEBUI_HOSTNAME', f'{domain}:8080')}"
        print(f"   💬 Open WebUI Chat:    {webui_url}")
    
    # Knowledge Management
    if enabled_services.get('appflowy', False) or enabled_services.get('affine', False):
        print("\n📝 KNOWLEDGE MANAGEMENT:")
        
        if enabled_services.get('appflowy', False):
            appflowy_url = f"{protocol}://{env_values.get('APPFLOWY_HOSTNAME', f'{domain}:3080')}"
            print(f"   📝 AppFlowy Notes:     {appflowy_url}")
        
        if enabled_services.get('affine', False):
            affine_url = f"{protocol}://{env_values.get('AFFINE_HOSTNAME', f'{domain}:3010')}"
            print(f"   ✨ Affine Workspace:   {affine_url}")
    
    # Container Management
    if enabled_services.get('portainer', False):
        print("\n🐳 CONTAINER MANAGEMENT:")
        portainer_url = f"{protocol}://{env_values.get('PORTAINER_HOSTNAME', f'{domain}:9000')}"
        print(f"   🐳 Portainer:          {portainer_url}")
    
    # Infrastructure Services
    infrastructure_shown = False
    if enabled_services.get('supabase', False):
        if not infrastructure_shown:
            print("\n🔧 INFRASTRUCTURE SERVICES:")
            infrastructure_shown = True
        supabase_url = f"{protocol}://{env_values.get('SUPABASE_HOSTNAME', f'{domain}:8000')}"
        print(f"   🗄️  Supabase Database:  {supabase_url}")
    
    if enabled_services.get('monitoring', False):
        if not infrastructure_shown:
            print("\n🔧 INFRASTRUCTURE SERVICES:")
            infrastructure_shown = True
        grafana_url = f"{protocol}://{env_values.get('GRAFANA_HOSTNAME', f'{domain}:3000')}"
        print(f"   📊 Grafana Monitoring: {grafana_url}")
    
    # Development Environment
    print("\n🎨 DEVELOPMENT ENVIRONMENT:")
    if check_zed_installation():
        print("   ⚡ Zed Editor:          zed (command-line) | Search 'Zed' in applications")
        print("   📁 Projects Directory: ~/Projects/")
        print("   🔧 Development Setup:  ~/setup-dev-session.sh")
    else:
        print("   ⚠️  Zed Editor: Not installed")
    
    # Access Instructions
    print("\n💡 QUICK ACCESS TIPS:")
    if domain == "localhost":
        print("   🌐 All services accessible via localhost URLs above")
    else:
        print(f"   🌐 All services accessible via {domain} with automatic HTTPS")
    
    print("   🔍 Check service status: docker ps")
    print("   📋 View service logs: docker logs <service_name>")
    print("   🛑 Stop all services: docker-compose -p localai down")
    
    if check_zed_installation():
        print("   🎨 Quick development setup: ~/setup-dev-session.sh")
        print("   📁 Open projects in Zed: zed ~/Projects/")
    
    print("="*90)

def show_startup_summary():
    """Show a summary of what will be started"""
    enabled_services = get_enabled_services()
    
    print("🎯 STARTUP SUMMARY")
    print("-" * 50)
    
    # Count enabled services
    total_services = sum(1 for enabled in enabled_services.values() if enabled)
    
    print(f"📊 Total services to start: {total_services}")
    print()
    
    # Core services (always enabled)
    print("🏗️  CORE INFRASTRUCTURE:")
    print("   ✅ PostgreSQL - Shared database")
    print("   ✅ Redis - Caching layer")  
    print("   ✅ Caddy - Reverse proxy")
    
    # Enabled services by category
    categories = {
        "🧠 AI AUTOMATION": {
            'n8n': 'n8n - Workflow automation',
            'flowise': 'Flowise - AI agent builder',
            'open-webui': 'Open WebUI - LLM interface',
            'ollama': 'Ollama - Local LLMs'
        },
        "📝 WORKSPACE": {
            'appflowy': 'AppFlowy - Knowledge management',
            'affine': 'Affine - Collaborative workspace',
            'portainer': 'Portainer - Container management'
        },
        "🔧 INFRASTRUCTURE": {
            'supabase': 'Supabase - Backend services',
            'monitoring': 'Grafana + Prometheus - Monitoring',
            'qdrant': 'Qdrant - Vector database',
            'weaviate': 'Weaviate - AI vector database',
            'neo4j': 'Neo4j - Graph database',
            'searxng': 'SearXNG - Private search',
            'langfuse': 'Langfuse - AI observability',
            'crawl4ai': 'Crawl4ai - Web crawler',
            'letta': 'Letta - Agent server'
        }
    }
    
    for category, services in categories.items():
        category_services = [desc for service, desc in services.items() 
                           if enabled_services.get(service, False)]
        
        if category_services:
            print(f"\n{category}:")
            for service_desc in category_services:
                print(f"   ✅ {service_desc}")
    
    print("\n🎨 DEVELOPMENT ENVIRONMENT:")
    if check_zed_installation():
        print("   ✅ Zed Editor - Already installed")
    else:
        print("   🔄 Zed Editor - Will be installed")
    
    print()

def main():
    """Main function orchestrating the enhanced startup process"""
    parser = argparse.ArgumentParser(description='Enhanced n8n-installer + Workspace Startup')
    parser.add_argument('--skip-zed', action='store_true',
                       help='Skip Zed editor installation')
    parser.add_argument('--reinstall-zed', action='store_true',
                       help='Force reinstall Zed editor even if already present')
    parser.add_argument('--skip-health-check', action='store_true',
                       help='Skip service health checks')
    parser.add_argument('action', nargs='?', choices=['up', 'down', 'restart', 'status'],
                       default='up', help='Action to perform (default: up)')
    
    args = parser.parse_args()
    
    if args.action == 'down':
        print("🛑 Stopping all services...")
        stop_existing_containers()
        print("✅ All services stopped")
        return
    
    if args.action == 'status':
        print("📊 Service Status:")
        subprocess.run(["docker", "ps", "--format", 
                       "table {{.Names}}\t{{.Status}}\t{{.Ports}}"])
        return
    
    if args.action == 'restart':
        print("🔄 Restarting all services...")
        stop_existing_containers()
        time.sleep(5)
    
    # Main startup process
    show_banner()
    check_prerequisites()
    show_startup_summary()
    
    # Confirm startup
    if args.action == 'up':
        confirm = input("\n🚀 Start the enhanced workspace? (Y/n): ").strip().lower()
        if confirm in ['n', 'no']:
            print("👋 Startup cancelled.")
            return
    
    # Setup phase
    setup_workspace_directories()
    
    # Repository setup
    clone_supabase_repo()
    prepare_supabase_env()
    generate_searxng_secret_key()
    setup_appflowy_storage()
    setup_affine_storage()
    
    # Zed installation
    if not args.skip_zed:
        install_zed_native(force_reinstall=args.reinstall_zed)
    
    # Service startup
    stop_existing_containers()
    
    if not start_shared_infrastructure():
        print("❌ Failed to start shared infrastructure")
        return
    
    if not start_supabase():
        print("❌ Failed to start Supabase services")
        return
    
    if not start_main_services():
        print("❌ Failed to start main services") 
        return
    
    # Health checking
    if not args.skip_health_check:
        print("\n🔍 Performing health checks...")
        health_ok = wait_for_services()
        logs_ok = check_service_logs()
        
        if not health_ok or not logs_ok:
            print("\n⚠️  Some services may need attention. Check logs with: docker logs <service_name>")
    
    # Success!
    show_service_urls()
    
    print(f"\n🎉 ENHANCED WORKSPACE IS READY!")
    print("Your complete AI development environment is now running.")
    print("Happy automating and developing! 🚀")

if __name__ == "__main__":
    main()
