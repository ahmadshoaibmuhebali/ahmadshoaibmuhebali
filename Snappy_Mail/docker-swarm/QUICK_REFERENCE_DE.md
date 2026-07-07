# Docker Swarm - Quick Setup Script und Referenz

**Version:** 1.0  
**Datum:** Juni 2026  
**Zweck:** Schnelle Referenz und automatisierte Setup-Scripts

---

## 1. Quick Reference - Schritt für Schritt

### 1.1 Manager-Setup (5-10 Minuten)

```bash
# 1. SSH zum Manager
ssh -i your-key.pem ubuntu@<manager_public_ip>

# 2. Docker überprüfen
docker --version
docker info

# 3. Swarm initialisieren (PRIVATE IP nutzen!)
docker swarm init --advertise-addr <manager_private_ip>

# 4. Worker-Token speichern
docker swarm join-token worker > /tmp/worker-join.txt
cat /tmp/worker-join.txt
```

### 1.2 Worker 1 Setup (2-3 Minuten)

```bash
# 1. SSH zu Worker 1
ssh -i your-key.pem ubuntu@<worker1_public_ip>

# 2. Join-Command ausführen
docker swarm join --token SWMTKN-1-xxx... <manager_private_ip>:2377

# 3. Überprüfen
docker node ls  # Sollte Fehler geben (nicht Manager)
# Das ist normal - Worker können nicht ls ausführen
```

### 1.3 Worker 2 Setup (2-3 Minuten)

```bash
# Gleich wie Worker 1
ssh -i your-key.pem ubuntu@<worker2_public_ip>
docker swarm join --token SWMTKN-1-xxx... <manager_private_ip>:2377
```

### 1.4 Verifikation (auf Manager)

```bash
# Back to Manager
ssh -i your-key.pem ubuntu@<manager_public_ip>

# Status überprüfen
docker node ls          # Sollte 3 Nodes zeigen
docker network create -d overlay traefik-public
docker network create -d overlay mailnet
docker network ls       # Sollte neue Networks zeigen
```

---

## 2. Automatisierte Setup-Scripts

### 2.1 Manager Setup Script

**Datei:** `setup-manager.sh`

```bash
#!/bin/bash
set -e

echo "=== Docker Swarm Manager Setup ==="
echo ""

# 1. Input Validation
if [ -z "$1" ]; then
    echo "Nutzung: $0 <manager_private_ip>"
    echo "Beispiel: $0 10.0.1.10"
    exit 1
fi

MANAGER_IP=$1

# 2. Docker Status überprüfen
echo "[1/5] Docker überprüfen..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker nicht installiert!"
    exit 1
fi

docker_version=$(docker --version)
echo "✅ Docker gefunden: $docker_version"
echo ""

# 3. Swarm initialisieren
echo "[2/5] Docker Swarm initialisieren..."
docker swarm init --advertise-addr $MANAGER_IP

echo ""
echo "[3/5] Networks erstellen..."
docker network create -d overlay --attachable traefik-public || echo "⚠️  Network existiert bereits"
docker network create -d overlay --attachable mailnet || echo "⚠️  Network existiert bereits"

echo ""
echo "[4/5] Join-Tokens speichern..."
mkdir -p /tmp/swarm-tokens
docker swarm join-token worker > /tmp/swarm-tokens/worker-join-token.txt
docker swarm join-token manager > /tmp/swarm-tokens/manager-join-token.txt
echo "✅ Tokens gespeichert in /tmp/swarm-tokens/"

echo ""
echo "[5/5] Status überprüfen..."
docker node ls
docker network ls | grep "traefik-public\|mailnet"

echo ""
echo "=== ✅ Manager Setup abgeschlossen ==="
echo ""
echo "Worker-Join-Command:"
cat /tmp/swarm-tokens/worker-join-token.txt
```

**Nutzung:**
```bash
chmod +x setup-manager.sh
./setup-manager.sh 10.0.1.10
```

### 2.2 Worker Setup Script

**Datei:** `setup-worker.sh`

```bash
#!/bin/bash
set -e

echo "=== Docker Swarm Worker Setup ==="
echo ""

# 1. Input Validation
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Nutzung: $0 <token> <manager_ip>:<port>"
    echo "Beispiel: $0 'SWMTKN-1-xxx...' 10.0.1.10:2377"
    exit 1
fi

TOKEN=$1
MANAGER_ADDR=$2

# 2. Docker Status überprüfen
echo "[1/3] Docker überprüfen..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker nicht installiert!"
    exit 1
fi

docker_version=$(docker --version)
echo "✅ Docker gefunden: $docker_version"
echo ""

# 3. Zum Swarm hinzufügen
echo "[2/3] Worker zum Swarm hinzufügen..."
docker swarm join --token $TOKEN $MANAGER_ADDR

echo ""
echo "[3/3] Verbindung überprüfen..."
sleep 2
docker node ls || echo "⚠️  Hinweis: Worker können 'node ls' nicht ausführen (normal)"

echo ""
echo "=== ✅ Worker Setup abgeschlossen ==="
echo ""
echo "Auf Manager überprüfen mit: docker node ls"
```

**Nutzung auf Worker-Knoten:**
```bash
chmod +x setup-worker.sh
./setup-worker.sh 'SWMTKN-1-xxx...' 10.0.1.10:2377
```

### 2.3 Stack Deployment Script

**Datei:** `deploy-stacks.sh`

```bash
#!/bin/bash
set -e

echo "=== Docker Swarm Stack Deployment ==="
echo ""

# 1. Konfiguration prüfen
if [ ! -f "docker-compose.stack.yml" ]; then
    echo "❌ Fehler: docker-compose.stack.yml nicht gefunden!"
    exit 1
fi

if [ ! -f "traefik.yml" ]; then
    echo "❌ Fehler: traefik.yml nicht gefunden!"
    exit 1
fi

if [ ! -f ".env" ]; then
    echo "❌ Fehler: .env nicht gefunden!"
    exit 1
fi

echo "✅ Alle Dateien gefunden"
echo ""

# 2. Directories erstellen
echo "[1/4] Erstelle Directories..."
sudo mkdir -p /opt/mailserver/{config,certs,snappymail-data}
sudo mkdir -p /var/dms/custom-certs
sudo mkdir -p /opt/traefik
sudo touch /opt/traefik/acme.json
sudo chmod 600 /opt/traefik/acme.json
echo "✅ Directories erstellt"
echo ""

# 3. Traefik deployen
echo "[2/4] Deploye Traefik Stack..."
docker stack deploy -c traefik.yml traefik
echo "✅ Traefik deployed"
echo ""

# 4. Mailserver deployen
echo "[3/4] Deploye Mailserver Stack..."
docker stack deploy -c docker-compose.stack.yml mailserver
echo "✅ Mailserver deployed"
echo ""

# 5. Warten und Status
echo "[4/4] Warte auf Container-Start..."
sleep 30

echo ""
echo "=== Stack Status ==="
docker stack ls
echo ""
docker service ls
echo ""

echo "=== ✅ Deployment abgeschlossen ==="
echo ""
echo "Services werden überprüft..."
docker service ls --filter "label=com.docker.compose.project=traefik"
docker service ls --filter "label=com.docker.compose.project=mailserver"

echo ""
echo "Logs anzeigen mit:"
echo "  docker service logs traefik_traefik"
echo "  docker service logs mailserver_mailserver"
```

**Nutzung auf Manager:**
```bash
cd /opt/mailserver
chmod +x deploy-stacks.sh
./deploy-stacks.sh
```

---

## 3. Cluster Info Script

**Datei:** `swarm-status.sh`

```bash
#!/bin/bash

echo "=== 🐳 Docker Swarm Cluster Status ==="
echo ""

echo "📊 NODES:"
docker node ls
echo ""

echo "🔗 NETWORKS:"
docker network ls | grep -E "traefik-public|mailnet|overlay"
echo ""

echo "⚙️  SERVICES:"
docker service ls
echo ""

echo "📦 SERVICE DETAILS:"
for service in $(docker service ls --quiet); do
    service_name=$(docker service inspect $service --format '{{.Spec.Name}}')
    echo "  ➜ $service_name"
    docker service ps $service --no-trunc | head -2
done
echo ""

echo "💾 VOLUMES:"
docker volume ls
echo ""

echo "📈 RESOURCE USAGE:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
echo ""

echo "❌ FEHLERHAFTE SERVICES:"
docker service ls --filter "mode=replicated" | grep -v "1/1" || echo "✅ Alle Services läufen"
echo ""

echo "=== Ende Status Report ==="
```

**Nutzung:**
```bash
chmod +x swarm-status.sh
./swarm-status.sh
```

---

## 4. Monitoring und Health Check Script

**Datei:** `health-check.sh`

```bash
#!/bin/bash

echo "=== 🏥 Docker Swarm Health Check ==="
echo ""

ERRORS=0
WARNINGS=0

# 1. Nodes überprüfen
echo "1️⃣  Nodes überprüfen..."
node_count=$(docker node ls --filter "status=ready" --quiet | wc -l)
echo "   Ready Nodes: $node_count/3"
if [ "$node_count" -lt 3 ]; then
    echo "   ⚠️  WARNING: Nicht alle Nodes ready!"
    WARNINGS=$((WARNINGS + 1))
    docker node ls
else
    echo "   ✅ Alle Nodes ready"
fi
echo ""

# 2. Services überprüfen
echo "2️⃣  Services überprüfen..."
docker service ls | tail -n +2 | while read line; do
    service_name=$(echo $line | awk '{print $2}')
    replicas=$(echo $line | awk '{print $3}')
    echo "   $service_name: $replicas"
    
    if [[ ! "$replicas" =~ ^[0-9]+/[0-9]+$ ]]; then
        echo "   ❌ ERROR: Service $service_name hat keine korrekten Replicas!"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# 3. Networks überprüfen
echo "3️⃣  Networks überprüfen..."
traefik_net=$(docker network ls --filter "name=traefik-public" --quiet)
mailnet=$(docker network ls --filter "name=mailnet" --quiet)

if [ -z "$traefik_net" ]; then
    echo "   ❌ ERROR: traefik-public Network fehlt!"
    ERRORS=$((ERRORS + 1))
else
    echo "   ✅ traefik-public Network OK"
fi

if [ -z "$mailnet" ]; then
    echo "   ❌ ERROR: mailnet Network fehlt!"
    ERRORS=$((ERRORS + 1))
else
    echo "   ✅ mailnet Network OK"
fi
echo ""

# 4. Disk Space überprüfen
echo "4️⃣  Speicherplatz überprüfen..."
disk_usage=$(df /var/lib/docker | tail -1 | awk '{print $5}' | sed 's/%//')
echo "   Docker Storage: ${disk_usage}%"
if [ "$disk_usage" -gt 80 ]; then
    echo "   ⚠️  WARNING: Speicher zu ${disk_usage}% voll!"
    WARNINGS=$((WARNINGS + 1))
else
    echo "   ✅ Speicherplatz OK"
fi
echo ""

# 5. Manager Quorum überprüfen
echo "5️⃣  Manager Quorum überprüfen..."
manager_count=$(docker node ls --filter "role=manager" --quiet | wc -l)
echo "   Manager Nodes: $manager_count"
if [ "$manager_count" -lt 1 ]; then
    echo "   ❌ ERROR: Kein Manager verfügbar!"
    ERRORS=$((ERRORS + 1))
else
    echo "   ✅ Manager verfügbar"
fi
echo ""

# Summary
echo "=== ZUSAMMENFASSUNG ==="
echo "Fehler: $ERRORS"
echo "Warnungen: $WARNINGS"

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo "✅ Cluster ist gesund!"
    exit 0
elif [ "$ERRORS" -eq 0 ]; then
    echo "⚠️  Cluster läuft, aber Warnungen vorhanden"
    exit 0
else
    echo "❌ Cluster hat Fehler!"
    exit 1
fi
```

**Nutzung:**
```bash
chmod +x health-check.sh
./health-check.sh
```

---

## 5. Backup und Restore Scripts

### 5.1 Backup Script

**Datei:** `swarm-backup.sh`

```bash
#!/bin/bash
set -e

BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/swarm-backup-$DATE.tar.gz"

echo "=== Docker Swarm Backup ==="
echo "Backup-Datei: $BACKUP_FILE"
echo ""

# 1. Backup Directory erstellen
mkdir -p $BACKUP_DIR

# 2. Swarm Tokens exportieren
echo "[1/4] Exportiere Swarm Tokens..."
mkdir -p /tmp/swarm-backup-$DATE/tokens
docker swarm join-token worker > /tmp/swarm-backup-$DATE/tokens/worker-token.txt
docker swarm join-token manager > /tmp/swarm-backup-$DATE/tokens/manager-token.txt

# 3. Service Konfigurationen exportieren
echo "[2/4] Exportiere Service Konfigurationen..."
mkdir -p /tmp/swarm-backup-$DATE/services
docker service ls --quiet | while read service_id; do
    service_name=$(docker service inspect $service_id --format '{{.Spec.Name}}')
    docker service inspect $service_id > /tmp/swarm-backup-$DATE/services/$service_name.json
done

# 4. Wichtige Volumes sichern
echo "[3/4] Sichere Volumes..."
sudo tar czf /tmp/swarm-backup-$DATE/volumes.tar.gz \
    /opt/traefik/acme.json \
    /opt/mailserver/snappymail-data \
    2>/dev/null || echo "⚠️  Einige Volumes nicht vorhanden"

# 5. Alles in eine Datei packen
echo "[4/4] Erstelle Backup-Datei..."
tar czf $BACKUP_FILE -C /tmp swarm-backup-$DATE
rm -rf /tmp/swarm-backup-$DATE

echo ""
echo "✅ Backup erstellt: $BACKUP_FILE"
echo "Größe: $(du -h $BACKUP_FILE | cut -f1)"

# Alte Backups löschen (älter als 30 Tage)
find $BACKUP_DIR -name "swarm-backup-*.tar.gz" -mtime +30 -delete
echo "✅ Alte Backups gelöscht (älter als 30 Tage)"
```

**Nutzung:**
```bash
chmod +x swarm-backup.sh
./swarm-backup.sh
```

### 5.2 Restore Script

**Datei:** `swarm-restore.sh`

```bash
#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Nutzung: $0 <backup_file>"
    echo "Beispiel: $0 /opt/backups/swarm-backup-20260611_120000.tar.gz"
    exit 1
fi

BACKUP_FILE=$1

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Backup-Datei nicht gefunden: $BACKUP_FILE"
    exit 1
fi

echo "=== Docker Swarm Restore ==="
echo "Backup-Datei: $BACKUP_FILE"
echo ""

# 1. Backup auspacken
echo "[1/3] Entpacke Backup..."
TEMP_DIR=$(mktemp -d)
tar xzf $BACKUP_FILE -C $TEMP_DIR
RESTORE_DIR=$(ls $TEMP_DIR)

# 2. Volumes wiederherstellen
echo "[2/3] Stelle Volumes wieder her..."
if [ -f "$TEMP_DIR/$RESTORE_DIR/volumes.tar.gz" ]; then
    sudo tar xzf $TEMP_DIR/$RESTORE_DIR/volumes.tar.gz -C /
    echo "✅ Volumes wiederhergestellt"
else
    echo "⚠️  Keine Volumes in Backup"
fi

# 3. Tokens anzeigen
echo "[3/3] Zeige Restore-Informationen..."
echo ""
echo "Join-Tokens:"
cat $TEMP_DIR/$RESTORE_DIR/tokens/worker-token.txt
echo ""
echo "Services können manuell wiederhergestellt werden mit:"
ls $TEMP_DIR/$RESTORE_DIR/services/

# Cleanup
rm -rf $TEMP_DIR

echo ""
echo "✅ Restore abgeschlossen"
echo "⚠️  Bitte überprüfen Sie die Systemkonfiguration!"
```

---

## 6. Troubleshooting Command Reference

```bash
# ==== DIAGNOSTIK ====

# Cluster-Überblick
docker info
docker node ls
docker service ls

# Service Logs
docker service logs mailserver_mailserver -n 100
docker service logs traefik_traefik -n 50

# Container auf diesem Knoten
docker ps -a
docker logs <container_id>

# Netzwerk-Test
docker network inspect traefik-public
docker network connect traefik-public <container_id>

# Speicher überprüfen
df -h /var/lib/docker
du -sh /var/lib/docker/*

# ==== REPARATUR ====

# Service neu starten
docker service update --force <service_name>

# Service neu bauen
docker service update --image <new_image> <service_name>

# Swarm Status reparieren
docker swarm unlock-key
docker swarm update --autolock=false

# Node aus Swarm entfernen
docker node rm <node_id>

# Node cleanup nach Problem
sudo systemctl restart docker
docker swarm join --token SWMTKN-... <manager>:2377

# ==== PERFORMANCE ====

# Live Monitoring
docker stats

# Event-Stream
docker events --filter type=service

# Detaillierte Service-Info
docker service inspect <service_name> --pretty

# Task-History
docker service ps --no-trunc <service_name>
```

---

## 7. Häufige Befehle Cheat Sheet

```bash
# MANAGER COMMANDS
docker swarm init --advertise-addr <ip>
docker swarm join-token worker
docker node ls
docker node rm <id>
docker service ls
docker service ps <service>
docker service logs <service>
docker service scale <service>=<count>
docker service update <service>
docker stack deploy -c file.yml <name>
docker stack ls
docker stack rm <name>

# WORKER COMMANDS  
docker swarm join --token <token> <manager_ip>:2377
docker swarm leave
docker ps
docker logs <container>

# NETWORK COMMANDS
docker network create -d overlay <name>
docker network inspect <name>
docker network ls

# DEBUGGING
docker service inspect <service> --pretty
docker node inspect <id> --pretty
docker events --filter type=service
docker stats
```

---

**Letzter Update:** Juni 2026
