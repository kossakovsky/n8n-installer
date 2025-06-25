# 🚨 QUICK FIX GUIDE - AppFlowy Installation Issues

## Sofortige Lösung für den GoTrue Fehler

Der Fehler `appflowy-gotrue is unhealthy` kann mit diesen Schritten behoben werden:

### 🔧 Schritt 1: Ersetze die docker-compose.yml

```bash
# Stoppe alle Services
sudo docker compose -p localai down

# Ersetze docker-compose.yml mit der korrigierten Version
# (Die neue Version aus meiner Antwort verwenden)
```

### 🔧 Schritt 2: Führe das Debug-Skript aus

Erstelle zuerst das Debug-Skript:

```bash
# Erstelle das Debug-Skript
sudo nano scripts/debug_appflowy.sh

# Mache es ausführbar
sudo chmod +x scripts/debug_appflowy.sh

# Führe es aus
sudo bash scripts/debug_appflowy.sh
```

### 🔧 Schritt 3: Starte die Services neu

```bash
# Starte mit der neuen Konfiguration
sudo bash scripts/05_run_services.sh
```

## 📋 Hauptänderungen in der neuen docker-compose.yml:

### ✅ AppFlowy Fixes:
- **GoTrue Image**: `supabase/gotrue:v2.132.3` statt `appflowyinc/gotrue:latest`
- **Spezifische Versionen**: AppFlowy Cloud/Web auf Version `0.5.9`
- **Längere Health Check Timeouts**: `start_period: 60s` für bessere Stabilität
- **Verbesserte Environment Variables**: Vollständige GoTrue Konfiguration
- **Database URL Format**: Korrigiert für PostgreSQL Verbindungen

### ✅ Affine Verbesserungen:
- **Längere Startup Zeit**: `start_period: 120s` für Affine
- **Migration Command**: Verbessert mit Echo-Statement
- **OpenAI Integration**: Optional für Copilot Features

## 🔍 Häufige Probleme & Lösungen:

### Problem 1: GoTrue Health Check schlägt fehl
```bash
# Lösung: Überprüfe die Logs
docker logs appflowy-gotrue

# Neustart des GoTrue Services
docker compose -p localai restart appflowy-gotrue
```

### Problem 2: Database Connection Errors
```bash
# Überprüfe PostgreSQL
docker logs appflowy-postgres

# Teste die Verbindung
docker exec appflowy-gotrue sh -c "nc -z appflowy-postgres 5432"
```

### Problem 3: JWT Secret Fehler
```bash
# Überprüfe .env Datei
grep APPFLOWY_JWT_SECRET .env

# Falls leer, regeneriere secrets
sudo bash scripts/03_generate_secrets.sh
```

## 🚀 Vollständiger Reset (falls nötig):

Wenn alle anderen Methoden fehlschlagen:

```bash
# 1. Stoppe alle Services
sudo docker compose -p localai down

# 2. Entferne AppFlowy Volumes (ACHTUNG: Datenverlust!)
sudo docker volume rm $(docker volume ls -q | grep appflowy)

# 3. Neue docker-compose.yml verwenden

# 4. Services neu starten
sudo bash scripts/05_run_services.sh
```

## 📊 Status überprüfen:

```bash
# Service Status
docker compose -p localai ps

# Health Status aller Services
docker ps --format "table {{.Names}}\t{{.Status}}"

# Spezifische Logs anzeigen
docker logs appflowy-gotrue --tail 50
docker logs appflowy-cloud --tail 50
```

## 🎯 Erfolgreiche Installation erkennen:

Du weißt, dass es funktioniert, wenn:

1. ✅ Alle AppFlowy Container sind "healthy"
2. ✅ `https://appflowy.yourdomain.com` ist erreichbar  
3. ✅ Keine Fehler in den Logs
4. ✅ Debug-Skript zeigt grüne Checkmarks

## 📞 Weitere Hilfe:

Falls die Probleme weiterhin bestehen:

1. **Führe das Debug-Skript aus**: `sudo bash scripts/debug_appflowy.sh`
2. **Teile die Ausgabe** für weitere Analyse
3. **Überprüfe die System-Ressourcen**: Mindestens 8GB RAM für alle Services
4. **DNS-Konfiguration**: Stelle sicher, dass `*.yourdomain.com` auf deinen Server zeigt

---

💡 **Tipp**: Die neue docker-compose.yml Version ist deutlich stabiler und sollte die meisten GoTrue-Probleme beheben. Das Debug-Skript hilft bei der Diagnose verbleibender Probleme.
