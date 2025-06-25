#!/usr/bin/env python3
"""
start_services.py

This script starts the Supabase stack first, waits for it to initialize, and then starts
the local AI stack. Both stacks use the same Docker Compose project name ("localai")
so they appear together in Docker Desktop.

Now includes support for AppFlowy and Affine knowledge management services.
"""

import os
import subprocess
import shutil
import time
import argparse
import platform
import sys
from dotenv import dotenv_values

def is_service_enabled(service_name):
    """Check if a service is in COMPOSE_PROFILES in .env file."""
    env_values = dotenv_values(".env")
    compose_profiles = env_values.get("COMPOSE_PROFILES", "")
    return service_name in compose_profiles.split(',')

def is_supabase_enabled():
    """Check if 'supabase' is in COMPOSE_PROFILES in .env file."""
    return is_service_enabled("supabase")

def is_appflowy_enabled():
    """Check if 'appflowy' is in COMPOSE_PROFILES in .env file."""
    return is_service_enabled("appflowy")

def is_affine_enabled():
    """Check if 'affine' is in COMPOSE_PROFILES in .env file."""
    return is_service_enabled("affine")

def run_command(cmd, cwd=None):
    """Run a shell command and print it."""
    print("Running:", " ".join(cmd))
    subprocess.run(cmd, cwd=cwd, check=True)

def clone_supabase_repo():
    """Clone the Supabase repository using sparse checkout if not already present."""
    if not is_supabase_enabled():
        print("Supabase is not enabled, skipping clone.")
        return
    if not os.path.exists("supabase"):
        print("Cloning the Supabase repository...")
        run_command([
            "git", "clone", "--filter=blob:none", "--no-checkout",
            "https://github.com/supabase/supabase.git"
        ])
        os.chdir("supabase")
        run_command(["git", "sparse-checkout", "init", "--cone"])
        run_command(["git", "sparse-checkout", "set", "docker"])
        run_command(["git", "checkout", "master"])
        os.chdir("..")
    else:
        print("Supabase repository already exists, updating...")
        os.chdir("supabase")
        run_command(["git", "pull"])
        os.chdir("..")

def prepare_supabase_env():
    """Copy .env to .env in supabase/docker."""
    if not is_supabase_enabled():
        print("Supabase is not enabled, skipping env preparation.")
        return
    env_path = os.path.join("supabase", "docker", ".env")
    env_example_path = os.path.join(".env")
    print("Copying .env in root to .env in supabase/docker...")
    shutil.copyfile(env_example_path, env_path)

def setup_appflowy_storage():
    """Setup AppFlowy MinIO buckets if AppFlowy is enabled."""
    if not is_appflowy_enabled():
        print("AppFlowy is not enabled, skipping storage setup.")
        return
    
    print("Setting up AppFlowy storage...")
    # AppFlowy will automatically create the required bucket through its services
    # No additional setup needed as the bucket creation is handled by the service initialization
    print("AppFlowy storage setup will be handled by the service itself.")

def setup_affine_storage():
    """Setup Affine storage directories if Affine is enabled."""
    if not is_affine_enabled():
        print("Affine is not enabled, skipping storage setup.")
        return
    
    print("Setting up Affine storage...")
    # Affine uses Docker volumes for storage, no manual setup needed
    # The volumes are automatically created by Docker Compose
    print("Affine storage will be handled by Docker volumes.")

def stop_existing_containers():
    """Stop and remove existing containers for our unified project ('localai')."""
    print("Stopping and removing existing containers for the unified project 'localai'...")
    cmd = [
        "docker", "compose",
        "-p", "localai",
        "-f", "docker-compose.yml"
    ]
    if is_supabase_enabled():
        cmd.extend(["-f", "supabase/docker/docker-compose.yml"])
    cmd.append("down")
    run_command(cmd)

def start_supabase():
    """Start the Supabase services (using its compose file)."""
    if not is_supabase_enabled():
        print("Supabase is not enabled, skipping start.")
        return
    print("Starting Supabase services...")
    run_command([
        "docker", "compose", "-p", "localai", "-f", "supabase/docker/docker-compose.yml", "up", "-d"
    ])

def start_local_ai():
    """Start the local AI services (using its compose file)."""
    print("Starting local AI services...")
    cmd = ["docker", "compose", "-p", "localai"]
    cmd.extend(["-f", "docker-compose.yml", "up", "-d"])
    run_command(cmd)

def wait_for_services():
    """Wait for critical services to be ready."""
    enabled_services = []
    
    if is_appflowy_enabled():
        enabled_services.append("AppFlowy")
    if is_affine_enabled():
        enabled_services.append("Affine")
    if is_supabase_enabled():
        enabled_services.append("Supabase")
    
    if enabled_services:
        print(f"Waiting for {', '.join(enabled_services)} services to initialize...")
        time.sleep(20)  # Give extra time for knowledge management services
    else:
        print("Waiting for core services to initialize...")
        time.sleep(10)

def check_service_health():
    """Check if enabled services are healthy."""
    print("Checking service health...")
    
    # Check AppFlowy services
    if is_appflowy_enabled():
        try:
            result = subprocess.run([
                "docker", "compose", "-p", "localai", "ps", "--filter", "name=appflowy", "--format", "table"
            ], capture_output=True, text=True, check=False)
            if result.returncode == 0:
                print("✓ AppFlowy services are running")
            else:
                print("⚠ AppFlowy services may have issues")
        except Exception as e:
            print(f"⚠ Could not check AppFlowy status: {e}")
    
    # Check Affine services
    if is_affine_enabled():
        try:
            result = subprocess.run([
                "docker", "compose", "-p", "localai", "ps", "--filter", "name=affine", "--format", "table"
            ], capture_output=True, text=True, check=False)
            if result.returncode == 0:
                print("✓ Affine services are running")
            else:
                print("⚠ Affine services may have issues")
        except Exception as e:
            print(f"⚠ Could not check Affine status: {e}")
    
    # Check Supabase services
    if is_supabase_enabled():
        try:
            result = subprocess.run([
                "docker", "compose", "-p", "localai", "-f", "supabase/docker/docker-compose.yml", "ps", "--format", "table"
            ], capture_output=True, text=True, check=False)
            if result.returncode == 0:
                print("✓ Supabase services are running")
            else:
                print("⚠ Supabase services may have issues")
        except Exception as e:
            print(f"⚠ Could not check Supabase status: {e}")

def generate_searxng_secret_key():
    """Generate a secret key for SearXNG based on the current platform."""
    print("Checking SearXNG settings...")

    # Define paths for SearXNG settings files
    settings_path = os.path.join("searxng", "settings.yml")
    settings_base_path = os.path.join("searxng", "settings-base.yml")

    # Check if settings-base.yml exists
    if not os.path.exists(settings_base_path):
        print(f"Warning: SearXNG base settings file not found at {settings_base_path}")
        return

    # Check if settings.yml exists, if not create it from settings-base.yml
    if not os.path.exists(settings_path):
        print(f"SearXNG settings.yml not found. Creating from {settings_base_path}...")
        try:
            shutil.copyfile(settings_base_path, settings_path)
            print(f"Created {settings_path} from {settings_base_path}")
        except Exception as e:
            print(f"Error creating settings.yml: {e}")
            return
    else:
        print(f"SearXNG settings.yml already exists at {settings_path}")

    print("Generating SearXNG secret key...")

    # Detect the platform and run the appropriate command
    system = platform.system()

    try:
        if system == "Windows":
            print("Detected Windows platform, using PowerShell to generate secret key...")
            # PowerShell command to generate a random key and replace in the settings file
            ps_command = [
                "powershell", "-Command",
                "$randomBytes = New-Object byte[] 32; " +
                "(New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes($randomBytes); " +
                "$secretKey = -join ($randomBytes | ForEach-Object { \"{0:x2}\" -f $_ }); " +
                "(Get-Content searxng/settings.yml) -replace 'ultrasecretkey', $secretKey | Set-Content searxng/settings.yml"
            ]
            subprocess.run(ps_command, check=True)

        elif system == "Darwin":  # macOS
            print("Detected macOS platform, using sed command with empty string parameter...")
            # macOS sed command requires an empty string for the -i parameter
            openssl_cmd = ["openssl", "rand", "-hex", "32"]
            random_key = subprocess.check_output(openssl_cmd).decode('utf-8').strip()
            sed_cmd = ["sed", "-i", "", f"s|ultrasecretkey|{random_key}|g", settings_path]
            subprocess.run(sed_cmd, check=True)

        else:  # Linux and other Unix-like systems
            print("Detected Linux/Unix platform, using standard sed command...")
            # Standard sed command for Linux
            openssl_cmd = ["openssl", "rand", "-hex", "32"]
            random_key = subprocess.check_output(openssl_cmd).decode('utf-8').strip()
            sed_cmd = ["sed", "-i", f"s|ultrasecretkey|{random_key}|g", settings_path]
            subprocess.run(sed_cmd, check=True)

        print("SearXNG secret key generated successfully.")

    except Exception as e:
        print(f"Error generating SearXNG secret key: {e}")
        print("You may need to manually generate the secret key using the commands:")
        print("  - Linux: sed -i \"s|ultrasecretkey|$(openssl rand -hex 32)|g\" searxng/settings.yml")
        print("  - macOS: sed -i '' \"s|ultrasecretkey|$(openssl rand -hex 32)|g\" searxng/settings.yml")
        print("  - Windows (PowerShell):")
        print("    $randomBytes = New-Object byte[] 32")
        print("    (New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes($randomBytes)")
        print("    $secretKey = -join ($randomBytes | ForEach-Object { \"{0:x2}\" -f $_ })")
        print("    (Get-Content searxng/settings.yml) -replace 'ultrasecretkey', $secretKey | Set-Content searxng/settings.yml")

def check_and_fix_docker_compose_for_searxng():
    """Check and modify docker-compose.yml for SearXNG first run."""
    docker_compose_path = "docker-compose.yml"
    if not os.path.exists(docker_compose_path):
        print(f"Warning: Docker Compose file not found at {docker_compose_path}")
        return

    try:
        # Read the docker-compose.yml file
        with open(docker_compose_path, 'r') as file:
            content = file.read()

        # Default to first run
        is_first_run = True

        # Check if Docker is running and if the SearXNG container exists
        try:
            # Check if the SearXNG container is running
            container_check = subprocess.run(
                ["docker", "ps", "--filter", "name=searxng", "--format", "{{.Names}}"],
                capture_output=True, text=True, check=True
            )
            searxng_containers = container_check.stdout.strip().split('\n')

            # If SearXNG container is running, check inside for uwsgi.ini
            if any(container for container in searxng_containers if container):
                container_name = next(container for container in searxng_containers if container)
                print(f"Found running SearXNG container: {container_name}")

                # Check if uwsgi.ini exists inside the container
                container_check = subprocess.run(
                    ["docker", "exec", container_name, "sh", "-c", "[ -f /etc/searxng/uwsgi.ini ] && echo 'found' || echo 'not_found'"],
                    capture_output=True, text=True, check=False
                )

                if "found" in container_check.stdout:
                    print("Found uwsgi.ini inside the SearXNG container - not first run")
                    is_first_run = False
                else:
                    print("uwsgi.ini not found inside the SearXNG container - first run")
                    is_first_run = True
            else:
                print("No running SearXNG container found - assuming first run")
        except Exception as e:
            print(f"Error checking Docker container: {e} - assuming first run")

        if is_first_run and "cap_drop: - ALL" in content:
            print("First run detected for SearXNG. Temporarily removing 'cap_drop: - ALL' directive...")
            # Temporarily comment out the cap_drop line
            modified_content = content.replace("cap_drop: - ALL", "# cap_drop: - ALL  # Temporarily commented out for first run")

            # Write the modified content back
            with open(docker_compose_path, 'w') as file:
                file.write(modified_content)

            print("Note: After the first run completes successfully, you should re-add 'cap_drop: - ALL' to docker-compose.yml for security reasons.")
        elif not is_first_run and "# cap_drop: - ALL  # Temporarily commented out for first run" in content:
            print("SearXNG has been initialized. Re-enabling 'cap_drop: - ALL' directive for security...")
            # Uncomment the cap_drop line and ensure correct multi-line YAML format
            correct_cap_drop_block = "cap_drop:\n      - ALL" # Note the newline and indentation for the list item
            modified_content = content.replace("# cap_drop: - ALL  # Temporarily commented out for first run", correct_cap_drop_block)
            
            # Write the modified content back
            with open(docker_compose_path, 'w') as file:
                file.write(modified_content)

    except Exception as e:
        print(f"Error checking/modifying docker-compose.yml for SearXNG: {e}")

def print_startup_summary():
    """Print a summary of which services are being started."""
    print("\n" + "="*50)
    print("STARTING SERVICES SUMMARY")
    print("="*50)
    
    enabled_services = []
    
    # Core services (always enabled)
    print("Core Services (Always Enabled):")
    print("  ✓ n8n (Workflow Automation)")
    print("  ✓ Caddy (Reverse Proxy)")
    print("  ✓ PostgreSQL (Database)")
    print("  ✓ Redis (Cache)")
    
    # Optional services
    optional_services = {
        "supabase": "Supabase (Backend as a Service)",
        "flowise": "Flowise (AI Agent Builder)",
        "open-webui": "Open WebUI (ChatGPT Interface)",
        "appflowy": "AppFlowy (Knowledge Management)",
        "affine": "Affine (Collaborative Workspace)",
        "qdrant": "Qdrant (Vector Database)",
        "weaviate": "Weaviate (Vector Database)",
        "neo4j": "Neo4j (Graph Database)",
        "searxng": "SearXNG (Private Search)",
        "langfuse": "Langfuse (AI Observability)",
        "monitoring": "Monitoring (Grafana + Prometheus)",
        "crawl4ai": "Crawl4AI (Web Crawler)",
        "letta": "Letta (Agent Server)",
        "cpu": "Ollama (CPU)",
        "gpu-nvidia": "Ollama (NVIDIA GPU)",
        "gpu-amd": "Ollama (AMD GPU)"
    }
    
    print("\nOptional Services:")
    for service, description in optional_services.items():
        if is_service_enabled(service):
            print(f"  ✓ {description}")
            enabled_services.append(service)
    
    if not enabled_services:
        print("  (None selected)")
    
    print("="*50 + "\n")

def main():
    print_startup_summary()
    
    if is_supabase_enabled():
        clone_supabase_repo()
        prepare_supabase_env()
    
    # Setup storage for knowledge management services
    setup_appflowy_storage()
    setup_affine_storage()
    
    # Generate SearXNG secret key and check docker-compose.yml
    generate_searxng_secret_key()
    check_and_fix_docker_compose_for_searxng()
    
    stop_existing_containers()
    
    # Start Supabase first
    if is_supabase_enabled():
        start_supabase()
    
        # Give Supabase some time to initialize
        print("Waiting for Supabase to initialize...")
        time.sleep(10)
    
    # Then start the local AI services
    start_local_ai()
    
    # Wait for services to be ready
    wait_for_services()
    
    # Check service health
    check_service_health()
    
    print("\n" + "="*50)
    print("SERVICE STARTUP COMPLETE")
    print("="*50)
    print("All enabled services should now be running.")
    print("Check the final report for access URLs and credentials.")
    print("Use 'docker compose -p localai ps' to see service status.")

if __name__ == "__main__":
    main()
