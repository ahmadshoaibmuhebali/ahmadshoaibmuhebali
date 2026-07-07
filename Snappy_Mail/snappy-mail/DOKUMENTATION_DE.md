# SnappyMail E-Mail Server - Dokumentation

**Sprache:** Deutsch (Schweizer Hochdeutsch)  
**Version:** 1.0  
**Datum:** Juni 2026

---

## 1. Übersicht

Dieses Projekt implementiert einen vollständigen E-Mail-Server mit Web-Interface basierend auf Docker Swarm. Der Server ermöglicht:

- **E-Mail-Verwaltung**: Vollständige SMTP-, IMAP- und POP3-Unterstützung
- **Web-Zugriff**: SnappyMail Webmail-Interface für Benutzer
- **Admin-Interface**: PostfixAdmin zur Verwaltung von Domains, Benutzern und Aliassen
- **Sichere Kommunikation**: Automatisches SSL/TLS-Zertifikat-Management via Let's Encrypt
- **Skalierbare Infrastruktur**: Docker Swarm für Hochverfügbarkeit

---

## 2. Systemarchitektur

### 2.1 Architektur-Übersicht

Das System ist in folgende Schichten unterteilt:

![Architecture](/Bild/architecture.png)

### 2.2 Netzwerk-Topologie

**Traefik-Public Network** (Extern):
- Für Web-Zugriff (HTTP/HTTPS)
- Öffentlich erreichbar via Ports 80 und 443
- Enthält: Traefik, PostfixAdmin, SnappyMail

**Mailnet Network** (Intern):
- Privates Overlay-Netzwerk für interne Kommunikation
- E-Mail-Protokoll-Verkehr (SMTP, IMAP, POP3)
- Datenbank- und Cache-Kommunikation

---

## 3. Komponenten im Detail

### 3.1 Docker Mailserver (Core Mail Engine)

**Image:** `mailserver/docker-mailserver:latest`

**Funktion:** Zentrale Mail-Engine für Versand und Empfang von E-Mails.

**Ports:**
| Port | Protokoll | Beschreibung |
|------|-----------|-------------|
| 25 | SMTP | Eingehende Mail von externen Servern |
| 143 | IMAP | IMAP mit STARTTLS (unverschlüsselt, aber mit TLS) |
| 465 | ESMTP | Implizites SSL/TLS (Secure SMTP) |
| 587 | SMTP Submission | Explizites STARTTLS für Client-Submission |
| 993 | IMAPS | IMAP mit implizitem SSL/TLS |

**Umgebungsvariablen:**
```yaml
DOMAINNAME=${DOMAIN}              # Haupt-Domain
HOSTNAME=${MAILSERVER_FQDN}       # Fully Qualified Domain Name
DMS_DB_HOST=mariadb               # Datenbank-Host
DMS_DB_NAME=mailserver            # Datenbankname
DMS_DB_USER=mailuser              # Datenbank-Benutzer
DMS_DB_PASS=${MYSQL_PASSWORD}     # Datenbank-Passwort
POSTFIXADMIN_PASSWORD=${...}      # PostfixAdmin Setup-Passwort
SSL_TYPE=manual                   # SSL-Zertifikate von Host laden
RELAY_HOST=${RELAY_HOST}          # SMTP-Relay (SandGrind)
RELAY_PORT=${RELAY_PORT}          # Relay-Port
RELAY_USER=${RELAY_USER}          # Relay-Benutzer
RELAY_PASSWORD=${RELAY_PASSWORD}  # Relay-Passwort
```

**Volumes:**
| Host-Pfad | Container-Pfad | Beschreibung |
|-----------|----------------|-------------|
| `/var/dms/custom-certs` | `/tmp/dms/custom-certs` | SSL-Zertifikate (Read-only) |
| `mail_data` | `/var/mail` | Mail-Speicher |
| `mail_vmail` | `/var/vmail` | Virtual-Mail-Daten |
| `mail_dkim` | `/etc/opendkim/keys` | DKIM-Schlüssel |
| `./certs` | `/etc/letsencrypt/live` | Let's Encrypt-Zertifikate |
| `./config` | `/tmp/docker-mailserver` | Mailserver-Konfiguration |

**Constraints:**
- Läuft nur auf Manager-Nodes (Docker Swarm)
- Eine Replica

---

### 3.2 MariaDB (Datenbank)

**Image:** `mariadb:10.11`

**Funktion:** Relationale Datenbank für:
- PostfixAdmin-Daten (Domains, Benutzer, Aliasse)
- Docker Mailserver Konfiguration
- Authentifizierung

**Umgebungsvariablen:**
```yaml
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=mailserver
MYSQL_USER=mailuser
MYSQL_PASSWORD=${MYSQL_PASSWORD}
```

**Health-Check:**
- Interval: 10 Sekunden
- Timeout: 5 Sekunden
- Max Retries: 5

**Volumes:**
| Docker Volume | Container-Pfad | Beschreibung |
|--------------|----------------|-------------|
| `mysql_data` | `/var/lib/mysql` | Persistente DB-Daten |

---

### 3.3 Redis (In-Memory Cache)

**Image:** `redis:7-alpine`

**Funktion:**
- Session-Caching
- Performance-Optimierung
- Daten-Caching für Mailserver

**Volumes:**
| Docker Volume | Container-Pfad | Beschreibung |
|--------------|----------------|-------------|
| `redis_data` | `/data` | Persistente Cache-Daten |

---

### 3.4 PostfixAdmin (Verwaltungs-Web-UI)

**Image:** `postfixadmin:latest`

**Funktion:** Web-basierte Verwaltungsoberfläche für:
- Domain-Management
- Benutzer-Management
- Alias-Verwaltung
- Mailbox-Konfiguration

**Domain:** `postfixadmin.cloud-ah.online`

**Umgebungsvariablen:**
```yaml
POSTFIXADMIN_DB_TYPE=mysqli
POSTFIXADMIN_DB_HOST=mariadb
POSTFIXADMIN_DB_NAME=mailserver
POSTFIXADMIN_DB_USER=mailuser
POSTFIXADMIN_DB_PASSWORD=${MYSQL_PASSWORD}
POSTFIXADMIN_SETUP_PASSWORD=${POSTFIXADMIN_PASSWORD}
POSTFIXADMIN_SMTP_SERVER=${MAILSERVER_FQDN}
POSTFIXADMIN_DOMAIN=${DOMAIN}
```

**Traefik-Labels:**
- HTTPS aktiviert
- Let's Encrypt SSL/TLS
- URL-Routing via Host-Header

**Volumes:**
| Docker Volume | Container-Pfad | Beschreibung |
|--------------|----------------|-------------|
| `postfixadmin_data` | `/var/www/postfixadmin/templates_c` | Template-Cache |

---

### 3.5 SnappyMail (Webmail-Interface)

**Image:** `djmaze/snappymail:latest`

**Funktion:** Benutzerfreundliches Webmail-Interface für:
- E-Mail-Empfang
- E-Mail-Versand
- Kontaktverwaltung
- Kalender und Aufgaben

**Domain:** `webmail.cloud-ah.online`

**Umgebungsvariablen:**
```yaml
RAINLOOP_DOMAIN=${DOMAIN}
RAINLOOP_IMAP_HOST=${MAILSERVER_FQDN}
RAINLOOP_IMAP_PORT=143
RAINLOOP_SMTP_HOST=${MAILSERVER_FQDN}
RAINLOOP_SMTP_PORT=587
```

**Traefik-Labels:**
- HTTPS aktiviert
- Let's Encrypt SSL/TLS
- Interner Port: 8888
- URL-Routing via Host-Header

**Volumes:**
| Docker Volume | Container-Pfad | Beschreibung |
|--------------|----------------|-------------|
| `snappy_persistent` | `/var/lib/snappymail` | Benutzer-Einstellungen |

**Bind-Mount:** `/opt/mailserver/snappymail-data`

---

### 3.6 Traefik (Reverse Proxy & Ingress Controller)

**Image:** `traefik:v2.10`

**Funktion:**
- SSL/TLS-Terminierung
- Reverse Proxy für Web-Services
- Automatisches Certificate Management via Let's Encrypt
- HTTP → HTTPS Weiterleitung

**Ports:**
| Port | Protokoll | Beschreibung |
|------|-----------|-------------|
| 80 | HTTP | Wird zu HTTPS umgeleitet |
| 443 | HTTPS | Sichere Kommunikation |

**Konfiguration:**
```yaml
# Docker Swarm-Integration
--providers.docker=true
--providers.docker.swarmmode=true
--providers.docker.endpoint=unix:///var/run/docker.sock

# Entry Points
--entrypoints.web.address=:80
--entrypoints.websecure.address=:443
--entrypoints.web.http.redirections.entryPoint.to=websecure
--entrypoints.web.http.redirections.entryPoint.scheme=https

# Let's Encrypt ACME
--certificatesresolvers.letsencrypt.acme.tlschallenge=true
--certificatesresolvers.letsencrypt.acme.email=admin@cloud-ah.online
--certificatesresolvers.letsencrypt.acme.storage=/acme.json
```

**Volumes:**
| Host-Pfad | Container-Pfad | Beschreibung |
|-----------|----------------|-------------|
| `/var/run/docker.sock` | `/var/run/docker.sock` | Docker Daemon Socket (Read-only) |
| `/opt/traefik/acme.json` | `/acme.json` | Let's Encrypt Zertifikate |

**ACME Speicherort:**
- Host: `/opt/traefik/acme.json`
- Permissions: `600` (nur Owner lesbar/schreibbar)

---

## 4. Datenfluss und Kommunikation

### 4.1 Eingehende E-Mails (Inbound)

1. **Externe Mail-Server** senden E-Mails via SMTP (Port 25)
2. **Docker Mailserver** empfängt die E-Mails
3. **MariaDB** speichert Routing-Informationen
4. E-Mail wird in **mail_data** und **mail_vmail** Volumes gespeichert
5. **Redis** cacht häufig zugegriffene Daten

### 4.2 Ausgehende E-Mails (Outbound)

1. **Webmail-Benutzer** senden E-Mail via SnappyMail
2. SnappyMail sendet via SMTP (Port 587) an **Docker Mailserver**
3. **Docker Mailserver** validiert die E-Mail via **MariaDB**
4. E-Mail wird an **SandGrind SMTP Relay** weitergeleitet (SMTP Port 587)
5. **SandGrind** liefert die E-Mail zu finalem Empfänger

### 4.3 Web-Zugriff

1. **Benutzer** öffnet Browser auf Port 80 oder 443
2. **Traefik** terminiert SSL/TLS und leitet zu PostfixAdmin oder SnappyMail
3. Services kommunizieren mit **MariaDB** und **Redis**
4. Antwort wird verschlüsselt zurück zum Browser gesendet

---

## 5. Volumes und Persistierung

### 5.1 Named Volumes (Docker-managed)

```yaml
mail_data:                # Mail-Speicher
mail_vmail:               # Virtual Mail-Speicher
mail_dkim:                # DKIM-Schlüssel für Signierung
mysql_data:               # MariaDB-Datenbank
redis_data:               # Redis-Cache
postfixadmin_data:        # PostfixAdmin Template-Cache
snappy_persistent:        # SnappyMail Benutzerdaten
  driver: local
  driver_opts:
    type: none
    o: bind
    device: /opt/mailserver/snappymail-data
```

### 5.2 Bind-Mounts (Host-Dateisystem)

| Host-Pfad | Container-Pfad | Service | Beschreibung |
|-----------|----------------|---------|-------------|
| `/var/dms/custom-certs` | `/tmp/dms/custom-certs` | mailserver | SSL-Zertifikate (RO) |
| `./certs` | `/etc/letsencrypt/live` | mailserver | Let's Encrypt Zerts (RO) |
| `./config` | `/tmp/docker-mailserver` | mailserver | Mailserver-Konfiguration |
| `/var/run/docker.sock` | `/var/run/docker.sock` | traefik | Docker Daemon (RO) |
| `/opt/traefik/acme.json` | `/acme.json` | traefik | Let's Encrypt ACME |

---

## 6. Sicherheitsfeatures

### 6.1 TLS/SSL-Verschlüsselung

- **Traefik**: Automatische HTTPS-Zertifikate via Let's Encrypt
- **Docker Mailserver**: Manuell konfigurierte Zertifikate
- **STARTTLS**: Port 143 (IMAP), Port 587 (SMTP Submission)
- **Implicit TLS**: Port 465 (SMTPS), Port 993 (IMAPS)

### 6.2 Netzwerk-Isolation

- **mailnet**: Privates Overlay-Netzwerk für interne Dienste
- **traefik-public**: Externe Network für Web-Services
- Externe Mail-Server können nur Port 25 erreichen

### 6.3 Authentifizierung

- **MariaDB**: Benutzername + Passwort für alle Dienste
- **PostfixAdmin**: Setup-Passwort für Admin-Zugang
- **SMTP Relay**: Authentifizierung gegen SandGrind

### 6.4 Datenschutz (Volume Permissions)

- `/var/dms/custom-certs`: Read-only mounting
- `/etc/letsencrypt/live`: Read-only mounting
- `/opt/traefik/acme.json`: Permissions 600

---

## 7. Deployment und Konfiguration

### 7.1 Erforderliche Umgebungsvariablen

Erstellen Sie eine `.env` Datei im Deployment-Verzeichnis:

```bash
# Domain-Konfiguration
DOMAIN=example.com
MAILSERVER_FQDN=mail.example.com

# Datenbank
MYSQL_ROOT_PASSWORD=secure_root_password_123
MYSQL_PASSWORD=secure_user_password_456

# PostfixAdmin
POSTFIXADMIN_PASSWORD=secure_admin_password_789

# SMTP Relay (SandGrind)
RELAY_HOST=smtp.sandgrind.de
RELAY_PORT=587
RELAY_USER=your_sandgrind_username
RELAY_PASSWORD=your_sandgrind_password
```

### 7.2 Docker Swarm Initialisierung

```bash
# Swarm initialisieren (falls nicht bereits geschehen)
docker swarm init

# Externe Netzwerk erstellen
docker network create -d overlay traefik-public

# Stack deployen
docker stack deploy -c docker-compose.stack.yml mailserver
docker stack deploy -c traefik.yml traefik
```

### 7.3 PostfixAdmin Initial Setup

1. Öffnen Sie `https://postfixadmin.cloud-ah.online`
2. Klicken Sie auf "Setup" im Admin-Bereich
3. Geben Sie das PostfixAdmin Setup-Passwort ein
4. Erstellen Sie eine Admin-Domain
5. Fügen Sie E-Mail-Domains hinzu
6. Erstellen Sie Benutzer und Aliasse

---

## 8. Wartung und Monitoring

### 8.1 Logs anzeigen

```bash
# Docker Mailserver Logs
docker service logs mailserver_mailserver

# PostfixAdmin Logs
docker service logs mailserver_postfixadmin

# SnappyMail Logs
docker service logs mailserver_rainloop

# Traefik Logs
docker service logs traefik_traefik

# MariaDB Logs
docker service logs mailserver_mariadb
```

### 8.2 Health Checks

MariaDB führt regelmässig Health-Checks durch:
```bash
mysqladmin ping -h localhost
```

Interval: 10 Sekunden | Timeout: 5 Sekunden | Retries: 5

### 8.3 Backup-Strategie

**Kritische Volumes:**
1. `mysql_data` - Tägliches Backup
2. `mail_data` + `mail_vmail` - Wöchentliches Backup
3. `/opt/traefik/acme.json` - Monatliches Backup
4. `/opt/mailserver/snappymail-data` - Monatliches Backup

**Backup-Befehl (Beispiel):**
```bash
docker run --rm -v mailserver_mysql_data:/data \
  -v /backup:/backup \
  -w /data \
  mariadb:10.11 \
  tar czf /backup/mysql_backup.tar.gz .
```

### 8.4 Service Status prüfen

```bash
docker service ls
docker service ps mailserver_mailserver
docker stack services mailserver
```

---

## 9. Troubleshooting

### 9.1 E-Mails werden nicht empfangen

- **Symptom**: Eingehende E-Mails landen nicht im Postfach
- **Lösung**:
  1. Prüfe Mailserver-Logs: `docker service logs mailserver_mailserver`
  2. Überprüfe Domain-Konfiguration in PostfixAdmin
  3. Prüfe DNS MX-Records
  4. Überprüfe Benutzer existiert in MariaDB

### 9.2 IMAP/SMTP Verbindung fehlgeschlagen

- **Symptom**: E-Mail-Client kann nicht verbinden
- **Lösung**:
  1. Überprüfe Port-Freigabe: `netstat -tlnp | grep :143`
  2. Prüfe SSL-Zertifikate: `docker exec mailserver_mailserver ls -la /tmp/dms/custom-certs/`
  3. Überprüfe Firewall-Regeln
  4. Test mit OpenSSL: `openssl s_client -connect mail.example.com:993`

### 9.3 SnappyMail zeigt 502 Bad Gateway

- **Symptom**: Webmail lädt nicht (502 Error)
- **Lösung**:
  1. Überprüfe Port-Konfiguration in Traefik-Labels (Port 8888)
  2. Prüfe SnappyMail Container-Status
  3. Überprüfe Netzwerk-Verbindung

### 9.4 Let's Encrypt Zertifikat erneuert sich nicht

- **Symptom**: Ablauf-Warnung für SSL-Zertifikate
- **Lösung**:
  1. Prüfe Traefik Logs für ACME-Fehler
  2. Überprüfe `/opt/traefik/acme.json` Permissions (sollte 600 sein)
  3. Stelle sicher, dass Port 80 und 443 extern erreichbar sind
  4. Neustarten: `docker service update --force traefik_traefik`

---

## 10. Best Practices

### 10.1 Sicherheit

- ✅ Nutze starke Passwörter (mind. 20 Zeichen)
- ✅ Aktiviere 2-Faktor-Authentifizierung in PostfixAdmin (falls verfügbar)
- ✅ Beschränke SSH-Zugang zum Host
- ✅ Nutze Firewall für Port-Beschränkung
- ✅ Überprüfe regelmässig Logs auf Anomalien

### 10.2 Performance

- ✅ Redis-Cache nutzen für häufig zugegriffene Daten
- ✅ MariaDB regelmässig optimieren: `OPTIMIZE TABLE`
- ✅ Datenbank-Backups regelmässig durchführen
- ✅ Mailserver-Logs rotieren: `logrotate`
- ✅ Monitoring einrichten (z.B. Prometheus + Grafana)

### 10.3 Hochverfügbarkeit

- ✅ Nutze mehrere Docker Swarm Manager-Nodes
- ✅ Repliziere Volumes auf mehreren Nodes
- ✅ Nutze LoadBalancer für redundante Mailserver-Instanzen
- ✅ Überprüfe regelmässig Service-Status
- ✅ Implementiere Health-Checks

---

## 11. Glossar

| Begriff | Erklärung |
|---------|-----------|
| **SMTP** | Simple Mail Transfer Protocol - Protokoll für E-Mail-Versand |
| **IMAP** | Internet Message Access Protocol - Protokoll für E-Mail-Abruf |
| **POP3** | Post Office Protocol v3 - Älteres E-Mail-Abruf-Protokoll |
| **STARTTLS** | Upgrade auf TLS-Verschlüsselung nach initialer Verbindung |
| **Implicit TLS** | TLS-Verschlüsselung von Anfang an |
| **DKIM** | DomainKeys Identified Mail - Digitale Signatur für E-Mails |
| **ACME** | Automatic Certificate Management Environment - Protokoll für Let's Encrypt |
| **Overlay Network** | Docker Swarm internes virtuelles Netzwerk |
| **Bind-Mount** | Direct Mounting von Host-Dateisystem in Container |
| **Named Volume** | Docker-verwaltetes Persistentes Speicher-Volume |
| **Health Check** | Automatische Überprüfung des Service-Status |
| **Reverse Proxy** | Service, der Anfragen an Backend-Services weiterleitet |

---

**Letzter Update:** Juni 2026  
**Kompatible Versionen:** Docker 20.10+, Docker Swarm Mode
