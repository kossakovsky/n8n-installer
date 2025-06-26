#!/usr/bin/env python3
"""
Start Services for n8n-installer + Workspace Integration

This comprehensive script orchestrates the complete unified workspace including:
- Core n8n-installer services (n8n, Flowise, monitoring, etc.)
- Knowledge management services (AppFlowy, Affine)
- Container management (Portainer)
- Editor installation and configuration (Zed/VS Code, native/container)
- Unified database and routing
- Development environment setup

Features:
- Intelligent service dependency management
- Editor selection and installation
- Health monitoring and diagnostics
- Workspace project structure
- Development environment optimization
"""

import asyncio
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import argparse
import platform
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
from dotenv import dotenv_values
import threading
from concurrent.futures import ThreadPoolExecutor
import signal


class EnhancedWorkspaceManager:
    def __init__(self):
        self.project_root = Path.cwd()
        self.config_dir = self.project_root / "editor-config"
        self.logs_dir = self.project_root / "logs"
        self.logs_dir.mkdir(exist_ok=True)
        
        # Service dependency graph
        self.service_dependencies = {
            # Core infrastructure (no dependencies)
            'shared-postgres': [],
            'shared-redis': [],
            'caddy': [],
            
            # Core services depend on infrastructure
            'n8n': ['shared-postgres', 'shared-redis'],
            'n8n-worker': ['n8n', 'shared-redis'],
            'flowise': [],
            'open-webui': [],
            
            # Knowledge management services
            'appflowy-minio': [],
            'appflowy-gotrue': ['shared-postgres'],
            'appflowy-cloud': ['appflowy-gotrue', 'appflowy-minio', 'shared-redis'],
            'appflowy-web': ['appflowy-cloud'],
            
            'affine-migration': ['shared-postgres', 'shared-redis'],
            'affine': ['affine-migration', 'shared-postgres', 'shared-redis'],
            
            # Container management
            'portainer': [],
            
            # Infrastructure services
            'prometheus': [],
            'node-exporter': [],
            'cadvisor': [],
            'grafana': ['prometheus'],
            
            'clickhouse': [],
            'minio': [],
            'langfuse-worker': ['shared-postgres', 'clickhouse', 'minio', 'shared-redis'],
            'langfuse-web': ['langfuse-worker'],
            
            # Vector databases
            'qdrant': [],
            'weaviate': [],
            'neo4j': [],
            
            # Additional services
            'searxng': [],
            'crawl4ai': [],
            'letta': [],
            
            # Ollama variants
            'ollama-cpu': [],
            'ollama-gpu': [],
            'ollama-gpu-amd': [],
        }
        
        self.startup_timeouts = {
            'shared-postgres': 60,
            'shared-redis': 30,
            'caddy': 30,
            'n8n': 120,
            'appflowy-cloud': 180,
            'affine': 180,
            'langfuse-web': 120,
            'default': 90
        }

    def show_enhanced_banner(self):
        """Display startup banner"""
        print("\n" + "="*100)
        print("🚀 AI-WORKSPACE LAUNCHER")
        print("="*100)
        print("🧠 AI Automation + 📝 Knowledge Management + 🎨 Development Environment")
        print()
        print("Unified Features:")
        print("  ⚡ Editor Integration  - Native Zed/VS Code with optimal performance")
        print("  🧠 AI Workflows       - n8n automation platform with worker scaling")
        print("  📝 Knowledge Hub       - AppFlowy & Affine for documentation")
        print("  🐳 Container Ops       - Portainer for service management")
        print("  🗄️  Unified Database    - Shared PostgreSQL for optimal performance")
        print("  🌐 Smart Routing      - Caddy with automatic HTTPS and load balancing")
        print("  📊 Full Observability - Grafana, Prometheus, Langfuse integration")
        print("="*100 + "\n")

    def check_system_requirements(self) -> Dict[str, Any]:
        """System requirements checking"""
        print("🔍 Analyzing system requirements...")
        
        requirements = {
            'docker': self._check_docker(),
            'compose': self._check_docker_compose(),
            'memory': self._check_memory(),
            'disk': self._check_disk_space(),
            'architecture': self._get_architecture(),
            'os': self._get_os_info(),
            'network': self._check_network(),
            'permissions': self._check_permissions()
        }
        
        # Display results
        print("\n📊 SYSTEM ANALYSIS:")
        print(f"  🐳 Docker:       {'✅ Available' if requirements['docker']['available'] else '❌ Missing'}")
        print(f"  📦 Compose:      {'✅ Available' if requirements['compose']['available'] else '❌ Missing'}")
        print(f"  💾 Memory:       {requirements['memory']['total_gb']}GB total, {requirements['memory']['available_gb']}GB available")
        print(f"  💿 Disk Space:   {requirements['disk']['free_gb']}GB free")
        print(f"  🖥️  Architecture: {requirements['architecture']}")
        print(f"  🐧 OS:           {requirements['os']['name']} {requirements['os']['version']}")
        print(f"  🌐 Network:      {'✅ Connected' if requirements['network']['connected'] else '❌ No connection'}")
        print(f"  👤 Permissions:  {'✅ Sufficient' if requirements['permissions']['sufficient'] else '⚠️  Limited'}")
        
        # Check minimum requirements
        issues = []
        if not requirements['docker']['available']:
            issues.append("Docker not available")
        if not requirements['compose']['available']:
            issues.append("Docker Compose not available")
        if requirements['memory']['available_gb'] < 4:
            issues.append(f"Low memory: {requirements['memory']['available_gb']}GB (4GB+ recommended)")
        if requirements['disk']['free_gb'] < 10:
            issues.append(f"Low disk space: {requirements['disk']['free_gb']}GB (10GB+ required)")
        
        if issues:
            print(f"\n⚠️  SYSTEM REQUIREMENTS ISSUES:")
            for issue in issues:
                print(f"   - {issue}")
            
            # Ask user if they want to continue
            if requirements['memory']['available_gb'] < 2 or requirements['disk']['free_gb'] < 5:
                print(f"\n❌ System does not meet minimum requirements.")
                return None
            else:
                proceed = input(f"\n⚠️  Continue with limited resources? (y/N): ").strip().lower()
                if proceed not in ['y', 'yes']:
                    return None
        else:
            print(f"\n✅ System meets all requirements!")
        
        return requirements

    def _check_docker(self) -> Dict[str, Any]:
        """Check Docker availability and version"""
        try:
            result = subprocess.run(['docker', '--version'], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                version = result.stdout.strip()
                
                # Check if daemon is running
                daemon_result = subprocess.run(['docker', 'info'], 
                                             capture_output=True, timeout=10)
                daemon_running = daemon_result.returncode == 0
                
                return {
                    'available': True,
                    'version': version,
                    'daemon_running': daemon_running
                }
            else:
                return {'available': False, 'version': None, 'daemon_running': False}
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return {'available': False, 'version': None, 'daemon_running': False}

    def _check_docker_compose(self) -> Dict[str, Any]:
        """Check Docker Compose availability"""
        # Try both 'docker compose' and 'docker-compose'
        for cmd in [['docker', 'compose', 'version'], ['docker-compose', '--version']]:
            try:
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
                if result.returncode == 0:
                    return {
                        'available': True,
                        'command': ' '.join(cmd[:2]),
                        'version': result.stdout.strip()
                    }
            except (subprocess.TimeoutExpired, FileNotFoundError):
                continue
        
        return {'available': False, 'command': None, 'version': None}

    def _check_memory(self) -> Dict[str, int]:
        """Check system memory"""
        try:
            with open('/proc/meminfo', 'r') as f:
                meminfo = f.read()
            
            total_kb = 0
            available_kb = 0
            
            for line in meminfo.split('\n'):
                if line.startswith('MemTotal:'):
                    total_kb = int(line.split()[1])
                elif line.startswith('MemAvailable:'):
                    available_kb = int(line.split()[1])
            
            return {
                'total_gb': round(total_kb / 1024 / 1024, 1),
                'available_gb': round(available_kb / 1024 / 1024, 1)
            }
        except:
            return {'total_gb': 0, 'available_gb': 0}

    def _check_disk_space(self) -> Dict[str, int]:
        """Check available disk space"""
        try:
            statvfs = os.statvfs('/')
            free_bytes = statvfs.f_frsize * statvfs.f_bavail
            total_bytes = statvfs.f_frsize * statvfs.f_blocks
            
            return {
                'free_gb': round(free_bytes / 1024**3, 1),
                'total_gb': round(total_bytes / 1024**3, 1)
            }
        except:
            return {'free_gb': 0, 'total_gb': 0}

    def _get_architecture(self) -> str:
        """Get system architecture"""
        return platform.machine()

    def _get_os_info(self) -> Dict[str, str]:
        """Get OS information"""
        try:
            with open('/etc/os-release', 'r') as f:
                os_release = f.read()
            
            info = {}
            for line in os_release.split('\n'):
                if '=' in line:
                    key, value = line.split('=', 1)
                    info[key] = value.strip('"')
            
            return {
                'name': info.get('PRETTY_NAME', platform.system()),
                'version': info.get('VERSION', 'Unknown'),
                'id': info.get('ID', 'unknown')
            }
        except:
            return {
                'name': platform.system(),
                'version': platform.release(),
                'id': 'unknown'
            }

    def _check_network(self) -> Dict[str, bool]:
        """Check network connectivity"""
        try:
            result = subprocess.run(['ping', '-c', '1', '-W', '3', '8.8.8.8'], 
                                  capture_output=True, timeout=10)
            return {'connected': result.returncode == 0}
        except:
            return {'connected': False}

    def _check_permissions(self) -> Dict[str, bool]:
        """Check required permissions"""
        docker_accessible = False
        try:
            result = subprocess.run(['docker', 'ps'], capture_output=True, timeout=10)
            docker_accessible = result.returncode == 0
        except:
            pass
        
        return {
            'sufficient': docker_accessible and os.access('/usr/local/bin', os.W_OK),
            'docker_accessible': docker_accessible,
            'can_install': os.access('/usr/local/bin', os.W_OK) or os.geteuid() == 0
        }

    def get_enabled_services(self) -> Dict[str, bool]:
        """Get enabled services from environment configuration"""
        env_values = dotenv_values(".env")
        compose_profiles = env_values.get("COMPOSE_PROFILES", "")
        
        services = {
            # Core services
            'n8n': 'n8n' in compose_profiles,
            'flowise': 'flowise' in compose_profiles,
            'open-webui': 'open-webui' in compose_profiles,
            
            # Knowledge management
            'appflowy': 'appflowy' in compose_profiles,
            'affine': 'affine' in compose_profiles,
            
            # Container management
            'portainer': 'portainer' in compose_profiles,
            
            # Infrastructure
            'supabase': 'supabase' in compose_profiles,
            'monitoring': 'monitoring' in compose_profiles,
            'langfuse': 'langfuse' in compose_profiles,
            
            # Databases
            'qdrant': 'qdrant' in compose_profiles,
            'weaviate': 'weaviate' in compose_profiles,
            'neo4j': 'neo4j' in compose_profiles,
            
            # Additional services
            'searxng': 'searxng' in compose_profiles,
            'crawl4ai': 'crawl4ai' in compose_profiles,
            'letta': 'letta' in compose_profiles,
            
            # Ollama variants
            'ollama': any(profile in compose_profiles for profile in ['cpu', 'gpu-nvidia', 'gpu-amd']),
            'ollama_type': next((profile for profile in ['cpu', 'gpu-nvidia', 'gpu-amd'] if profile in compose_profiles), None)
        }
        
        return services

    def check_editor_configuration(self) -> Dict[str, Any]:
        """Check existing editor configuration"""
        config_file = self.config_dir / "editor-choice.json"
        
        if config_file.exists():
            try:
                with open(config_file, 'r') as f:
                    config = json.load(f)
                
                # Check if selected editor is installed
                editor_type = config.get('editor_type', 'unknown')
                installation_type = config.get('installation_type', 'unknown')
                
                installed = False
                if installation_type == 'native':
                    if editor_type == 'zed':
                        installed = shutil.which('zed') is not None
                    elif editor_type == 'vscode':
                        installed = shutil.which('code') is not None
                elif installation_type == 'container':
                    # Check if container exists
                    try:
                        result = subprocess.run(['docker', 'ps', '-a', '--filter', f'name={editor_type}'], 
                                              capture_output=True, timeout=10)
                        installed = editor_type in result.stdout.decode()
                    except:
                        installed = False
                
                config['installed'] = installed
                return config
            except (json.JSONDecodeError, KeyError):
                return {'configured': False}
        
        return {'configured': False}

    def run_editor_selection(self):
        """Run the editor selection process"""
        print("🎨 Starting editor selection and configuration...")
        
        # Check if editor-selection script exists
        selection_script = self.project_root / "enhanced_editor_selection.py"
        if not selection_script.exists():
            print("❌ Editor selection script not found. Skipping editor setup.")
            return
        
        try:
            result = subprocess.run([sys.executable, str(selection_script)], 
                                  check=True, timeout=300)
            print("✅ Editor selection completed successfully!")
        except subprocess.CalledProcessError as e:
            print(f"❌ Editor selection failed: {e}")
        except subprocess.TimeoutExpired:
            print("⏱️  Editor selection timed out")

    def install_selected_editor(self) -> bool:
        """Install the selected editor"""
        config = self.check_editor_configuration()
        
        if not config.get('configured', False):
            print("⚠️  No editor configured. Run editor selection first.")
            return False
        
        if config.get('installed', False):
            print(f"✅ {config.get('editor_name', 'Selected editor')} already installed")
            return True
        
        # Run installation script
        install_script = self.config_dir / "install-selected-editor.sh"
        if not install_script.exists():
            print("❌ Installation script not found")
            return False
        
        print(f"🔧 Installing {config.get('editor_name', 'selected editor')}...")
        
        try:
            if config.get('installation_type') == 'native':
                # Native installation requires sudo
                result = subprocess.run(['sudo', 'bash', str(install_script)], 
                                      check=True, timeout=600)
            else:
                # Container installation
                result = subprocess.run(['bash', str(install_script)], 
                                      check=True, timeout=600)
            
            print("✅ Editor installed successfully!")
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ Editor installation failed: {e}")
            return False
        except subprocess.TimeoutExpired:
            print("⏱️  Editor installation timed out")
            return False

    def setup_workspace_structure(self):
        """Create workspace directory structure"""
        print("📁 Setting up enhanced workspace structure...")
        
        # Core directories
        directories = [
            # Shared data
            "shared",
            "shared/uploads",
            "shared/exports", 
            "shared/templates",
            "shared/backups",
            
            # Service data directories
            "data/postgres",
            "data/redis", 
            "data/caddy",
            
            # Development directories
            Path.home() / "Projects",
            Path.home() / "Projects" / "n8n-workflows",
            Path.home() / "Projects" / "ai-experiments",
            Path.home() / "Projects" / "docker-configs",
            Path.home() / "Projects" / "scripts",
            Path.home() / "Projects" / "knowledge-base",
            Path.home() / "Projects" / "tools",
            
            # Configuration directories
            "config/zed",
            "config/vscode",
            "config/caddy",
            
            # Logs
            "logs/services",
            "logs/editor",
            "logs/workspace"
        ]
        
        for directory in directories:
            Path(directory).mkdir(parents=True, exist_ok=True)
            print(f"  ✅ {directory}")
        
        # Create sample files and templates
        self._create_sample_files()
        
        print("✅ Workspace structure ready!")

    def _create_sample_files(self):
        """Create sample files and templates"""
        # Create welcome README
        readme_path = Path.home() / "Projects" / "README.md"
        if not readme_path.exists():
            readme_content = """# 🚀 Enhanced AI Workspace

Welcome to your unified development environment!

## 🏗️ Workspace Structure

- **n8n-workflows/**: Automation workflows and templates
- **ai-experiments/**: AI model experiments and notebooks  
- **docker-configs/**: Container configurations and compositions
- **scripts/**: Utility scripts and tools
- **knowledge-base/**: Documentation, notes, and wikis
- **tools/**: Development tools and helpers

## 🎨 Development Environment

Your workspace includes:
- Native code editor (Zed/VS Code) with optimal performance
- Integrated terminal and development tools
- Language servers for multiple programming languages
- Git integration and version control
- Project templates and scaffolding

## 🧠 AI Services Integration

Services available in your workspace:
- **n8n**: Workflow automation and AI orchestration
- **AppFlowy**: Knowledge management and documentation
- **Affine**: Collaborative workspace and project planning
- **Portainer**: Container management and monitoring

## 🚀 Quick Start

1. Open your editor: `zed` or `code`
2. Start a new project in the appropriate directory
3. Use service URLs for integration testing
4. Check service status: `docker ps`

Happy coding! ✨
"""
            readme_path.write_text(readme_content)

    def start_infrastructure_services(self) -> bool:
        """Start core infrastructure services first"""
        print("🏗️  Starting core infrastructure services...")
        
        infrastructure_services = [
            'shared-postgres',
            'shared-redis', 
            'caddy'
        ]
        
        for service in infrastructure_services:
            if not self._start_service(service):
                print(f"❌ Failed to start {service}")
                return False
        
        # Wait for infrastructure to be ready
        print("⏳ Waiting for infrastructure services to initialize...")
        time.sleep(20)
        
        # Verify infrastructure health
        if not self._verify_infrastructure_health():
            print("❌ Infrastructure health check failed")
            return False
        
        print("✅ Infrastructure services ready!")
        return True

    def start_knowledge_services(self) -> bool:
        """Start knowledge management services"""
        enabled_services = self.get_enabled_services()
        
        knowledge_services = []
        if enabled_services.get('appflowy', False):
            knowledge_services.extend([
                'appflowy-minio',
                'appflowy-gotrue', 
                'appflowy-cloud',
                'appflowy-web'
            ])
        
        if enabled_services.get('affine', False):
            knowledge_services.extend([
                'affine-migration',
                'affine'
            ])
        
        if not knowledge_services:
            print("📝 No knowledge management services enabled")
            return True
        
        print("📝 Starting knowledge management services...")
        
        # Start services in dependency order
        for service in knowledge_services:
            if not self._start_service(service):
                print(f"❌ Failed to start {service}")
                return False
            
            # Wait longer for knowledge services
            if service in ['appflowy-cloud', 'affine']:
                print(f"⏳ Waiting for {service} to initialize...")
                time.sleep(30)
        
        print("✅ Knowledge management services started!")
        return True

    def start_remaining_services(self) -> bool:
        """Start all remaining enabled services"""
        print("🚀 Starting remaining application services...")
        
        cmd = [
            "docker", "compose", "-p", "localai",
            "-f", "docker-compose.yml",
            "up", "-d"
        ]
        
        try:
            result = subprocess.run(cmd, check=True, timeout=300,
                                  capture_output=True, text=True)
            print("✅ All services started successfully!")
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to start services: {e}")
            if e.stderr:
                print(f"Error details: {e.stderr}")
            return False
        except subprocess.TimeoutExpired:
            print("⏱️  Service startup timed out")
            return False

    def _start_service(self, service_name: str) -> bool:
        """Start a specific service"""
        print(f"🔄 Starting {service_name}...")
        
        cmd = [
            "docker", "compose", "-p", "localai",
            "-f", "docker-compose.yml",
            "up", "-d", service_name
        ]
        
        try:
            result = subprocess.run(cmd, check=True, timeout=120,
                                  capture_output=True, text=True)
            print(f"✅ {service_name} started")
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to start {service_name}: {e}")
            return False
        except subprocess.TimeoutExpired:
            print(f"⏱️  {service_name} startup timed out")
            return False

    def _verify_infrastructure_health(self) -> bool:
        """Verify infrastructure services are healthy"""
        health_checks = [
            ("PostgreSQL", ["docker", "exec", "shared-postgres", "pg_isready", "-U", "postgres"]),
            ("Redis", ["docker", "exec", "shared-redis", "redis-cli", "ping"]),
            ("Caddy", ["docker", "exec", "caddy", "caddy", "version"])
        ]
        
        for service_name, cmd in health_checks:
            try:
                result = subprocess.run(cmd, capture_output=True, timeout=10)
                if result.returncode == 0:
                    print(f"  ✅ {service_name}: Healthy")
                else:
                    print(f"  ❌ {service_name}: Unhealthy")
                    return False
            except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
                print(f"  ❌ {service_name}: Health check failed")
                return False
        
        return True

    def perform_health_checks(self) -> Dict[str, bool]:
        """Perform comprehensive health checks on all services"""
        print("🔍 Performing comprehensive health checks...")
        
        enabled_services = self.get_enabled_services()
        health_results = {}
        
        # Define health check endpoints
        health_endpoints = {
            'n8n': ('localhost', 5678, '/healthz'),
            'flowise': ('localhost', 3001, '/api/v1/ping'),
            'open-webui': ('localhost', 8080, '/health'),
            'appflowy-web': ('localhost', 3000, '/'),
            'affine': ('localhost', 3010, '/api/health'),
            'portainer': ('localhost', 9000, '/api/system/status'),
            'grafana': ('localhost', 3000, '/api/health'),
            'langfuse-web': ('localhost', 3000, '/api/public/health'),
        }
        
        for service, (host, port, path) in health_endpoints.items():
            # Only check enabled services
            service_key = service.replace('-web', '').replace('-', '_')
            if not enabled_services.get(service_key, False):
                continue
            
            health_results[service] = self._check_service_health(service, host, port, path)
        
        # Summary
        healthy_count = sum(health_results.values())
        total_count = len(health_results)
        
        print(f"\n📊 Health Check Summary: {healthy_count}/{total_count} services healthy")
        
        if healthy_count < total_count:
            unhealthy = [service for service, healthy in health_results.items() if not healthy]
            print(f"⚠️  Unhealthy services: {', '.join(unhealthy)}")
            print("   Check logs with: docker logs <service_name>")
        
        return health_results

    def _check_service_health(self, service: str, host: str, port: int, path: str, timeout: int = 30) -> bool:
        """Check health of a specific service"""
        print(f"  🔍 Checking {service}...")
        
        start_time = time.time()
        while time.time() - start_time < timeout:
            try:
                result = subprocess.run([
                    "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}",
                    f"http://{host}:{port}{path}"
                ], capture_output=True, text=True, timeout=5)
                
                if result.returncode == 0:
                    status_code = result.stdout.strip()
                    if status_code.startswith(('200', '201', '204', '302')):
                        print(f"    ✅ {service}: Healthy (HTTP {status_code})")
                        return True
                    elif status_code.startswith(('401', '403')):
                        # Authentication required, but service is running
                        print(f"    ✅ {service}: Running (HTTP {status_code})")
                        return True
            except (subprocess.TimeoutExpired, FileNotFoundError):
                pass
            
            time.sleep(2)
        
        print(f"    ❌ {service}: Unhealthy (timeout)")
        return False

    def show_access_information(self):
        """Display comprehensive service access information"""
        enabled_services = self.get_enabled_services()
        env_values = dotenv_values(".env")
        editor_config = self.check_editor_configuration()
        
        domain = env_values.get("USER_DOMAIN_NAME", "localhost")
        protocol = "https" if domain != "localhost" else "http"
        
        print("\n" + "="*100)
        print("🌐 AI-WORKSPACE ACCESS INFORMATION")
        print("="*100)
        
        # Core Services
        print("\n🧠 CORE AI AUTOMATION:")
        if enabled_services.get('n8n', False):
            n8n_url = f"{protocol}://n8n.{domain}" if domain != "localhost" else "http://localhost:5678"
            print(f"   🧠 n8n Workflows:      {n8n_url}")
        
        if enabled_services.get('flowise', False):
            flowise_url = f"{protocol}://flowise.{domain}" if domain != "localhost" else "http://localhost:3001"
            print(f"   🤖 Flowise AI Builder: {flowise_url}")
        
        if enabled_services.get('open_webui', False):
            webui_url = f"{protocol}://webui.{domain}" if domain != "localhost" else "http://localhost:8080"
            print(f"   💬 Open WebUI Chat:    {webui_url}")
        
        # Knowledge Management
        knowledge_active = enabled_services.get('appflowy', False) or enabled_services.get('affine', False)
        if knowledge_active:
            print("\n📝 KNOWLEDGE MANAGEMENT:")
            
            if enabled_services.get('appflowy', False):
                appflowy_url = f"{protocol}://appflowy.{domain}" if domain != "localhost" else "http://localhost:3000"
                print(f"   📝 AppFlowy:           {appflowy_url}")
            
            if enabled_services.get('affine', False):
                affine_url = f"{protocol}://affine.{domain}" if domain != "localhost" else "http://localhost:3010"
                print(f"   ✨ Affine Workspace:   {affine_url}")
        
        # Container Management
        if enabled_services.get('portainer', False):
            print("\n🐳 CONTAINER MANAGEMENT:")
            portainer_url = f"{protocol}://portainer.{domain}" if domain != "localhost" else "http://localhost:9000"
            print(f"   🐳 Portainer:          {portainer_url}")
        
        # Development Environment
        print("\n🎨 DEVELOPMENT ENVIRONMENT:")
        if editor_config.get('configured', False):
            editor_name = editor_config.get('editor_name', 'Unknown')
            installation_type = editor_config.get('installation_type', 'unknown')
            
            if editor_config.get('installed', False):
                if installation_type == 'native':
                    editor_type = editor_config.get('editor_type', 'unknown')
                    print(f"   ⚡ {editor_name}: {editor_type} (launch from terminal)")
                    print(f"   📁 Projects: ~/Projects/")
                    print(f"   🚀 Quick start: {editor_type} ~/Projects/")
                else:
                    print(f"   🐳 {editor_name}: Container-based")
                    if 'vscode' in editor_config.get('editor_type', ''):
                        print(f"   🌐 Access: http://localhost:8080")
                    else:
                        print(f"   🖥️  Access: VNC to localhost:5900")
            else:
                print(f"   ⚠️  {editor_name}: Configured but not installed")
                print(f"   💡 Install with: bash editor-config/install-selected-editor.sh")
        else:
            print("   ⚠️  No editor configured")
            print("   🎨 Setup editor: python editor_selection.py")
        
        # Infrastructure Services
        infrastructure_services = ['monitoring', 'langfuse', 'supabase']
        if any(enabled_services.get(service, False) for service in infrastructure_services):
            print("\n🔧 INFRASTRUCTURE:")
            
            if enabled_services.get('monitoring', False):
                grafana_url = f"{protocol}://grafana.{domain}" if domain != "localhost" else "http://localhost:3000"
                print(f"   📊 Grafana:            {grafana_url}")
            
            if enabled_services.get('langfuse', False):
                langfuse_url = f"{protocol}://langfuse.{domain}" if domain != "localhost" else "http://localhost:3000"
                print(f"   📈 Langfuse:           {langfuse_url}")
            
            if enabled_services.get('supabase', False):
                supabase_url = f"{protocol}://supabase.{domain}" if domain != "localhost" else "http://localhost:8000"
                print(f"   🗄️  Supabase:           {supabase_url}")
        
        # Quick Actions
        print("\n💡 QUICK ACTIONS:")
        print("   📊 Service status:     docker ps")
        print("   📋 Service logs:       docker logs <service_name>")
        print("   🔄 Restart service:    docker restart <service_name>")
        print("   🛑 Stop all:           docker-compose -p localai down")
        
        if editor_config.get('installed', False) and editor_config.get('installation_type') == 'native':
            editor_type = editor_config.get('editor_type', 'editor')
            print(f"   🎨 Open editor:        {editor_type} ~/Projects/")
        
        print("   🚀 Full restart:       python start_services.py restart")
        
        print("="*100)

    def create_management_scripts(self):
        """Create useful management scripts"""
        print("📜 Creating workspace management scripts...")
        
        scripts_dir = Path.home() / "Projects" / "scripts"
        scripts_dir.mkdir(exist_ok=True)
        
        scripts = {
            'workspace-status.sh': self._get_status_script(),
            'workspace-logs.sh': self._get_logs_script(),
            'workspace-backup.sh': self._get_backup_script(),
            'dev-session.sh': self._get_dev_session_script(),
            'service-restart.sh': self._get_service_restart_script()
        }
        
        for script_name, script_content in scripts.items():
            script_path = scripts_dir / script_name
            script_path.write_text(script_content)
            script_path.chmod(0o755)
            print(f"  ✅ {script_name}")
        
        print("✅ Management scripts created!")

    def _get_status_script(self) -> str:
        return """#!/bin/bash
# Workspace Status Script

echo "🚀 AI-Workspace Status"
echo "=" * 50

echo "🐳 Docker Services:"
docker ps --format "table {{.Names}}\\t{{.Status}}\\t{{.Ports}}" | grep -E "(n8n|appflowy|affine|portainer|grafana|caddy)"

echo ""
echo "💾 Resource Usage:"
docker stats --no-stream --format "table {{.Container}}\\t{{.CPUPerc}}\\t{{.MemUsage}}"

echo ""
echo "🌐 Service URLs:"
echo "  n8n:       http://localhost:5678"
echo "  AppFlowy:  http://localhost:3000"
echo "  Affine:    http://localhost:3010"
echo "  Portainer: http://localhost:9000"

echo ""
echo "📁 Workspace Directories:"
ls -la ~/Projects/
"""

    def _get_logs_script(self) -> str:
        return """#!/bin/bash
# Workspace Logs Script

SERVICE=${1:-n8n}
LINES=${2:-50}

echo "📋 Viewing logs for $SERVICE (last $LINES lines):"
echo "=" * 50

docker logs --tail $LINES -f $SERVICE
"""

    def _get_backup_script(self) -> str:
        return """#!/bin/bash
# Workspace Backup Script

BACKUP_DIR="$HOME/workspace-backups"
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="workspace-backup-$DATE"

echo "💾 Creating workspace backup: $BACKUP_NAME"

mkdir -p "$BACKUP_DIR"

# Backup PostgreSQL databases
echo "📊 Backing up databases..."
docker exec shared-postgres pg_dumpall -U postgres > "$BACKUP_DIR/$BACKUP_NAME-databases.sql"

# Backup configuration
echo "⚙️ Backing up configuration..."
tar -czf "$BACKUP_DIR/$BACKUP_NAME-config.tar.gz" .env editor-config/

# Backup projects
echo "📁 Backing up projects..."
tar -czf "$BACKUP_DIR/$BACKUP_NAME-projects.tar.gz" -C "$HOME" Projects/

echo "✅ Backup completed: $BACKUP_DIR/$BACKUP_NAME*"
"""

    def _get_dev_session_script(self) -> str:
        editor_config = self.check_editor_configuration()
        editor_command = "echo 'No editor configured'"
        
        if editor_config.get('installed', False):
            if editor_config.get('installation_type') == 'native':
                editor_type = editor_config.get('editor_type', 'nano')
                editor_command = f"{editor_type} ~/Projects/"
        
        return f"""#!/bin/bash
# Development Session Setup

echo "🎨 Starting development session..."

cd ~/Projects

echo "📊 Workspace Status:"
docker ps --format "table {{{{.Names}}}}\\t{{{{.Status}}}}" | head -10

echo ""
echo "📁 Available Projects:"
ls -la

echo ""
echo "🚀 Development Environment Ready!"
echo ""
echo "Quick commands:"
echo "  Open editor:     {editor_command}"
echo "  Service status:  docker ps"
echo "  View logs:       docker logs <service>"
echo ""

# Start editor if available
{editor_command}
"""

    def _get_service_restart_script(self) -> str:
        return """#!/bin/bash
# Service Restart Script

SERVICE=${1:-}

if [ -z "$SERVICE" ]; then
    echo "Usage: $0 <service_name>"
    echo "Available services:"
    docker ps --format "{{.Names}}" | grep -E "(n8n|appflowy|affine|portainer)"
    exit 1
fi

echo "🔄 Restarting $SERVICE..."
docker restart $SERVICE

echo "⏳ Waiting for service to be ready..."
sleep 10

echo "✅ $SERVICE restarted"
docker logs --tail 20 $SERVICE
"""


def main():
    """Main orchestration function"""
    parser = argparse.ArgumentParser(description='Enhanced n8n-installer + Workspace Launcher')
    parser.add_argument('action', nargs='?', choices=['up', 'down', 'restart', 'status', 'editor'], 
                       default='up', help='Action to perform')
    parser.add_argument('--skip-editor', action='store_true', 
                       help='Skip editor installation and configuration')
    parser.add_argument('--skip-health-check', action='store_true',
                       help='Skip comprehensive health checks')
    parser.add_argument('--force-editor-setup', action='store_true',
                       help='Force editor selection even if already configured')
    
    args = parser.parse_args()
    
    workspace = EnhancedWorkspaceManager()
    
    if args.action == 'down':
        print("🛑 Stopping all workspace services...")
        subprocess.run(["docker", "compose", "-p", "localai", "down"])
        print("✅ All services stopped")
        return
    
    if args.action == 'status':
        workspace.show_access_information()
        return
    
    if args.action == 'editor':
        workspace.run_editor_selection()
        workspace.install_selected_editor()
        return
    
    if args.action == 'restart':
        print("🔄 Restarting workspace...")
        subprocess.run(["docker", "compose", "-p", "localai", "down"])
        time.sleep(5)
    
    # Main startup sequence
    workspace.show_enhanced_banner()
    
    # System requirements check
    requirements = workspace.check_system_requirements()
    if requirements is None:
        sys.exit(1)
    
    # Show startup plan
    enabled_services = workspace.get_enabled_services()
    enabled_count = sum(1 for enabled in enabled_services.values() if enabled)
    
    print(f"🎯 STARTUP PLAN: {enabled_count} services to deploy")
    print("📋 Services: " + ", ".join([k for k, v in enabled_services.items() if v and k != 'ollama_type']))
    
    # Confirm startup
    confirm = input("\n🚀 Start the enhanced workspace? (Y/n): ").strip().lower()
    if confirm in ['n', 'no']:
        print("👋 Startup cancelled")
        return
    
    # Setup workspace structure
    workspace.setup_workspace_structure()
    
    # Editor setup
    if not args.skip_editor:
        editor_config = workspace.check_editor_configuration()
        
        if not editor_config.get('configured', False) or args.force_editor_setup:
            workspace.run_editor_selection()
        
        if not editor_config.get('installed', False):
            workspace.install_selected_editor()
    
    # Service startup sequence
    print("\n🏗️  Starting workspace services...")
    
    # 1. Infrastructure first
    if not workspace.start_infrastructure_services():
        print("❌ Infrastructure startup failed")
        sys.exit(1)
    
    # 2. Knowledge management services
    if not workspace.start_knowledge_services():
        print("⚠️  Knowledge services startup had issues, continuing...")
    
    # 3. All remaining services
    if not workspace.start_remaining_services():
        print("❌ Service startup failed")
        sys.exit(1)
    
    # Health checks
    if not args.skip_health_check:
        print("\n🔍 Performing health checks...")
        health_results = workspace.perform_health_checks()
        
        if not all(health_results.values()):
            print("⚠️  Some services may need attention")
    
    # Create management tools
    workspace.create_management_scripts()
    
    # Success! Show access information
    workspace.show_access_information()
    
    print(f"\n🎉 AI-WORKSPACE IS READY!")
    print("Your complete AI development and knowledge management environment is now running.")
    print("Happy building! 🚀✨")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n👋 Startup interrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)
