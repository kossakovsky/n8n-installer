#!/usr/bin/env python3
"""
start_services.py

This script starts the Supabase stack first, waits for it to initialize, and then starts
the local AI stack. Both stacks use the same Docker Compose project name ("localai")
so they appear together in Docker Desktop.
"""

import os
import subprocess
import shutil
import time
import argparse
import platform
import sys
import yaml
from dotenv import dotenv_values

def is_supabase_enabled():
    """Check if 'supabase' is in COMPOSE_PROFILES in .env file."""
    env_values = dotenv_values(".env")
    compose_profiles = env_values.get("COMPOSE_PROFILES", "")
    return "supabase" in compose_profiles.split(',')

def is_dify_enabled():
    """Check if 'dify' is in COMPOSE_PROFILES in .env file."""
    env_values = dotenv_values(".env")
    compose_profiles = env_values.get("COMPOSE_PROFILES", "")
    return "dify" in compose_profiles.split(',')

def get_all_profiles(compose_file):
    """Get all profile names from a docker-compose file."""
    if not os.path.exists(compose_file):
        return []
    
    with open(compose_file, 'r') as f:
        compose_config = yaml.safe_load(f)

    profiles = set()
    if 'services' in compose_config:
        for service_name, service_config in compose_config.get('services', {}).items():
            if service_config and 'profiles' in service_config:
                for profile in service_config['profiles']:
                    profiles.add(profile)
    return list(profiles)

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

def clone_dify_repo():
    """Clone the Dify repository using sparse checkout if not already present."""
    if not is_dify_enabled():
        print("Dify is not enabled, skipping clone.")
        return
    if not os.path.exists("dify"):
        print("Cloning the Dify repository...")
        run_command([
            "git", "clone", "--filter=blob:none", "--no-checkout",
            "https://github.com/langgenius/dify.git"
        ])
        os.chdir("dify")
        run_command(["git", "sparse-checkout", "init", "--cone"])
        run_command(["git", "sparse-checkout", "set", "docker"])
        # Dify's default branch is 'main'
        run_command(["git", "checkout", "main"])
        os.chdir("..")
    else:
        print("Dify repository already exists, updating...")
        os.chdir("dify")
        run_command(["git", "pull"])
        os.chdir("..")

def prepare_dify_env():
    """Create dify/docker/.env from env.example and inject selected values from root .env.

    Mapping (strip DIFY_ prefix from root .env):
      - DIFY_SECRET_KEY -> SECRET_KEY
      - DIFY_EXPOSE_NGINX_PORT -> EXPOSE_NGINX_PORT
      - DIFY_EXPOSE_NGINX_SSL_PORT -> EXPOSE_NGINX_SSL_PORT
    """
    if not is_dify_enabled():
        print("Dify is not enabled, skipping env preparation.")
        return

    dify_docker_dir = os.path.join("dify", "docker")
    if not os.path.isdir(dify_docker_dir):
        print(f"Warning: Dify docker directory not found at {dify_docker_dir}. Have you cloned the repo?")
        return

    # Determine env example file name: prefer 'env.example', fallback to '.env.example'
    env_example_candidates = [
        os.path.join(dify_docker_dir, "env.example"),
        os.path.join(dify_docker_dir, ".env.example"),
    ]
    env_example_path = next((p for p in env_example_candidates if os.path.exists(p)), None)

    if env_example_path is None:
        print(f"Warning: Could not find env.example in {dify_docker_dir}")
        return

    env_path = os.path.join(dify_docker_dir, ".env")

    print(f"Creating {env_path} from {env_example_path}...")
    with open(env_example_path, 'r') as f:
        env_content = f.read()

    # Load values from root .env
    root_env = dotenv_values(".env")
    mapping = {
        "SECRET_KEY": root_env.get("DIFY_SECRET_KEY", ""),
        "EXPOSE_NGINX_PORT": root_env.get("DIFY_EXPOSE_NGINX_PORT", ""),
        "EXPOSE_NGINX_SSL_PORT": root_env.get("DIFY_EXPOSE_NGINX_SSL_PORT", ""),
    }

    # Replace or append variables in env_content
    lines = env_content.splitlines()
    replaced_keys = set()
    for i, line in enumerate(lines):
        for dest_key, value in mapping.items():
            if line.startswith(f"{dest_key}=") and value:
                lines[i] = f"{dest_key}={value}"
                replaced_keys.add(dest_key)

    # Append any missing keys with values
    for dest_key, value in mapping.items():
        if value and dest_key not in replaced_keys:
            lines.append(f"{dest_key}={value}")

    with open(env_path, 'w') as f:
        f.write("\n".join(lines) + "\n")

def stop_existing_containers():
    """Stop and remove existing containers for our unified project ('localai')."""
    print("Stopping and removing existing containers for the unified project 'localai'...")
    
    # Base command
    cmd = ["docker", "compose", "-p", "localai"]

    # Get all profiles from the main docker-compose.yml to ensure all services can be brought down
    all_profiles = get_all_profiles("docker-compose.yml")
    for profile in all_profiles:
        cmd.extend(["--profile", profile])
    
    cmd.extend(["-f", "docker-compose.yml"])

    # Check if the Supabase Docker Compose file exists. If so, include it in the 'down' command.
    supabase_compose_path = os.path.join("supabase", "docker", "docker-compose.yml")
    if os.path.exists(supabase_compose_path):
        cmd.extend(["-f", supabase_compose_path])
    
    # Check if the Dify Docker Compose file exists. If so, include it in the 'down' command.
    dify_compose_path = os.path.join("dify", "docker", "docker-compose.yaml")
    if os.path.exists(dify_compose_path):
        cmd.extend(["-f", dify_compose_path])

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

def start_dify():
    """Start the Dify services (using its compose file)."""
    if not is_dify_enabled():
        print("Dify is not enabled, skipping start.")
        return
    print("Starting Dify services...")
    run_command([
        "docker", "compose", "-p", "localai", "-f", "dify/docker/docker-compose.yaml", "up", "-d"
    ])

def start_local_ai():
    """Start the local AI services (using its compose file)."""
    print("Starting local AI services...")

    # Explicitly build services and pull newer base images first.
    print("Checking for newer base images and building services...")
    build_cmd = ["docker", "compose", "-p", "localai", "-f", "docker-compose.yml", "build", "--pull"]
    run_command(build_cmd)

    # Now, start the services using the newly built images. No --build needed as we just built.
    print("Starting containers...")
    up_cmd = ["docker", "compose", "-p", "localai", "-f", "docker-compose.yml", "up", "-d"]
    run_command(up_cmd)

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

def main():
    # Clone and prepare repositories
    if is_supabase_enabled():
        clone_supabase_repo()
        prepare_supabase_env()
    
    if is_dify_enabled():
        clone_dify_repo()
        prepare_dify_env()
    
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
    
    # Start Dify services
    if is_dify_enabled():
        start_dify()
        # Give Dify some time to initialize
        print("Waiting for Dify to initialize...")
        time.sleep(10)
    
    # Then start the local AI services
    start_local_ai()

if __name__ == "__main__":
    main()
