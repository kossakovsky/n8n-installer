#!/bin/bash

# Prüfen, ob das Skript als root ausgeführt wird
if [ "$(id -u)" -ne 0 ]; then
    echo "Bitte das Skript als root oder mit sudo ausführen!"
    exit 1
fi

# Paketquellen aktualisieren und notwendige Pakete installieren
apt update
apt install -y ca-certificates curl gnupg

# Docker-Repository hinzufügen
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Paketquellen aktualisieren
apt update

# Docker Engine und Compose Plugin installieren
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Überprüfen der Installation
echo ""
echo "Docker- und Docker Compose-Installation abgeschlossen."
echo "Überprüfe die Versionen:"
docker --version
docker compose version
