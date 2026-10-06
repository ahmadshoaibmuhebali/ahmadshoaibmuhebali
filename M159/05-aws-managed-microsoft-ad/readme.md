# AWS Managed AD / AD-Trust – Ersetzt durch Samba 4 AD

> [!WARNING]
>
> **Hinweis:** AWS Managed AD ist kostenpflichtig (ca. 18 $ pro Woche). Für dieses Modul wurde stattdessen ein **Samba 4 AD DC** verwendet. Die folgende Dokumentation beschreibt die Einrichtung einer **External Trust**-Beziehung zwischen dem Windows AD (`DC1.CLOUD-AH.LOCAL`) und dem Samba 4 AD (`CLOUD-AH.COM`).

![Modul_159_Architekturdiagramm](/M159/images/nework-diagramm.svg)
---

## Umgebung

| Komponente | Rolle | Domäne / Host | NetBIOS | Beschreibung |
| :--- | :--- | :--- | :--- | :--- |
| **DC01** | Windows Server AD DC | `DC1.CLOUD-AH.LOCAL` | `INTERN` | Interne Benutzer, Gruppen, SMB-Freigaben und NTFS-Ressourcen |
| **DC02** | Samba 4 AD DC | `CLOUD-AH.COM` | `CLOUD-AH` | Externe Benutzer und Gruppen (`Partner`, `Promoter`, `Extern`) |
| **Trust** | External Trust | bidirektional | – | Vertrauensstellung zwischen beiden Domänen |

**Samba 4 AD – Spezifische Daten:**

- Forest: `cloud-ah.com`
- Domain: `cloud-ah.com`
- NetBIOS-Domain: `CLOUD-AH`
- DC-Name: `dc2.cloud-ah.com`
- DC-NetBIOS-Name: `DC2`
- Server-Site: `Default-First-Site-Name`
- Client-Site: `Default-First-Site-Name`

---

## 1. Voraussetzungen

Bevor die Vertrauensstellung eingerichtet werden kann, müssen folgende Bedingungen erfüllt sein:

1. **DNS-Auflösung:** Beide Domänen müssen sich gegenseitig auflösen können. Dazu werden **Conditional Forwarder** auf beiden DNS-Servern eingerichtet.
2. **Ports:** Die erforderlichen Ports für Kerberos, LDAP, SMB, DNS etc. müssen zwischen den Servern geöffnet sein.
3. **Zeitsynchronisation:** Die Systemzeiten beider DCs müssen synchron sein (Kerberos toleriert max. 5 Minuten Abweichung).
4. **Administrative Rechte:** Auf beiden DCs werden Domänen-Administrator-Rechte benötigt.

---

## 2. Conditional Forwarders

Damit der Windows AD DNS-Server die Samba-Domäne `cloud-ah.com` auflösen kann und umgekehrt, werden bedingte Weiterleitungen eingerichtet.

### 2.1 Windows DC `DC01` – DNS Conditional Forwarder

1. **DNS-Verwaltung öffnen:** `dnsmgmt.msc`
2. Rechtsklick auf **Conditional Forwarders** → **New Conditional Forwarder**
3. **DNS Domain:** `cloud-ah.com`
4. **IP-Adressen:** IP-Adresse des Samba 4 DC `DC2` eintragen (z. B. `10.0.0.2`)
5. **Store this conditional forwarder in Active Directory** aktivieren
6. Mit **OK** bestätigen

**Test auf DC01:**

```cmd
nslookup -type=SOA cloud-ah.com
nslookup dc2.cloud-ah.com
```
![Test-Result-DC01](/M159/images/dns_lookup_trust.png)

### 2.2 Samba 4 DC `DC02` – DNS Forwarder

Auf dem Samba 4 DC wird ein DNS-Forwarder für die Windows-Domäne `dc1.cloud-ah.local` eingerichtet.

**In der `smb.conf` unter `[global]` ergänzen:**

```ini
dns forwarder = 10.0.9.193
```

Beispiel:

```ini
# Global parameters
[global]
        dns forwarder = 10.0.9.193
        netbios name = DC2
        realm = CLOUD-AH.COM
        server role = active directory domain controller
        workgroup = CLOUD-AH
        idmap_ldb:use rfc2307 = yes
        # LDAPS Configuration
        tls enabled = yes
        tls cafile = /var/lib/samba/private/tls/ca.pem
        tls certfile = /var/lib/samba/private/tls/cert.pem
        tls keyfile = /var/lib/samba/private/tls/key.pem
        # Winbind & Trust Domain ID Mapping
        winbind enum users = yes
        winbind enum groups = yes
        idmap config * : backend = tdb
        idmap config * : range = 3000000-4000000
        idmap config DC1 : backend = rid
        idmap config DC1 : range = 2000000-2999999
        ntlm auth = mschapv2-and-ntlmv2-only
[sysvol]
	path = /var/lib/samba/sysvol
	read only = No

[netlogon]
	path = /var/lib/samba/sysvol/cloud-ah.com/scripts
	read only = No
```

Anschliessend Samba-Dienste neu starten:

```bash
sudo systemctl restart samba-ad-dc
```
![Samba-4-AD-Service-Status](/M159/images/Samba-4-AD-Service.png)

**Test auf DC02:**

```bash
nslookup -type=SOA dc1.cloud-ah.local
nslookup dc01.dc1.cloud-ah.local
```
![Test-REesult](/M159/images/dns-dc02-test-result.png)

> [!TIP]
>
> Prüfen Sie die Auflösung in beide Richtungen mit `nslookup`. Bei Problemen kontrollieren Sie die Firewall-Regeln und die DNS-Einstellungen.

---

## 3. Trust einrichten

Die Vertrauensstellung wird als **External Trust** (bidirektional) eingerichtet. Die Einrichtung kann auf der Windows-Seite begonnen und auf der Samba-Seite abgeschlossen werden (oder umgekehrt).

### 3.1 Windows DC `DC01` – Trust anlegen

1. **Active Directory Domänen- und Vertrauensstellungen** öffnen: `domain.msc`
2. Rechtsklick auf die Domäne `DC1.CLOUD-AH.LOCAL` → **Eigenschaften**
3. Reiter **Vertrauensstellungen** → **Neue Vertrauensstellung**
4. **Trust-Assistent:**
   - **Name der Domäne:** `cloud-ah.com`
   - **Trust-Typ:** **Externe Vertrauensstellung** (External Trust)
   - **Richtung:** **Bidirektional** (Both directions)
   - **Seiten:** **Both this domain and the specified domain**
   - **Benutzername/Passwort:** Domänen-Administrator der Samba-Domäne (`CLOUD-AH\Administrator`) und dessen Passwort
5. **Vertrauensstellung bestätigen:** Im Assistenten die Option **Confirm Outgoing Trust** und **Confirm Incoming Trust** wählen.
6. Abschliessen und die Vertrauensstellung ggf. validieren.

### 3.2 Samba 4 DC `DC02` – Trust erstellen

Auf dem Samba 4 DC wird die Vertrauensstellung mit `samba-tool` erstellt.

**Befehl:**

```bash
sudo samba-tool domain trust create DC1.CLOUD-AH.LOCAL \
    --type=external \
    --direction=both \
    --username=Administrator \
    --password=<Passwort des Windows-Domänen-Admins>
```

**Erklärung der Parameter:**

- `DC1.CLOUD-AH.LOCAL` – Name der Windows-Domäne
- `--type=external` – Externe Vertrauensstellung
- `--direction=both` – Bidirektional
- `--username` / `--password` – Anmeldedaten eines Administrators der Windows-Domäne

Nach erfolgreicher Erstellung kann die Vertrauensstellung validiert werden.

**Trust auflisten:**

```bash
sudo samba-tool domain trust list
```
![Turst-List-Samba](/M159/images/Tust-List-Samba.png)

```powershell
nltest /domain_trusts
```
![Trust-List-Windows](/M159/images/Trust-List-Windows.png)

---

## 4. Zusammenfassung

Die Vertrauensstellung zwischen dem Windows AD (`DC1.CLOUD-AH.LOCAL`) und dem Samba 4 AD (`CLOUD-AH.COM`) wurde erfolgreich als **External Trust** eingerichtet.  
Durch die Conditional Forwarder auf beiden DNS-Servern ist die gegenseitige Namensauflösung gewährleistet.  
Die Validierung bestätigt die Funktionsfähigkeit der Vertrauensstellung.  
Externe Benutzer aus `CLOUD-AH.COM` können nun kontrolliert auf Freigaben des Windows-Servers `DC01` zugreifen, wobei die NTFS-Berechtigungen die zentrale Steuerungsinstanz bilden.
