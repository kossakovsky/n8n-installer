#!/usr/bin/env python3
"""
Editor Selection for Unified n8n-installer + Workspace
Supports both native installation and container-based development
"""

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Tuple


class EnhancedEditorSetup:
    def __init__(self):
        self.available_editors = {
            "zed_native": {
                "name": "Zed Editor (Native)",
                "description": "Lightning-fast native editor with AI features",
                "features": [
                    "🚀 Ultra-fast performance (native binary)",
                    "🤝 Built-in collaboration features",
                    "🧠 AI assistant integration",
                    "⚡ Instant startup time",
                    "🔧 Advanced LSP support",
                    "🎨 Modern UI with themes"
                ],
                "install_method": "native_download",
                "performance": "excellent",
                "resource_usage": "low",
                "default": True,
            },
            "vscode_native": {
                "name": "Visual Studio Code (Native)",
                "description": "Feature-rich editor with extensive extension ecosystem",
                "features": [
                    "🔌 Massive extension marketplace",
                    "🐛 Advanced debugging capabilities",
                    "📊 Integrated Git workflow",
                    "🌐 Remote development support",
                    "📝 IntelliSense and code completion",
                    "🔄 Live Share collaboration"
                ],
                "install_method": "apt_repository",
                "performance": "good",
                "resource_usage": "medium",
                "default": False,
            },
            "zed_container": {
                "name": "Zed Editor (Container)",
                "description": "Zed in isolated container environment",
                "features": [
                    "🐳 Containerized isolation",
                    "🔒 Sandboxed execution",
                    "📦 Portable development environment",
                    "🔄 Easy backup and migration",
                    "⚡ Fast performance in container",
                    "🌐 Web-accessible interface"
                ],
                "install_method": "container_build",
                "performance": "good",
                "resource_usage": "medium",
                "default": False,
            },
            "vscode_container": {
                "name": "VS Code (Container)",
                "description": "VS Code in container with code-server",
                "features": [
                    "🌐 Web-based interface",
                    "🐳 Containerized environment",
                    "🔌 Extension support via code-server",
                    "📱 Access from any device",
                    "🔒 Isolated development environment",
                    "☁️ Cloud-ready setup"
                ],
                "install_method": "container_build",
                "performance": "fair",
                "resource_usage": "high",
                "default": False,
            }
        }
        
        self.config_dir = Path("editor-config")
        self.config_dir.mkdir(exist_ok=True)

    def detect_system_capabilities(self) -> Dict[str, bool]:
        """Detect system capabilities for editor installation"""
        capabilities = {
            "has_display": bool(os.environ.get("DISPLAY")),
            "has_docker": self._check_command("docker"),
            "has_systemd": Path("/etc/systemd").exists(),
            "has_snap": self._check_command("snap"),
            "has_flatpak": self._check_command("flatpak"),
            "is_root": os.geteuid() == 0,
            "architecture": self._get_architecture(),
            "memory_gb": self._get_memory_gb(),
            "cpu_cores": self._get_cpu_cores()
        }
        return capabilities

    def _check_command(self, command: str) -> bool:
        """Check if a command is available"""
        try:
            subprocess.run([command, "--version"], 
                         capture_output=True, check=True, timeout=5)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
            return False

    def _get_architecture(self) -> str:
        """Get system architecture"""
        try:
            result = subprocess.run(["uname", "-m"], 
                                  capture_output=True, text=True, timeout=5)
            return result.stdout.strip()
        except:
            return "unknown"

    def _get_memory_gb(self) -> int:
        """Get available system memory in GB"""
        try:
            with open("/proc/meminfo", "r") as f:
                for line in f:
                    if line.startswith("MemTotal:"):
                        kb = int(line.split()[1])
                        return kb // 1024 // 1024
        except:
            pass
        return 0

    def _get_cpu_cores(self) -> int:
        """Get number of CPU cores"""
        try:
            return os.cpu_count() or 0
        except:
            return 0

    def show_system_analysis(self, capabilities: Dict[str, bool]):
        """Show system capability analysis"""
        print("\n" + "="*70)
        print("🖥️  SYSTEM ANALYSIS")
        print("="*70)
        
        print(f"💾 Memory: {capabilities['memory_gb']}GB")
        print(f"⚡ CPU Cores: {capabilities['cpu_cores']}")
        print(f"🏗️  Architecture: {capabilities['architecture']}")
        print(f"🖥️  Display: {'Available' if capabilities['has_display'] else 'Not detected'}")
        print(f"🐳 Docker: {'Available' if capabilities['has_docker'] else 'Not available'}")
        print(f"👤 User: {'Root' if capabilities['is_root'] else 'Regular user'}")
        
        # Recommendations based on system
        print("\n🎯 RECOMMENDATIONS:")
        if capabilities['memory_gb'] >= 8 and capabilities['cpu_cores'] >= 4:
            print("   ✅ System suitable for any editor configuration")
        elif capabilities['memory_gb'] >= 4:
            print("   ⚠️  System suitable for native editors (container options may be slow)")
        else:
            print("   ⚠️  Limited resources - native editors recommended")
            
        if not capabilities['has_docker']:
            print("   ℹ️  Docker not available - only native installation possible")

    def filter_available_editors(self, capabilities: Dict[str, bool]) -> Dict[str, dict]:
        """Filter editors based on system capabilities"""
        filtered = {}
        
        for key, editor in self.available_editors.items():
            # Check if container-based editors are possible
            if "container" in key and not capabilities['has_docker']:
                continue
                
            # Check memory requirements
            if capabilities['memory_gb'] < 2 and editor['resource_usage'] == 'high':
                continue
                
            # Check architecture support (mainly for native installations)
            if capabilities['architecture'] not in ['x86_64', 'aarch64', 'arm64'] and "native" in key:
                continue
                
            filtered[key] = editor
            
        return filtered

    def show_editor_selection(self, available_editors: Dict[str, dict]):
        """Show enhanced editor selection dialog"""
        print("\n" + "="*70)
        print("🎨 CHOOSE YOUR DEVELOPMENT EDITOR")
        print("="*70)
        print()
        
        # Group editors by type
        native_editors = {k: v for k, v in available_editors.items() if "native" in k}
        container_editors = {k: v for k, v in available_editors.items() if "container" in k}
        
        if native_editors:
            print("🚀 NATIVE EDITORS (Recommended for best performance):")
            for i, (key, editor) in enumerate(native_editors.items(), 1):
                default_marker = " [RECOMMENDED]" if editor["default"] else ""
                print(f"\n{i}. {editor['name']}{default_marker}")
                print(f"   {editor['description']}")
                print(f"   Performance: {editor['performance'].title()} | Resources: {editor['resource_usage'].title()}")
                
                for feature in editor["features"]:
                    print(f"   {feature}")
        
        if container_editors:
            print(f"\n🐳 CONTAINER EDITORS:")
            start_num = len(native_editors) + 1
            for i, (key, editor) in enumerate(container_editors.items(), start_num):
                print(f"\n{i}. {editor['name']}")
                print(f"   {editor['description']}")
                print(f"   Performance: {editor['performance'].title()} | Resources: {editor['resource_usage'].title()}")
                
                for feature in editor["features"]:
                    print(f"   {feature}")

        return self._get_user_choice(available_editors)

    def _get_user_choice(self, available_editors: Dict[str, dict]) -> Tuple[str, dict]:
        """Get user's editor choice"""
        editors_list = list(available_editors.items())
        
        while True:
            try:
                print("\n" + "="*50)
                choice = input(f"Select editor (1-{len(editors_list)}) [1 for default]: ").strip()
                
                if not choice:  # Default to first option
                    choice = "1"
                    
                choice_num = int(choice)
                if 1 <= choice_num <= len(editors_list):
                    selected_key, selected_editor = editors_list[choice_num - 1]
                    
                    print(f"\n✅ Selected: {selected_editor['name']}")
                    print(f"📋 Installation method: {selected_editor['install_method']}")
                    
                    # Confirm choice
                    confirm = input("\nConfirm this selection? (Y/n): ").strip().lower()
                    if confirm in ['', 'y', 'yes']:
                        return selected_key, selected_editor
                    else:
                        print("Please make another selection.")
                else:
                    print(f"❌ Invalid choice. Please select 1-{len(editors_list)}.")
                    
            except ValueError:
                print("❌ Please enter a number.")
            except KeyboardInterrupt:
                print("\n👋 Editor selection cancelled.")
                sys.exit(0)

    def create_editor_config(self, editor_key: str, editor_info: dict) -> Dict[str, str]:
        """Create comprehensive editor configuration"""
        config = {
            "selected_editor": editor_key,
            "editor_name": editor_info["name"],
            "install_method": editor_info["install_method"],
            "performance": editor_info["performance"],
            "resource_usage": editor_info["resource_usage"],
            "installation_type": "native" if "native" in editor_key else "container",
            "editor_type": "zed" if "zed" in editor_key else "vscode",
        }
        
        # Save configuration
        config_file = self.config_dir / "editor-choice.json"
        with open(config_file, "w") as f:
            json.dump(config, f, indent=2)
            
        print(f"✅ Editor configuration saved: {config_file}")
        return config

    def create_installation_script(self, editor_key: str, editor_info: dict):
        """Create installation script for selected editor"""
        script_path = self.config_dir / "install-selected-editor.sh"
        
        script_content = self._generate_install_script(editor_key, editor_info)
        
        with open(script_path, "w") as f:
            f.write(script_content)
            
        # Make script executable
        os.chmod(script_path, 0o755)
        
        print(f"✅ Installation script created: {script_path}")
        return script_path

    def _generate_install_script(self, editor_key: str, editor_info: dict) -> str:
        """Generate appropriate installation script"""
        script_header = """#!/bin/bash
set -e

# Enhanced Editor Installation Script
# Generated by enhanced editor selection system

echo "🎨 Installing selected editor..."

"""
        
        if editor_key == "zed_native":
            return script_header + self._get_zed_native_script()
        elif editor_key == "vscode_native":
            return script_header + self._get_vscode_native_script()
        elif editor_key == "zed_container":
            return script_header + self._get_zed_container_script()
        elif editor_key == "vscode_container":
            return script_header + self._get_vscode_container_script()
        else:
            return script_header + "echo 'Unknown editor type'"

    def _get_zed_native_script(self) -> str:
        return """
# Zed Native Installation
echo "⚡ Installing Zed Editor (Native)..."

# Check if already installed
if command -v zed &> /dev/null; then
    echo "✅ Zed already installed"
    zed --version
    exit 0
fi

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64) ZED_ARCH="x86_64" ;;
    aarch64|arm64) ZED_ARCH="aarch64" ;;
    *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Get latest release
echo "📥 Downloading latest Zed release..."
RELEASE_URL="https://api.github.com/repos/zed-industries/zed/releases/latest"
DOWNLOAD_URL=$(curl -s "$RELEASE_URL" | grep "browser_download_url.*linux-$ZED_ARCH.tar.gz" | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ Could not find download URL for $ZED_ARCH"
    exit 1
fi

# Download and install
cd /tmp
wget -q "$DOWNLOAD_URL" -O zed.tar.gz
tar -xzf zed.tar.gz

# Install to system
sudo mkdir -p /opt/zed
sudo cp -r zed-linux-$ZED_ARCH/* /opt/zed/
sudo ln -sf /opt/zed/bin/zed /usr/local/bin/zed

# Create desktop entry
sudo tee /usr/share/applications/zed.desktop > /dev/null << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Zed
Comment=A high-performance, multiplayer code editor
Exec=/usr/local/bin/zed %F
Icon=/opt/zed/share/icons/hicolor/512x512/apps/zed.png
Terminal=false
Categories=Development;TextEditor;
StartupWMClass=zed
MimeType=text/plain;text/x-chdr;text/x-csrc;text/x-c++hdr;text/x-c++src;text/x-java;text/x-dsrc;text/x-pascal;text/x-perl;text/x-python;application/x-php;application/xml;text/html;text/css;text/x-sql;text/x-diff;
EOF

# Cleanup
rm -f zed.tar.gz
rm -rf zed-linux-$ZED_ARCH

echo "✅ Zed installed successfully!"
zed --version
"""

    def _get_vscode_native_script(self) -> str:
        return """
# VS Code Native Installation
echo "📝 Installing Visual Studio Code (Native)..."

# Check if already installed
if command -v code &> /dev/null; then
    echo "✅ VS Code already installed"
    code --version
    exit 0
fi

# Add Microsoft repository
echo "📦 Adding Microsoft repository..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'

# Install VS Code
echo "📥 Installing VS Code..."
sudo apt update
sudo apt install -y code

# Install recommended extensions
echo "🔌 Installing recommended extensions..."
EXTENSIONS=(
    "ms-python.python"
    "ms-vscode.vscode-typescript-next"
    "ms-vscode.vscode-json"
    "redhat.vscode-yaml"
    "ms-vscode.docker"
    "rust-lang.rust-analyzer"
    "bradlc.vscode-tailwindcss"
)

for ext in "${EXTENSIONS[@]}"; do
    code --install-extension "$ext" --force
done

echo "✅ VS Code installed successfully with extensions!"
code --version
"""

    def _get_zed_container_script(self) -> str:
        return """
# Zed Container Installation
echo "🐳 Setting up Zed Editor (Container)..."

# Check Docker availability
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not available. Cannot install container version."
    exit 1
fi

# Create Zed container setup
mkdir -p ~/zed-container

# Create Dockerfile for Zed
cat > ~/zed-container/Dockerfile << 'EOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \\
    curl wget git build-essential \\
    libfontconfig1-dev libfreetype6-dev \\
    libx11-dev libxrandr2 libxi6 \\
    libgl1-mesa-glx libasound2-dev \\
    xvfb x11vnc fluxbox \\
    && rm -rf /var/lib/apt/lists/*

# Install Zed
RUN cd /tmp && \\
    ARCH=$(uname -m) && \\
    wget $(curl -s https://api.github.com/repos/zed-industries/zed/releases/latest | grep "browser_download_url.*linux-$ARCH.tar.gz" | cut -d '"' -f 4) -O zed.tar.gz && \\
    tar -xzf zed.tar.gz && \\
    mkdir -p /opt/zed && \\
    cp -r zed-linux-*/* /opt/zed/ && \\
    ln -sf /opt/zed/bin/zed /usr/local/bin/zed && \\
    rm -rf /tmp/*

# Setup X11 forwarding
ENV DISPLAY=:99
EXPOSE 5900

# Startup script
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

CMD ["/startup.sh"]
EOF

# Create startup script
cat > ~/zed-container/startup.sh << 'EOF'
#!/bin/bash
Xvfb :99 -screen 0 1920x1080x24 &
fluxbox &
x11vnc -display :99 -nopw -listen localhost -xkb -forever &
sleep 2
zed
EOF

# Build container
cd ~/zed-container
docker build -t zed-container .

# Create run script
cat > ~/run-zed-container.sh << 'EOF'
#!/bin/bash
docker run -it --rm \\
    -p 5900:5900 \\
    -v "$HOME/Projects:/home/user/Projects" \\
    -v "$HOME/.config/zed:/home/user/.config/zed" \\
    zed-container
EOF

chmod +x ~/run-zed-container.sh

echo "✅ Zed container setup complete!"
echo "🚀 Run with: ~/run-zed-container.sh"
echo "🖥️  Connect via VNC to localhost:5900"
"""

    def _get_vscode_container_script(self) -> str:
        return """
# VS Code Container Installation (code-server)
echo "🐳 Setting up VS Code Server (Container)..."

# Check Docker availability
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not available. Cannot install container version."
    exit 1
fi

# Create code-server container setup
mkdir -p ~/vscode-container

# Create docker-compose.yml for code-server
cat > ~/vscode-container/docker-compose.yml << 'EOF'
version: '3.8'
services:
  code-server:
    image: codercom/code-server:latest
    container_name: vscode-server
    ports:
      - "8080:8080"
    volumes:
      - "$HOME/Projects:/home/coder/Projects"
      - "$HOME/.config/code-server:/home/coder/.config/code-server"
      - vscode-extensions:/home/coder/.local/share/code-server
    environment:
      - PASSWORD=development
    restart: unless-stopped

volumes:
  vscode-extensions:
EOF

# Create configuration
mkdir -p ~/.config/code-server
cat > ~/.config/code-server/config.yaml << 'EOF'
bind-addr: 0.0.0.0:8080
auth: password
password: development
cert: false
EOF

# Start code-server
cd ~/vscode-container
docker-compose up -d

echo "✅ VS Code Server setup complete!"
echo "🌐 Access at: http://localhost:8080"
echo "🔑 Password: development"
"""

    def show_completion_message(self, editor_key: str, editor_info: dict, script_path: Path):
        """Show completion message with next steps"""
        print("\n" + "="*70)
        print("🎉 EDITOR SELECTION COMPLETE!")
        print("="*70)
        
        print(f"\n✅ Selected Editor: {editor_info['name']}")
        print(f"📁 Configuration saved in: {self.config_dir}")
        print(f"🚀 Installation script: {script_path}")
        
        print(f"\n📋 NEXT STEPS:")
        if "native" in editor_key:
            print(f"   1. Run installation: sudo bash {script_path}")
            if "zed" in editor_key:
                print(f"   2. Launch editor: zed")
                print(f"   3. Open projects: zed ~/Projects/")
            else:
                print(f"   2. Launch editor: code")
                print(f"   3. Open projects: code ~/Projects/")
        else:
            print(f"   1. Run installation: bash {script_path}")
            print(f"   2. Access via container interface")
            if "zed" in editor_key:
                print(f"   3. VNC to localhost:5900")
            else:
                print(f"   3. Web interface at localhost:8080")
        
        print(f"\n💡 Integration with n8n-installer:")
        print(f"   • Editor config will be used during workspace setup")
        print(f"   • Projects directory: ~/Projects/")
        print(f"   • Development tools will be pre-configured")
        
        print("="*70)


def main():
    """Main function for enhanced editor selection"""
    print("🎨 Enhanced Editor Selection for Unified Workspace")
    print("=" * 60)
    
    try:
        setup = EnhancedEditorSetup()
        
        # Analyze system capabilities
        capabilities = setup.detect_system_capabilities()
        setup.show_system_analysis(capabilities)
        
        # Filter available editors based on system
        available_editors = setup.filter_available_editors(capabilities)
        
        if not available_editors:
            print("\n❌ No suitable editors found for this system.")
            print("Please check system requirements and try again.")
            sys.exit(1)
        
        # Show selection and get user choice
        selected_key, selected_editor = setup.show_editor_selection(available_editors)
        
        # Create configuration
        config = setup.create_editor_config(selected_key, selected_editor)
        
        # Create installation script
        script_path = setup.create_installation_script(selected_key, selected_editor)
        
        # Show completion message
        setup.show_completion_message(selected_key, selected_editor, script_path)
        
        return selected_key
        
    except KeyboardInterrupt:
        print("\n\n👋 Editor selection cancelled by user.")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Error during editor selection: {e}")
        sys.exit(1)


if __name__ == "__main__":
    selected_editor = main()
    print(f"\n✨ Ready to proceed with {selected_editor.replace('_', ' ').title()}!")
