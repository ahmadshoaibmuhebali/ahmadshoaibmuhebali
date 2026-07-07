# AWS Infrastruktur - Terraform Dokumentation
**Version:** 1.0  
**Datum:** Juni 2026  
**Cloud Provider:** Amazon Web Services (AWS)  
**Region:** us-east-1

---

## 1. Übersicht

Diese Terraform-Konfiguration erstellt eine vollständige AWS-Infrastruktur für einen **Docker Swarm Cluster** mit 3 Knoten zur Ausführung des SnappyMail E-Mail-Servers.

**Ziel:** Hochverfügbare und skalierbare E-Mail-Infrastruktur in der Cloud

**Ressourcen:**
- 3x EC2 Instances (t3.medium) - Ubuntu 24.04 LTS
- 1x Security Group (Netzwerk-Firewall)
- 1x Elastic IP (statische öffentliche IP für Manager)
- VPC und Subnets (bestehend)

---

## 2. Terraform Konfiguration

### 2.1 Backend Konfiguration (`backend.tf`)

```hcl
terraform {
  required_version = ">= 1.0"
  
  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
```

**Backend:** Lokale State-Datei (`terraform.tfstate`)

| Parameter | Wert | Beschreibung |
|-----------|------|-------------|
| `terraform.version` | >= 1.0 | Mindestversion Terraform |
| `aws.version` | ~> 5.0 | AWS Provider Version 5.x |
| `aws.region` | us-east-1 | AWS Region (Nordirland) |
| `backend.path` | terraform.tfstate | Lokale State-Datei |

### 2.2 AWS Provider Konfiguration

- **Region:** `us-east-1` (USA - Nordirland)
- **API Version:** AWS Provider ~> 5.0
- **Zugriff:** Mittels AWS Credentials (z.B. ~/.aws/credentials)

---

## 3. Netzwerk-Infrastruktur

### 3.1 VPC und Subnets (bestehend)

```hcl
data "aws_vpc" "default" {
  id = "vpc-0d89e2f9a58287f88"
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }
}
```

**Bestehende VPC:** `vpc-0d89e2f9a58287f88`

**Verfügbarkeitszonen:**
- `us-east-1a` - Verfügbar für t3.medium
- `us-east-1b` - Verfügbar für t3.medium
- `us-east-1c` - Verfügbar für t3.medium
- `us-east-1e` - **Nicht verwendet** (Kapazitätsprobleme mit t3.medium)

**Subnet-Zuordnung:**
- Die 3 EC2-Instanzen werden reihum auf die 3 verfügbaren Subnets verteilt
- Gewährleistet hohe Verfügbarkeit durch geografische Verteilung

### 3.2 Security Group

```hcl
resource "aws_security_group" "ec2_sg" {
  name        = "stalwart-ec2-sg"
  description = "Allow mail traffic and SSH inside default VPC"
  vpc_id      = data.aws_vpc.default.id
  ...
}
```

**Name:** `stalwart-ec2-sg`  
**VPC:** Default VPC (`vpc-0d89e2f9a58287f88`)

#### Eingehende Regeln (Ingress)

**E-Mail und Web-Management Ports:**
| Port | Protokoll | Quelle | Zweck |
|------|-----------|--------|-------|
| 25 | TCP | 0.0.0.0/0 | SMTP (Inbound Mail) |
| 465 | TCP | 0.0.0.0/0 | SMTPS (Implizites TLS) |
| 587 | TCP | 0.0.0.0/0 | SMTP Submission (STARTTLS) |
| 143 | TCP | 0.0.0.0/0 | IMAP (STARTTLS) |
| 993 | TCP | 0.0.0.0/0 | IMAPS (Implizites TLS) |
| 80 | TCP | 0.0.0.0/0 | HTTP (Web) |
| 443 | TCP | 0.0.0.0/0 | HTTPS (Traefik SSL) |
| 8080 | TCP | 0.0.0.0/0 | Alternative HTTP |

**SSH Zugriff:**
| Port | Protokoll | Quelle | Zweck |
|------|-----------|--------|-------|
| 22 | TCP | 0.0.0.0/0 | SSH (Remote Access) |

**Interne Cluster-Kommunikation:**
| Protokoll | Quelle | Zweck |
|-----------|--------|-------|
| Alle (-1) | Self | Docker Swarm Overlay Networking |

#### Ausgehende Regeln (Egress)

| Protokoll | Ziel | Zweck |
|-----------|------|-------|
| Alle (-1) | 0.0.0.0/0 | Alle ausgehenden Verbindungen erlaubt |

---

## 4. EC2 Instanzen (Docker Swarm Knoten)

### 4.1 Allgemeine Konfiguration

```hcl
resource "aws_instance" "swarm_nodes" {
  count         = 3
  ami           = "ami-091138d0f0d41ff90"  # Ubuntu 24.04 LTS
  instance_type = "t3.medium"
  ...
}
```

**Anzahl Instanzen:** 3

| Parameter | Wert | Beschreibung |
|-----------|------|-------------|
| `ami` | ami-091138d0f0d41ff90 | Ubuntu 24.04 LTS (us-east-1) |
| `instance_type` | t3.medium | 2 vCPU, 4 GB RAM, burstable performance |
| `root_block_device.volume_size` | 30 GB | Speichergrösse des Root-Volumes |
| `root_block_device.volume_type` | gp3 | General Purpose SSD (kostengünstig) |

### 4.2 Netzwerk-Konfiguration

**Subnet-Zuordnung:**
```hcl
subnet_id = element(data.aws_subnets.default.ids, count.index)
```

- **Node 0 (Manager):** Subnet us-east-1a
- **Node 1 (Worker):** Subnet us-east-1b
- **Node 2 (Worker):** Subnet us-east-1c

**Sicherheit:**
```hcl
vpc_security_group_ids = [aws_security_group.ec2_sg.id]
```

Alle Instanzen verwenden die `stalwart-ec2-sg` Security Group

### 4.3 Instance-Initialisierung (User Data)

Die User Data Skript führt bei der Instance-Initialisierung automatisch aus:

```bash
#cloud-config
package_update: true
package_upgrade: true
packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
runcmd:
  # Docker GPG-Schlüssel installieren
  - install -m 0755 -d /etc/apt/keyrings
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  - chmod a+r /etc/apt/keyrings/docker.asc
  
  # Docker Repository hinzufügen
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] 
    https://download.docker.com/linux/ubuntu noble stable" | 
    tee /etc/apt/sources.list.d/docker.list > /dev/null
  
  # Docker installieren
  - apt-get update -y
  - apt-get install -y docker-ce docker-ce-cli containerd.io 
    docker-buildx-plugin docker-compose-plugin
  
  # Docker starten
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker ubuntu
```

**Installation Steps:**
1. ✅ OS Updates durchführen
2. ✅ Abhängigkeiten installieren
3. ✅ Docker GPG-Schlüssel einrichten
4. ✅ Docker Repository konfigurieren
5. ✅ Docker Engine + Tools installieren
6. ✅ Docker Daemon starten und aktivieren
7. ✅ Ubuntu-Benutzer zu docker-Gruppe hinzufügen

**Nach der Installation ist Docker ready für Docker Swarm**

### 4.4 Instance-Tags

Für jede Instanz werden automatisch Tags gesetzt:

```hcl
tags = {
  Name = "swarm-node-${count.index}"
  Role = count.index == 0 ? "manager" : "worker"
}
```

| Node | Name | Role |
|------|------|------|
| 0 | swarm-node-0 | manager |
| 1 | swarm-node-1 | worker |
| 2 | swarm-node-2 | worker |

---

## 5. Elastic IP für Manager-Knoten

```hcl
resource "aws_eip" "manager_eip" {
  instance = aws_instance.swarm_nodes[0].id
  domain   = "vpc"
  tags     = { Name = "stalwart-manager-eip" }
}
```

**Zweck:** Statische öffentliche IP-Adresse für den Manager-Knoten

**Vorteile:**
- IP ändert sich nicht beim Stop/Start der Instanz
- Ermöglicht stabile DNS-Einträge
- Notwendig für Produktions-Umgebungen

**Zuordnung:** Manager-Knoten (`swarm-node-0`)

---

## 6. Terraform Outputs

```hcl
output "manager_public_ip" {
  description = "Static public IP of the manager node"
  value       = aws_eip.manager_eip.public_ip
}

output "worker_public_ips" {
  description = "Public IPs of worker nodes"
  value       = [aws_instance.swarm_nodes[1].public_ip, 
                  aws_instance.swarm_nodes[2].public_ip]
}

output "ec2_private_ips" {
  description = "Private internal IPs for Swarm Cluster setup"
  value       = aws_instance.swarm_nodes[*].private_ip
}
```

Nach dem `terraform apply` werden diese Informationen ausgegeben:

| Output | Beispiel | Zweck |
|--------|----------|-------|
| `manager_public_ip` | 54.XXX.XXX.XXX | SSH Zugriff auf Manager |
| `worker_public_ips` | [52.XXX..., 34.XXX...] | SSH Zugriff auf Worker |
| `ec2_private_ips` | [10.0.1.10, 10.0.2.20, ...] | Docker Swarm Initialisierung |

---

## 7. Deployment und Verwaltung

### 7.1 Voraussetzungen

- **Terraform:** >= 1.0 installiert
- **AWS CLI:** Konfiguriert mit Credentials
- **AWS Permissions:** EC2, VPC, EIP, Security Groups, Tags

**AWS Credentials einrichten:**
```bash
aws configure
# AWS Access Key ID: [xxx]
# AWS Secret Access Key: [xxx]
# Default region: us-east-1
# Default output format: json
```

### 7.2 Deployment

**1. Terraform initialisieren:**
```bash
cd terraform/
terraform init
```

**2. Plan anzeigen (vor Deployment):**
```bash
terraform plan -out=tfplan
```

**3. Infrastruktur erstellen:**
```bash
terraform apply tfplan
```

**Erwartete Dauer:** ~5-10 Minuten
- VPC/Subnet Abfrage: ~30 Sekunden
- Security Group erstellen: ~1 Minute
- 3x EC2-Instanzen starten: ~3-5 Minuten
- Cloud-init Skript ausführen: ~2-3 Minuten

**4. Outputs anzeigen:**
```bash
terraform output
```

### 7.3 Docker Swarm Initialisierung (nach Terraform)

**SSH zur Manager-Instanz:**
```bash
ssh -i your-key.pem ubuntu@<manager_public_ip>
```

**Swarm initialisieren:**
```bash
docker swarm init --advertise-addr <manager_private_ip>
```

**Worker-Token abrufen:**
```bash
docker swarm join-token worker
```

**Auf Worker-Instanzen ausführen:**
```bash
docker swarm join --token SWMTKN-... <manager_private_ip>:2377
```

**Status überprüfen:**
```bash
docker node ls
docker service ls
```

### 7.4 Stack Deployment (nach Swarm Setup)

```bash
# SSH in Manager
ssh -i your-key.pem ubuntu@<manager_public_ip>

# Config Dateien kopieren
scp -i your-key.pem docker-compose.stack.yml ubuntu@<manager_ip>:/home/ubuntu/
scp -i your-key.pem traefik.yml ubuntu@<manager_ip>:/home/ubuntu/
scp -i your-key.pem .env ubuntu@<manager_ip>:/home/ubuntu/

# Externe Netzwerk erstellen
docker network create -d overlay traefik-public

# Stacks deployen
docker stack deploy -c docker-compose.stack.yml mailserver
docker stack deploy -c traefik.yml traefik
```

---

## 8. Instance-Details

### 8.1 t3.medium Spezifikationen

| Spezifikation | Wert |
|---------------|------|
| vCPU | 2 (burstable) |
| Memory | 4 GB |
| Network Performance | Bis zu 5 Gbps |
| EBS-optimiert | Ja |
| Max Durchsatz (EBS) | Bis zu 4,750 MB/s |
| Max Bandbreite (Netzwerk) | Bis zu 5 Gbps |

**CPU Credits:**
- Burstable Performance Instanz
- Sammelt CPU Credits während normaler Auslastung
- Nutzt Credits für Burst-Phase bei hoher Last
- Kostenoptimiert für variable Workloads

### 8.2 Root Volume

| Parameter | Wert |
|-----------|------|
| Größe | 30 GB |
| Typ | gp3 (General Purpose SSD) |
| Verschlüsselung | Standard AWS-Verschlüsselung |
| IOPS | 3000 (Baseline) |
| Durchsatz | 125 MB/s (Baseline) |

**Speichernutzung Schätzung:**
- Ubuntu OS: ~2-3 GB
- Docker + Dienste: ~5-8 GB
- Mail-Daten: ~15-20 GB
- **Verfügbar:** ~30 GB

⚠️ **Hinweis:** Bei größerem Mailserver-Wachstum zusätzliche EBS-Volumes oder S3-Backup empfohlen.

---

## 9. Netzwerk-Architektur

```
┌─────────────────────────────────────────────────┐
│             AWS Region: us-east-1                │
│                                                   │
│  ┌───────────────────────────────────────────┐  │
│  │  VPC: vpc-0d89e2f9a58287f88               │  │
│  │                                             │  │
│  │  ┌──────────────┐  ┌──────────────┐       │  │
│  │  │ Subnet AZ-a  │  │ Subnet AZ-b  │       │  │
│  │  │              │  │              │       │  │
│  │  │ swarm-node-0 │  │ swarm-node-1 │       │  │
│  │  │ (Manager)    │  │ (Worker)     │       │  │
│  │  │              │  │              │       │  │
│  │  └──────────────┘  └──────────────┘       │  │
│  │                                             │  │
│  │  ┌──────────────┐                          │  │
│  │  │ Subnet AZ-c  │                          │  │
│  │  │              │                          │  │
│  │  │ swarm-node-2 │                          │  │
│  │  │ (Worker)     │                          │  │
│  │  │              │                          │  │
│  │  └──────────────┘                          │  │
│  │                                             │  │
│  │  Security Group: stalwart-ec2-sg           │  │
│  │  - SMTP (25, 465, 587)                     │  │
│  │  - IMAP (143, 993)                         │  │
│  │  - HTTP/HTTPS (80, 443, 8080)              │  │
│  │  - SSH (22)                                │  │
│  │  - Docker Swarm (internal, self)           │  │
│  └───────────────────────────────────────────┘  │
│                                                   │
│  Elastic IP (Manager): 54.XXX.XXX.XXX            │
└─────────────────────────────────────────────────┘
                        │
                        ▼
            ┌─────────────────────┐
            │  Internet Gateway    │
            │  (Public Internet)   │
            └─────────────────────┘
```

### 9.1 Verfügbarkeitszonen (AZs)

Die 3 Knoten sind über 3 verschiedene Verfügbarkeitszonen verteilt:

| Node | AZ | Vorteile |
|------|----|---------| 
| swarm-node-0 (Manager) | us-east-1a | Redundanz bei AZ-Ausfall |
| swarm-node-1 (Worker) | us-east-1b | Verteilte Arbeitslast |
| swarm-node-2 (Worker) | us-east-1c | Hochverfügbarkeit |

**Hochverfügbarkeit:**
- Wenn AZ-a ausfällt: Manager funktioniert noch (aber reduziert)
- Wenn AZ-b oder AZ-c ausfällt: Worker-Kapazität sinkt
- Docker Swarm repliziert Services automatisch

---

## 10. Kosten-Schätzung (AWS)

**Monatliche Schätzung (US-East-1):**

| Ressource | Typ | Menge | Kosten/Monat |
|-----------|-----|-------|--------------|
| EC2 Instances | t3.medium (On-Demand) | 3 | ~45 USD |
| EBS Volumes | gp3 (30 GB × 3) | 90 GB | ~9 USD |
| Elastic IP | (Wenn im Einsatz) | 1 | ~4 USD |
| Data Transfer | (Outbound) | ~100 GB | ~9 USD |
| **Total (Schätzung)** | | | **~67 USD** |

**Optimierungsmöglichkeiten:**
- Savings Plans: ~30% Rabatt auf EC2
- Reserved Instances: ~40% Rabatt für 1-Jahr
- Spot Instances: ~70% Rabatt (nicht für Produktion)

---

## 11. Sicherheit und Best Practices

### 11.1 Sicherheitsgruppe

**Aktuell:** Offene Ports (0.0.0.0/0)
- ✅ Gut für E-Mail-Server (muss öffentlich erreichbar sein)
- ⚠️ SSH sollte auf bekannte IPs beschränkt werden

**Empfohlene Sicherheitsverbesserungen:**

```hcl
# SSH nur von Admin-IP zulassen
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["YOUR_ADMIN_IP/32"]
}

# Mail-Ports bleiben offen
# (Notwendig für globale E-Mail-Kommunikation)
```

### 11.2 IAM und Credentials

- **AWS Credentials:** In ~/.aws/credentials speichern (nicht im Git!)
- **MFA:** Aktivieren für AWS Console
- **IAM Benutzer:** Terraform mit spezialisiertem IAM-Benutzer ausführen (nicht Root)

### 11.3 Backup und Disaster Recovery

**State-Datei schützen:**
```bash
# terraform.tfstate ist sensibel!
# .gitignore eintragen:
echo "terraform.tfstate*" >> .gitignore
```

**Remote State (Empfohlen für Produktion):**
```hcl
# terraform.tfstate in S3 speichern
backend "s3" {
  bucket         = "my-terraform-state"
  key            = "mailserver/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-lock"
}
```

### 11.4 Monitoring und Logging

**CloudWatch aktivieren:**
```bash
# SSH zu Manager
ssh ubuntu@<manager_ip>

# CloudWatch Agent installieren
wget https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogsd-agent-setup.py
python3 awslogsd-agent-setup.py -n -r us-east-1 -c ec2
```

---

## 12. Maintenance und Updates

### 12.1 Terraform State Backups

```bash
# State-Datei sichern
cp terraform.tfstate terraform.tfstate.backup

# Mit Versionskontrolle (nicht Git!)
git add .gitignore  # terraform.tfstate* eintragen
git commit -m "Add terraform state to gitignore"
```

### 12.2 Instance Updates

**Nach Terraform Deployment:**
```bash
# SSH zu Manager
ssh -i your-key.pem ubuntu@<manager_ip>

# OS Updates durchführen
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get autoremove -y

# Docker Updates
sudo apt-get install --only-upgrade docker-ce

# Services neu starten
docker service update --force <service_name>
```

### 12.3 Volume Erweiterung

Wenn Speicher knapp wird:

```hcl
# main.tf anpassen
root_block_device {
  volume_size = 50  # 30 GB → 50 GB
  volume_type = "gp3"
}

# Änderungen anwenden
terraform plan
terraform apply
```

**Dann auf Instanz:**
```bash
# Filesystem erweitern
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
```

---

## 13. Troubleshooting

### 13.1 Terraform Fehler: VPC nicht gefunden

**Fehler:**
```
Error: Error on AWS API call: VpcId 'vpc-0d89e2f9a58287f88' does not exist
```

**Lösung:**
1. VPC-ID überprüfen: `aws ec2 describe-vpcs --region us-east-1`
2. In `main.tf` korrekte VPC-ID eintragen
3. VPC muss in us-east-1 Region sein

### 13.2 Instance bootet nicht (t3.medium nicht verfügbar)

**Fehler:**
```
InsufficientInstanceCapacity: insufficient capacity in availability zone
```

**Lösung:**
- us-east-1e ist für t3.medium oft nicht verfügbar
- Terraform nutzt bereits us-east-1a, 1b, 1c (sicherer)
- Alternativ: `instance_type = "t3.small"` versuchen

### 13.3 SSH Verbindung fehlgeschlagen

**Fehler:**
```
Connection refused on port 22
```

**Lösung:**
1. Sicherheitsgruppe prüfen: Port 22 erlaubt?
2. SSH-Schlüssel Permissions: `chmod 600 your-key.pem`
3. Instance initialisiert noch (warten Sie ~2 Minuten)
4. Elastische IP nutzen (nicht die temporäre Public IP)

### 13.4 Terraform State korrupt

**Fehler:**
```
Error: failed to decode state: json: cannot unmarshal
```

**Lösung:**
```bash
# Backup vorhanden?
cp terraform.tfstate.backup terraform.tfstate

# Remote State überprüfen (falls konfiguriert)
terraform state list
terraform state show aws_instance.swarm_nodes

# Schlimmstenfalls: Neustart
terraform destroy
terraform apply
```

---

## 14. Glossar

| Begriff | Erklärung |
|---------|-----------|
| **VPC** | Virtual Private Cloud - Isoliertes Netzwerk in AWS |
| **Subnet** | Netzwerk-Unterteilung innerhalb VPC |
| **Availability Zone (AZ)** | Physisches Rechenzentrum in einer Region |
| **EC2** | Elastic Compute Cloud - Virtuelle Server |
| **t3.medium** | Instance-Typ mit 2 vCPU, 4 GB RAM, burstable |
| **Elastic IP** | Statische öffentliche IP-Adresse |
| **Security Group** | Virtuelle Firewall für Netzwerk-Zugriff |
| **AMI** | Amazon Machine Image - VM-Template |
| **user_data** | Initialisierungs-Skript für neue Instanzen |
| **Cloud-init** | Standard Cloud-Konfigurationsformat |
| **docker-compose** | Container-Orchestration Definitionsdatei |
| **Docker Swarm** | Native Docker-Cluster-Orchestration |
| **State File** | terraform.tfstate mit aktueller Infrastruktur-Definition |
| **Provider** | Terraform-Plugin für Cloud-Provider (AWS, Azure, etc.) |
| **Resource** | Infrastruktur-Komponente (EC2, Security Group, etc.) |
| **Data Source** | Abfrage bestehender AWS-Ressourcen |

---

## 15. Weitere Ressourcen

**AWS Documentation:**
- [EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [VPC und Subnets](https://docs.aws.amazon.com/vpc/)
- [Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)

**Terraform Documentation:**
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [Terraform Best Practices](https://learn.hashicorp.com/tutorials/terraform/best-practices)
- [Docker Swarm Mode](https://docs.docker.com/engine/swarm/)

**Cloud-init Documentation:**
- [Cloud-init Docs](https://cloud-init.io/)
- [Ubuntu Cloud-init](https://cloudinit.readthedocs.io/)

---

**Letzter Update:** Juni 2026  
**Kompatible Versionen:** Terraform >= 1.0, AWS Provider ~> 5.0
