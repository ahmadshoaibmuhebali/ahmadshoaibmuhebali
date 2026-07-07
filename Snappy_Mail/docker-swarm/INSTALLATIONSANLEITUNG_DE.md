# Docker Swarm - Installationsanleitung und Konfiguration 
**Version:** 1.0  
**Datum:** Juni 2026  
**Ziel:** Docker Swarm Cluster mit Manager und Worker-Knoten aufbauen

---

## 1. Übersicht

Diese Anleitung beschreibt die Installation und Konfiguration eines **Docker Swarm Clusters** für den SnappyMail E-Mail-Server.

**Cluster-Struktur:**
- **1x Manager-Knoten** - Orchestriert alle Services
- **2x Worker-Knoten** - Führen Container aus

**Vorbedingung:** Terraform hat bereits 3x EC2 Instanzen mit Docker erstellt

---

## 2. Voraussetzungen und Vorbereitung

### 2.1 Erforderliche Komponenten

**Für jeden Knoten (Manager + Worker):**
- ✅ Ubuntu 24.04 LTS
- ✅ Docker Engine installiert
- ✅ Docker Compose Plugin installiert
- ✅ Netzwerk-Konnektivität zwischen Knoten
- ✅ Ports offen (siehe Abschnitt 2.3)

### 2.2 Knoten-Identifikation

Notieren Sie die IP-Adressen aus dem Terraform Output:

```bash
# Terraform Outputs abrufen
cd terraform/
terraform output
```

**Beispiel-Output:**
```
manager_public_ip = "100.57.61.138"
worker_public_ips = ["52.234.56.78", "34.345.67.89"]
ec2_private_ips = ["172.31.2.190", "172.31.28.236", "172.31.36.202"]
```

**Dokumentieren Sie:**
| Knoten-Name | Rolle | Public IP | Private IP | SSH-Key |
|------------|-------|-----------|-----------|---------|
| swarm-node-0 | Manager | 100.57.61.138| 172.31.2.190 | aws-key.pem |
| swarm-node-1 | Worker | 52.234.56.78 | 172.31.28.236 | aws-key.pem |
| swarm-node-2 | Worker | 34.345.67.89 | 172.31.36.202| aws-key.pem |

### 2.3 Erforderliche Ports

**Manager-Knoten:**
| Port | Protokoll | Zweck | Richtung |
|------|-----------|-------|---------|
| 2377 | TCP | Swarm Manager Communication | Eingehend (Worker) |
| 7946 | TCP/UDP | Gossip Protocol (Node Discovery) | Bidirektional |
| 4789 | UDP | Overlay Network (VXLAN) | Bidirektional |
| 22 | TCP | SSH | Eingehend |

**Worker-Knoten:**
| Port | Protokoll | Zweck | Richtung |
|------|-----------|-------|---------|
| 7946 | TCP/UDP | Gossip Protocol | Bidirektional |
| 4789 | UDP | Overlay Network | Bidirektional |
| 22 | TCP | SSH | Eingehend |

**Bereits offen (Security Group):**
- ✅ Ports 25, 465, 587, 143, 993 (E-Mail)
- ✅ Ports 80, 443 (Web/HTTPS)
- ✅ Port 22 (SSH)
- ✅ "All internal traffic between Swarm nodes" (self)

⚠️ **Swarm-Ports (7946, 4789) sind durch "Allow all internal traffic" (self) bereits abgedeckt**

---

## 3. Docker Installation Überprüfung

### 3.1 SSH-Zugriff zu Manager-Knoten

```bash
# SSH-Schlüssel Permissions setzen
chmod 600 aws-key


# mit Public IP (von öffentlichem Internet)
**Beispiel:**
```bash
ssh -i ~/.ssh/aws-key ubuntu@100.57.61.138
```

### 3.2 Docker-Status überprüfen

Nach dem SSH-Login:

```bash
# Docker Version überprüfen
docker --version
# Erwartete Ausgabe: Docker version 27.x.x oder höher

# Docker Daemon läuft?
docker info
# Sollte Server Information anzeigen

# User-Zugehörigkeit überprüfen
groups ubuntu
# Sollte 'docker' enthalten
```

### 3.3 Wenn Docker nicht läuft

```bash
# Docker Service starten
sudo systemctl start docker

# Docker Service aktivieren (startet bei Reboot)
sudo systemctl enable docker

# Docker Service überprüfen
sudo systemctl status docker
```

---

## 4. Docker Swarm Initialisierung (Manager-Knoten)

### 4.1 Swarm initialisieren

**Auf dem Manager-Knoten:**

```bash
# Swarm mit privater IP initialisieren (WICHTIG!)
docker swarm init --advertise-addr 172.31.2.190
```

**Erwartete Ausgabe:**
```
Swarm initialized: current node (abc123def456) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-abc123...def456 172.31.2.190:2377

To add a manager to this swarm, run the following command:

    docker swarm join-token manager

Run 'docker node ls' on a manager to see all nodes.
```

### 4.2 Swarm Status überprüfen

```bash
# Nodes anzeigen (aktuell nur Manager)
docker node ls

# Ausgabe sollte sein:
# ID            HOSTNAME       STATUS    AVAILABILITY   MANAGER STATUS
# abc123def456  swarm-node-0   Ready     Active         Leader
```

### 4.3 Join-Tokens speichern

Die Tokens sind notwendig zum Hinzufügen von Worker-Knoten. Speichern Sie diese:

```bash
# Worker-Join-Token anzeigen und kopieren
docker swarm join-token worker
# Ausgabe: SWMTKN-1-abc123...def456 172.31.2.190:2377

# Manager-Join-Token anzeigen (für zusätzliche Manager)
docker swarm join-token manager
# Ausgabe: SWMTKN-1-xyz789...abc123 172.31.2.190:2377

# In Datei speichern (optional)
docker swarm join-token worker > /tmp/worker-token.txt
cat /tmp/worker-token.txt
```

**Speichern Sie die Tokens sicher:**
```
WORKER_TOKEN=SWMTKN-1-abc123...def456
MANAGER_IP=172.31.2.190
MANAGER_PORT=2377
```

---

## 5. Worker-Knoten verbinden

### 5.1 SSH zu Worker-Knoten 1

```bash
ssh -i your-key.pem ubuntu@<worker1_public_ip>

# Beispiel:
ssh -i ~/.ssh/aws-key.pem ubuntu@52.234.56.78
```

### 5.2 Worker zum Swarm hinzufügen

```bash
# Worker-Join-Command ausführen
docker swarm join --token SWMTKN-1-abc123...def456 172.31.2.190:2377
```

**Erwartete Ausgabe:**
```
This node joined a swarm as a worker.
```

### 5.3 SSH zu Worker-Knoten 2

```bash
exit  # Aus Worker 1 ausloggen

ssh -i your-key.pem ubuntu@<worker2_public_ip>

# Beispiel:
ssh -i ~/.ssh/aws-key.pem ubuntu@34.345.67.89
```

### 5.4 Worker 2 zum Swarm hinzufügen

```bash
# Gleicher Join-Command wie Worker 1
docker swarm join --token SWMTKN-1-abc123...def456 172.31.2.190:2377
```

**Erwartete Ausgabe:**
```
This node joined a swarm as a worker.
```

---

## 6. Swarm Cluster Überprüfung

### 6.1 Zurück zum Manager

```bash
exit  # Aus Worker ausloggen

ssh -i aws ubuntu@100.57.61.138
```

### 6.2 Nodes überprüfen

```bash
docker node ls

# Erwartete Ausgabe (alle 3 Nodes):
# ID            HOSTNAME       STATUS    AVAILABILITY   MANAGER STATUS
# abc123def456  swarm-node-0   Ready     Active         Leader
# def456ghi789  swarm-node-1   Ready     Active
# ghi789jkl012  swarm-node-2   Ready     Active
```

**Erklärung:**
- **ID**: Eindeutige Node-ID
- **HOSTNAME**: Container-Hostname
- **STATUS**: Ready = Online, Down = Offline
- **AVAILABILITY**: Active = Kann Container hosten
- **MANAGER STATUS**: Leader = Primärer Manager

### 6.3 Detaillierte Node-Informationen

```bash
# Spezifische Node Information
docker node inspect <node-id>

# Beispiel:
docker node inspect abc123def456

# Human-readable Format
docker node inspect --pretty abc123def456
```

### 6.4 Cluster-Informationen

```bash
# Swarm-Status anzeigen
docker info | grep -A 10 "Swarm:"

# Ausgabe sollte ähnlich sein:
# Swarm: active
#  NodeID: abc123def456...
#  Is Manager: true
#  ClusterID: cluster123abc...
#  Nodes: 3
#  Managers: 1
#  Services: 0
#  Tasks: 0
```

---

## 7. Netzwerk-Konfiguration

### 7.1 Overlay Network erstellen

```bash
# Traefik-Public Network erstellen (für externe Services)
docker network create -d overlay --attachable traefik-public

# Mail-Network erstellen (für interne Services)
docker network create -d overlay --attachable mailnet
```

**Erklärung:**
- `-d overlay`: Overlay Network Driver (für Multi-Node)
- `--attachable`: Auch standalone Container können verbinden

### 7.2 Networks überprüfen

```bash
docker network ls

# Ausgabe:
# NETWORK ID        NAME              DRIVER    SCOPE
# abc123...         bridge            bridge    local
# def456...         host              host      local
# ghi789...         none              null      local
# jkl012...         traefik-public    overlay   swarm
# mno345...         mailnet           overlay   swarm
```

### 7.3 Network Details

```bash
docker network inspect traefik-public

# Zeigt verbundene Container und Subnet-Informationen
```

---

## 8. Stack Deployment

### 8.1 Dateien vorbereiten

```bash
# SSH zu Manager
ssh -i your-key.pem ubuntu@<manager_public_ip>

# Arbeitsverzeichnis erstellen
mkdir -p /opt/mailserver/{config,certs}
cd /opt/mailserver

# Dateien hierher kopieren (von lokalem Rechner):
# docker-compose.stack.yml
# traefik.yml
# .env (mit Secrets!)
```

### 8.2 Dateien kopieren (von lokalem Rechner)

```bash
# Lokaler Terminal (NICHT SSH)

scp -i your-key.pem docker-compose.stack.yml ubuntu@<manager_ip>:/opt/mailserver/
scp -i your-key.pem traefik.yml ubuntu@<manager_ip>:/opt/mailserver/
scp -i your-key.pem .env ubuntu@<manager_ip>:/opt/mailserver/

# Certs vorbereiten
mkdir -p certs/
# Copy your cert.pem und key.pem hier
scp -i your-key.pem -r certs/ ubuntu@<manager_ip>:/opt/mailserver/
```

### 8.3 Directories für Daten erstellen

```bash
# Auf Manager-Knoten

# SnappyMail persistent data
sudo mkdir -p /opt/mailserver/snappymail-data
sudo chmod 755 /opt/mailserver/snappymail-data

# Traefik ACME certificates
sudo mkdir -p /opt/traefik
sudo touch /opt/traefik/acme.json
sudo chmod 600 /opt/traefik/acme.json

# DMS certificates
sudo mkdir -p /var/dms/custom-certs
sudo chmod 755 /var/dms/custom-certs
```

### 8.4 Stacks deployen

```bash
# Zu Deployment-Directory navigieren
cd /opt/mailserver

# Traefik Stack zuerst
docker stack deploy -c traefik.yml traefik

# Mail Server Stack
docker stack deploy -c docker-compose.stack.yml mailserver

# Warten Sie 30 Sekunden für Container-Start
sleep 30

# Status überprüfen
docker stack ls
docker service ls
docker ps
```

### 8.5 Services überprüfen

```bash
# Alle Services auflisten
docker service ls

# Ausgabe sollte ähnlich sein:
# ID          NAME              MODE        REPLICAS   IMAGE
# abc123...   mailserver_...    replicated  1/1        mailserver/docker-mailserver:latest
# def456...   traefik_traefik   replicated  1/1        traefik:v2.10

# Service Logs anzeigen
docker service logs <service-name>

# Beispiel:
docker service logs mailserver_mailserver
docker service logs traefik_traefik
```

---

## 9. Post-Deployment Konfiguration

### 9.1 PostfixAdmin Initial Setup

```bash
# PostfixAdmin ist unter https://postfixadmin.cloud-ah.online erreichbar

# 1. Browser öffnen und aufrufen:
https://postfixadmin.cloud-ah.online/setup

# 2. Setup-Passwort eingeben (aus .env: POSTFIXADMIN_PASSWORD)

# 3. Schritte:
   - Create Admin Account
   - Add Domain
   - Add Mailbox
   - Configure Aliases (optional)
```

### 9.2 Webmail Setup

```bash
# SnappyMail ist unter https://webmail.cloud-ah.online erreichbar

# Konfiguration erfolgt oft automatisch:
# - IMAP Server: mailserver
# - IMAP Port: 143
# - SMTP Server: mailserver
# - SMTP Port: 587

# Falls manuell notwendig:
# SSH zu Manager und Container-Shell öffnen:
docker exec -it $(docker ps -q -f label=com.docker.compose.service=rainloop) bash
```

---

## 10. Cluster Verwaltung

### 10.1 Service Skalieren

```bash
# Service auf mehrere Replicas skalieren
docker service scale mailserver_mailserver=2

# Rollback wenn Probleme
docker service update --image mailserver/docker-mailserver:latest mailserver_mailserver
```

### 10.2 Service neustarten

```bash
# Service erzwungener Neustart
docker service update --force mailserver_mailserver

# Alle Replicas neustarten
docker service update --force traefik_traefik
```

### 10.3 Node-Management

**Node vom Cluster entfernen:**
```bash
# SSH zu dem Node, der entfernt werden soll
docker swarm leave

# Oder von Manager aus:
docker node rm <node-id>
```

**Node in den Drain-Modus versetzen (keine neuen Container):**
```bash
docker node update --availability drain <node-id>

# Zurück in active Modus
docker node update --availability active <node-id>
```

---

## 11. Monitoring und Troubleshooting

### 11.1 Logs anzeigen

```bash
# Service Logs
docker service logs <service-name>

# Beispiele:
docker service logs mailserver_mailserver
docker service logs mailserver_mariadb
docker service logs mailserver_rainloop
docker service logs traefik_traefik

# Live Logs folgen
docker service logs -f mailserver_mailserver

# Nur letzte 50 Zeilen
docker service logs --tail 50 mailserver_mailserver
```

### 11.2 Container-Status überprüfen

```bash
# Alle laufenden Container
docker ps

# Ausgabe zeigt:
# - Container ID
# - Image
# - Command
# - Created
# - Status
# - Ports
# - Names

# Nur auf diesem Knoten
docker ps -a
```

### 11.3 Resource-Nutzung überwachen

```bash
# Live Docker Stats
docker stats

# Zeigt pro Container:
# - CPU %
# - Memory Usage
# - Memory %
# - Network I/O
# - Block I/O

# Spezifischer Container
docker stats <container-id>
```

### 11.4 Swarm Health Check

```bash
# Nodes überprüfen
docker node ls

# Manager-Quorum überprüfen
docker node inspect <manager-id> --pretty | grep -A 5 "Reachability"

# Services überprüfen
docker service ls

# Tasks (Container) pro Service
docker service ps <service-name>

# Beispiel:
docker service ps mailserver_mailserver
```

---

## 12. Häufige Probleme und Lösungen

### 12.1 Worker kann nicht beitreten

**Fehler:**
```
Error response from daemon: could not choose an IP address
```

**Lösung:**
1. IP-Adressen überprüfen: `ip addr show`
2. Netzwerk-Konnektivität testen: `ping <manager_private_ip>`
3. Firewall überprüfen: Ports 2377, 7946, 4789 offen?
4. Token überprüfen: `docker swarm join-token worker`

### 12.2 Service startet nicht

**Fehler:**
```
docker service ls zeigt 0/1 statt 1/1
```

**Lösung:**
```bash
# Service Logs prüfen
docker service logs <service-name>

# Tasks Detailliere überprüfen
docker service ps <service-name>

# Häufig: fehlende Volumes, Ports bereits belegt
docker ps  # Lokale Container überprüfen

# Service neustarten
docker service update --force <service-name>
```

### 12.3 Overlay Network Problem

**Fehler:**
```
Error response from daemon: failed to create overlay network
```

**Lösung:**
```bash
# Netzwerk-Treiber überprüfen
docker info | grep "kernel version"

# Netzwerke auflisten
docker network ls

# Netzwerk debuggen
docker network inspect traefik-public

# Netzwerk neu erstellen (falls korrupt)
docker network rm traefik-public
docker network create -d overlay --attachable traefik-public
```

### 12.4 Manager nicht erreichbar

**Fehler:**
```
Error: rpc error: code = Unavailable
```

**Lösung:**
1. Manager-Knoten überprüfen: `docker ps` auf Manager
2. Manager-IP überprüfen: `hostname -I`
3. Swarm-Status: `docker info`
4. Manager neustarten: `sudo systemctl restart docker`

### 12.5 SSH-Zugriff fehlgeschlagen

**Fehler:**
```
Connection refused / Permission denied
```

**Lösung:**
```bash
# SSH-Schlüssel Permissions
chmod 600 your-key.pem

# Verbose SSH für Debug
ssh -v -i your-key.pem ubuntu@<ip>

# Security Group überprüfen (AWS Console)
# Port 22 offen? CIDR blocks korrekt?

# Auf EC2-Instanz SSH starten (falls nicht läuft)
sudo systemctl restart ssh
```

---

## 13. Sicherheit und Best Practices

### 13.1 Secrets Management

```bash
# Secrets in Swarm erstellen (für Prod)
echo "my_secure_password" | docker secret create db_password -

# In Service verwenden
docker service create \
  --secret db_password \
  my_service
```

### 13.2 Firewall-Härtung

**In Security Group (AWS):**
```
Port 2377 (TCP): Nur Manager-IP
Port 7946 (TCP/UDP): Nur VPC CIDR
Port 4789 (UDP): Nur VPC CIDR
Port 22 (SSH): Nur Admin IP
```

### 13.3 Backup Strategy

```bash
# Swarm Token backupen
docker swarm join-token worker > ~/swarm-worker-token.txt
docker swarm join-token manager > ~/swarm-manager-token.txt

# Sensitive Daten sichern
tar czf ~/swarm-backup.tar.gz \
  /var/lib/docker/swarm \
  /opt/traefik/acme.json

# Auf sicheren Ort kopieren
scp ~/swarm-backup.tar.gz backup-server:/backups/
```

### 13.4 Updates durchführen

```bash
# Rolling Update (keine Downtime)
docker service update \
  --image mailserver/docker-mailserver:latest \
  --update-parallelism 1 \
  --update-delay 30s \
  mailserver_mailserver

# Update-Status verfolgen
docker service ps mailserver_mailserver
```

---

## 14. Weitere Konfiguration

### 14.1 Labels und Constraints

```bash
# Node mit Label versehen
docker node update --label-add role=manager swarm-node-0

# Service nur auf Nodes mit Label starten
docker service create \
  --constraint node.labels.role==manager \
  --name my_service \
  my_image
```

### 14.2 Service Discovery

```bash
# Container können sich gegenseitig per Namen erreichen
# innerhalb des Overlay Networks:

# Von Container A:
curl http://service-b:8080

# Service Name Resolution funktioniert automatisch
# Dank eingebautem DNS Server
```

### 14.3 Load Balancing

```bash
# Services werden automatisch load-balanced
# über alle Replicas und Nodes

# Load Balancing überprüfen:
docker service inspect <service-name> | grep -A 10 "Endpoint"

# Ausgabe zeigt VIP (Virtual IP)
```

---

## 15. Checkliste für Deployment

- [ ] **Terraform**: 3x EC2 Instanzen erfolgreich erstellt
- [ ] **SSH-Zugriff**: Zu allen 3 Knoten möglich
- [ ] **Docker**: Installation überprüft auf allen Knoten
- [ ] **Manager-Swarm**: `docker swarm init` ausgeführt
- [ ] **Worker 1**: Mit Swarm verbunden
- [ ] **Worker 2**: Mit Swarm verbunden
- [ ] **Nodes**: `docker node ls` zeigt alle 3 Knoten
- [ ] **Networks**: `traefik-public` und `mailnet` erstellt
- [ ] **Dateien**: docker-compose.stack.yml, traefik.yml, .env kopiert
- [ ] **Directories**: /opt/mailserver/, /opt/traefik erstellt
- [ ] **Stacks**: Traefik und Mailserver deployed
- [ ] **Services**: `docker service ls` zeigt alle Services
- [ ] **PostfixAdmin**: Erreichbar unter https://postfixadmin.cloud-ah.online
- [ ] **Webmail**: Erreichbar unter https://webmail.cloud-ah.online
- [ ] **Logs**: Überprüft auf Fehler mit `docker service logs`

---

## 16. Glossar

| Begriff | Erklärung |
|---------|-----------|
| **Swarm** | Docker-Cluster-Orchestration |
| **Manager** | Knoten, der Swarm koordiniert und Services orchestriert |
| **Worker** | Knoten, der Container ausführt |
| **Service** | Container-Gruppe mit gleicher Konfiguration |
| **Task** | Einzelner Container einer Service |
| **Stack** | Mehrere Services zusammen (docker-compose Format) |
| **Overlay Network** | Multi-Host Netzwerk für Container-Kommunikation |
| **Node ID** | Eindeutige Kennung eines Swarm-Nodes |
| **Join Token** | Secret Token zum Verbinden von Worker/Manager |
| **Quorum** | Mehrheit der Manager-Knoten (für HA) |
| **Constraint** | Bedingung, auf welchem Node Services laufen |
| **Label** | Key-Value Paar für Knoten-Charakterisierung |
| **VIP** | Virtual IP für Service Load Balancing |
| **VXLAN** | Virtual Extensible LAN (Overlay Network Protokoll) |
| **Gossip Protocol** | Verteilter Informationsaustausch zwischen Nodes |

---

## 17. Nützliche Commands

```bash
# **MANAGER NODES:**

# Swarm Status
docker info | grep -A 20 "Swarm:"

# Alle Nodes anzeigen
docker node ls

# Node-Details
docker node inspect <node-id>

# Service verwalten
docker service ls
docker service ps <service-name>
docker service logs <service-name>

# Neue Services starten
docker service create [OPTIONS] IMAGE [COMMAND]

# Services skalieren
docker service scale <service-name>=<replicas>

# Services updaten
docker service update [OPTIONS] <service-name>

# Stack Operationen
docker stack deploy -c docker-compose.yml <stack-name>
docker stack ls
docker stack ps <stack-name>
docker stack rm <stack-name>

# **WORKER NODES:**

# Swarm Status
docker info | grep Swarm

# Lokale Container
docker ps

# Aus Swarm austreten
docker swarm leave
```

---

## 18. Weiterführende Ressourcen

**Docker Swarm Documentation:**
- [Docker Swarm Docs](https://docs.docker.com/engine/swarm/)
- [Service Deployment](https://docs.docker.com/engine/swarm/services/)
- [Networking](https://docs.docker.com/engine/swarm/networking/)

**Best Practices:**
- [Docker Production Readiness Checklist](https://docs.docker.com/engine/swarm/admin_guide/)
- [High Availability Setup](https://docs.docker.com/engine/swarm/raft/)

**Troubleshooting:**
- [Docker Swarm Troubleshooting](https://docs.docker.com/engine/swarm/troubleshoot/)
- [Common Issues](https://docs.docker.com/engine/reference/commandline/swarm/)

---

**Letzter Update:** Juni 2026  
**Kompatible Versionen:** Docker 20.10+, Docker Compose 2.0+
