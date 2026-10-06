# Freigaben, Laufwerke & Berechtigungen - Gesamtdokumentation

## Umgebung & Domänen-Szenario

| Komponente | Rolle | Domäne / Host | Beschreibung |
| :--- | :--- | :--- | :--- |
| **DC01** | Windows Server AD DC | `DC1.CLOUD-AH.LOCAL` | Interne Benutzer, interne Gruppen, SMB-Freigaben und NTFS-Ressourcen |
| **DC02** | Samba 4 AD DC | `CLOUD-AH.COM` | CLOUD-AH.COMe Benutzer und cloud-ah.come Gruppen (`Partner`, `Promoter`, `CLOUD-AH.COM`) |
| **Trust** | CLOUD-AH.COMal Trust | `DC1.CLOUD-AH.LOCAL` <-> `CLOUD-AH.COM` | Bidirektionaler CLOUD-AH.COMal Trust; für Zugriff auf DC01-Ressourcen muss `DC1.CLOUD-AH.LOCAL` die Domäne `CLOUD-AH.COM` vertrauen |
| **DNS** | Namensauflösung | Conditional Forwarder / Stub Zone | Beide Domänen müssen sich gegenseitig auflösen können |

---

## 1. Einleitung & Aufgabenstellung

Diese Dokumentation beschreibt die Umsetzung und Konfiguration von Dateifreigaben, Gruppenstrukturen, NTFS-Berechtigungen sowie Sicherheitsrichtlinien unter Windows Server (`DC01`) in einer Umgebung mit **zwei getrennten AD-Domänen**:

- **Windows DC `DC01`** in der Domäne `DC1.CLOUD-AH.LOCAL` für interne Benutzer, interne Gruppen und die zentralen SMB-Freigaben.
- **Samba 4 AD DC `DC02`** in der Domäne `CLOUD-AH.COM` für cloud-ah.come Benutzer und cloud-ah.come Gruppen.
- Beide Domänen sind über einen **CLOUD-AH.COMal Trust** verbunden.

Die Kernziele umfassen:
- Konfiguration von Benutzer- und Gruppenstrukturen im Active Directory (`DC1.CLOUD-AH.LOCAL`) sowie im Samba 4 AD (`CLOUD-AH.COM`).
- Saubere Trennung von Freigabeberechtigungen (SMB Share Level) und NTFS-Dateisystemberechtigungen.
- Einsatz von **Access-Based Enumeration (ABE)** zur Ausblendung unberechtigter Ordner.
- Reorganisation der Rechtevergabe nach dem Best-Practice-Standard **AGDLP**.
- Nutzung des CLOUD-AH.COMal Trusts, damit cloud-ah.come Benutzer aus `CLOUD-AH.COM` auf Freigaben auf `DC01` zugreifen können.

---

## 2. User und Gruppen in Active Directory

### 2.1 Anlegen der Gruppen & Strukturierung

Die Gruppen werden auf zwei Systeme verteilt angelegt:

#### Windows DC `DC01` – Domäne `DC1.CLOUD-AH.LOCAL`

Im Active Directory Administrative Center (ADAC) bzw. über *Active Directory-Benutzer und -Computer* wurden globale Sicherheitsgruppen (*Global Security Groups*) für alle internen Abteilungen sowie die Dachgruppe `Intern` angelegt.

**Interne Abteilungsgruppen:**
- `GL`
- `Aussendienst`
- `Sekretariat`
- `Buchhaltung`
- `Informatik`
- `Messemitarbeiter`

**Interne Hauptgruppe:**
- `Intern`

#### Samba 4 AD DC `DC02` – Domäne `CLOUD-AH.COM`

Auf dem Samba 4 AD DC wurden die cloud-ah.comen Gruppen über `samba-tool` oder RSAT angelegt.

**CLOUD-AH.COMe Gruppen:**
- `Partner`
- `Promoter`

**CLOUD-AH.COMe Hauptgruppe:**
- `CLOUD-AH.COM`

**Beispielhafte Samba-4-Befehle:**

```bash
# Auf DC02 – CLOUD-AH.COM
samba-tool group add CLOUD-AH.COM
samba-tool group add Partner
samba-tool group add Promoter
samba-tool group addmembers CLOUD-AH.COM Partner
samba-tool group addmembers CLOUD-AH.COM Promoter
```

**Überprüfung der Mitgliedschaften:**

```bash
sudo samba-tool group listmembers CLOUD-AH.COM
```

**Ausgabe:**

```text
Partner
Promoter
```

> **Passwortrichtlinie Note:** Falls das Anlegen von Benutzern aufgrund strenger Komplexitätsanforderungen fehlschlägt, können die Richtlinien in der Group Policy Management Console unter `Default Domain Policy -> Computerkonfiguration -> Richtlinien -> Windows-Einstellungen -> Sicherheitseinstellungen -> Kontorichtlinien -> Kennwortrichtlinien` angepasst werden.  
> Für Samba 4 AD gilt die Passwortrichtlinie der Samba-Domäne; sie kann z. B. über `samba-tool domain passwordsettings` angepasst werden.

---

### 2.2 Verschachtelung: Intern vs. CLOUD-AH.COM

Die internen Abteilungen werden der Hauptgruppe `Intern` in `DC1.CLOUD-AH.LOCAL` zugewiesen.  
Die cloud-ah.comen Abteilungen `Partner` und `Promoter` werden der Hauptgruppe `CLOUD-AH.COM` in `CLOUD-AH.COM` zugewiesen.

1. **Gruppe `Intern` (`DC1.CLOUD-AH.LOCAL`):**  
   Enthält als Mitglieder die internen Abteilungsgruppen:
   - `GL`
   - `Aussendienst`
   - `Sekretariat`
   - `Buchhaltung`
   - `Informatik`
   - `Messemitarbeiter`

2. **Gruppe `CLOUD-AH.COM` (`CLOUD-AH.COM`):**  
   Enthält als Mitglieder die cloud-ah.comen Abteilungsgruppen:
   - `Partner`
   - `Promoter`

```text
Windows DC (DC1.CLOUD-AH.LOCAL)
────────────────────────────────────────────────────────────
[Benutzer] ──> [Abteilungsgruppe] ──> [Hauptgruppe: Intern]
                                  ├──> GL
                                  ├──> Aussendienst
                                  ├──> Sekretariat
                                  ├──> Buchhaltung
                                  ├──> Informatik
                                  └──> Messemitarbeiter

Samba 4 AD DC (CLOUD-AH.COM)
────────────────────────────────────────────────────────────
[Benutzer] ──> [Abteilungsgruppe: Partner]  ──┐
[Benutzer] ──> [Abteilungsgruppe: Promoter] ──┴──> [Hauptgruppe: CLOUD-AH.COM]

CLOUD-AH.COMal Trust
────────────────────────────────────────────────────────────
DC1.CLOUD-AH.LOCAL  <================ CLOUD-AH.COMal Trust ================>  CLOUD-AH.COM
```

---

### 2.3 Anmeldung & Test am Windows Client

Die internen Benutzer wurden ihren jeweiligen Abteilungsgruppen in `DC1.CLOUD-AH.LOCAL` hinzugefügt.  
Die cloud-ah.comen Benutzer wurden ihren Gruppen in `CLOUD-AH.COM` hinzugefügt.

Zur Validierung wurden Testanmeldungen an einem Windows 10/11 Client durchgeführt:

- Anmeldung mit einem internen Benutzer aus der Abteilung `Sekretariat` (`INTERN\sek1`).
- Anmeldung mit einem internen Benutzer aus der Abteilung `GL` (`INTERN\gl1`).
- Anmeldung mit einem cloud-ah.comen Benutzer aus der Abteilung `Partner` (`CLOUD-AH.COM\partner1`).
- Anmeldung mit einem cloud-ah.comen Benutzer aus der Abteilung `Promoter` (`CLOUD-AH.COM\promoter1`).

Die Anmeldung, die Vertrauensstellung und die Bereitstellung der Kerberos-Tickets verliefen erfolgreich.

---

## 3. UNC (Uniform Naming Convention)

### 3.1 Grundlagen & Aufbau

Die **Uniform Naming Convention (UNC)** ist eine standardisierte Syntax zur Identifikation und Adressierung von freigegebenen Ressourcen in einem Local Area Network (LAN).

#### Syntaxschema:
```text
\\<Hostname_oder_IP>\<Freigabename>[\Unterordner][\Dateiname]
```

Bei domänenübergreifendem Zugriff sollte bevorzugt der FQDN verwendet werden:
```text
\\DC01.DC1.CLOUD-AH.LOCAL\<Freigabename>
```

---

### 3.2 Praxisbeispiele im Servernetzwerk

In der Testumgebung auf Server **DC01** ergeben sich folgende UNC-Pfade für den Netzwerkzugriff:

- **Hauptdatenpfad:** `\\DC01\Daten` bzw. `\\DC01.DC1.CLOUD-AH.LOCAL\Daten`
- **Abteilungsübersicht:** `\\DC01\Abteilungen` bzw. `\\DC01.DC1.CLOUD-AH.LOCAL\Abteilungen`
- **Spezifische Abteilungen:**
  - `\\DC01\Abteilungen\Sekretariat`
  - `\\DC01\Abteilungen\Buchhaltung`
  - `\\DC01\Abteilungen\Partner`
  - `\\DC01\Abteilungen\Promoter`
- **Pool-Bereich:** `\\DC01\Pool`
- **Interne / CLOUD-AH.COMe Bereiche:** `\\DC01\Intern` und `\\DC01\CLOUD-AH.COM`

CLOUD-AH.COMe Benutzer aus `CLOUD-AH.COM` greifen mit ihren Anmeldeinformationen `CLOUD-AH.COM\<Benutzername>` auf die Freigaben von `DC01` zu. Der CLOUD-AH.COMal Trust stellt dabei die Authentifizierung und Autorisierung sicher.

---

## 4. Ordner- & Freigabestruktur sowie NTFS-Berechtigungen

### 4.1 Freigabeübersicht (SMB Shares)

Folgende SMB-Freigaben wurden auf dem Windows Server `DC01` eingerichtet:

| Share Name | Local Path (DC01) | Protocol | Availability Type |
| :--- | :--- | :---: | :--- |
| **Daten** | `C:\Daten` | SMB | Not Clustered |
| **Pool** | `C:\Daten\Pool` | SMB | Not Clustered |
| **Abteilungen** | `C:\Daten\Abteilungen` | SMB | Not Clustered |
| **Intern** | `C:\Intern` | SMB | Not Clustered |
| **CLOUD-AH.COM** | `C:\CLOUD-AH.COM` | SMB | Not Clustered |

> Die SMB-Freigaben liegen ausschliesslich auf `DC01` in der Domäne `DC1.CLOUD-AH.LOCAL`.  
> CLOUD-AH.COMe Benutzer aus `CLOUD-AH.COM` greifen über den CLOUD-AH.COMal Trust auf diese Freigaben zu.

---

### 4.2 Vererbung & Basis-Freigaberechte

1. **SMB Freigabeberechtigungen (Share Permissions):**
   - Auf allen oben genannten Freigaben erhält die Gruppe **`Jeder` (Everyone)** die Freigabeberechtigung **«Ändern» (Change)** und **«Lesen» (Read)**.
   - Die Begrenzung der Zugriffsrechte erfolgt zentral über NTFS-Rechte.

2. **Deaktivierung der NTFS-Vererbung:**
   - Auf dem Stammordner `C:\Daten` und allen Unterordnern wurde die Vererbung deaktiviert (*Block Inheritance / Explicit ACLs*).
   - Die Standardgruppe `Domänen-Benutzer` (Domain Users) wurde aus allen ACLs entfernt.

3. **Cross-Domain-Berechtigungen:**
   - CLOUD-AH.COMe Gruppen aus `CLOUD-AH.COM` wie `CLOUD-AH.COM\Partner`, `CLOUD-AH.COM\Promoter` und `CLOUD-AH.COM\CLOUD-AH.COM` können aufgrund des CLOUD-AH.COMal Trusts in NTFS-ACLs auf `DC01` verwendet werden.
   - Für den produktiven Betrieb wird gemäss AGDLP empfohlen, cloud-ah.come globale Gruppen nur in domänenlokale Gruppen von `DC1.CLOUD-AH.LOCAL` aufzunehmen und nicht direkt in NTFS-ACLs einzutragen.

---

### 4.3 Vollständige NTFS-Berechtigungsmatrix

Legende:
- **C** = Change / Ändern (Modifizieren, Lesen, Schreiben, Löschen)
- **R** = Read / Lesen (Lesen & Ausführen, Ordnerinhalt auflisten)
- **-** = Kein Zugriff


| Physischer Pfad (DC01) | INTERN\GL | INTERN\Aussend. | INTERN\Sekretariat | INTERN\Buchhaltung | CLOUD-AH.COM\Promoter | CLOUD-AH.COM\Partner | INTERN\Informatik | INTERN\Messem. | INTERN\Intern | CLOUD-AH.COM\CLOUD-AH.COM |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `C:\Daten\` | **C** | - | - | **C** | - | - | **C** | - | - | - |
| `C:\Daten\Pool` | - | - | - | - | - | - | - | - | **C** | **C** |
| `C:\Daten\Abteilungen` | **C** | - | - | - | - | - | - | - | **R** | **R** |
| `...\Abteilungen\GL` | **C** | - | - | - | - | - | - | - | - | - |
| `...\Abteilungen\Aussendienst` | **C** | **C** | - | - | - | - | - | - | - | - |
| `...\Abteilungen\Sekretariat` | **C** | **R** | **C** | - | **R** | **R** | **R** | **R** | - | - |
| `...\Abteilungen\Buchhaltung` | **C** | **R** | **R** | **C** | **R** | **R** | **R** | **R** | - | - |
| `...\Abteilungen\Promoter` | **C** | - | - | - | **C** | - | - | - | - | - |
| `...\Abteilungen\Partner` | **C** | - | - | - | - | **C** | - | - | - | - |
| `...\Abteilungen\Informatik` | **C** | - | - | - | - | - | **C** | - | - | - |
| `...\Abteilungen\Messemitarbeiter` | **C** | - | - | - | - | - | - | **C** | - | - |
| `C:\Intern` | - | - | - | - | - | - | - | - | **C** | - |
| `C:\CLOUD-AH.COM` | - | - | - | - | - | - | - | - | - | **C** |

> **Wichtig:** Die direkte Vergabe von NTFS-Rechten an `CLOUD-AH.COM\Partner`, `CLOUD-AH.COM\Promoter` oder `CLOUD-AH.COM\CLOUD-AH.COM` funktioniert nur bei bestehendem CLOUD-AH.COMal Trust und korrekter Namensauflösung. Best Practice ist die Kapselung über domänenlokale Gruppen in `DC1.CLOUD-AH.LOCAL` (siehe Abschnitt 7).
![Permission](/images/Permission.png)
---

### 4.4 Automation per PowerShell Script

Zur schnellen und fehlerfreien Bereitstellung der Ordnerstruktur sowie Freigaben auf `DC01` dient das nachfolgende PowerShell-Script.

#### PowerShell auf `DC01` (`DC1.CLOUD-AH.LOCAL`)

```powershell
# 1. Erstellen der Verzeichnisstruktur
$Directories = @(
    "C:\Daten",
    "C:\Daten\Pool",
    "C:\Daten\Abteilungen",
    "C:\Daten\Abteilungen\GL",
    "C:\Daten\Abteilungen\Aussendienst",
    "C:\Daten\Abteilungen\Sekretariat",
    "C:\Daten\Abteilungen\Buchhaltung",
    "C:\Daten\Abteilungen\Promoter",
    "C:\Daten\Abteilungen\Partner",
    "C:\Daten\Abteilungen\Informatik",
    "C:\Daten\Abteilungen\Messemitarbeiter",
    "C:\Intern",
    "C:\CLOUD-AH.COM"
)

foreach ($Path in $Directories) {
    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force
    }
}

# 2. SMB Freigaben konfigurieren (Jeder: Change)
New-SmbShare -Name "Daten" -Path "C:\Daten" -FullAccess "Administratoren" -ChangeAccess "Jeder"
New-SmbShare -Name "Pool" -Path "C:\Daten\Pool" -FullAccess "Administratoren" -ChangeAccess "Jeder"
New-SmbShare -Name "Abteilungen" -Path "C:\Daten\Abteilungen" -FullAccess "Administratoren" -ChangeAccess "Jeder"
New-SmbShare -Name "Intern" -Path "C:\Intern" -FullAccess "Administratoren" -ChangeAccess "Jeder"
New-SmbShare -Name "CLOUD-AH.COM" -Path "C:\CLOUD-AH.COM" -FullAccess "Administratoren" -ChangeAccess "Jeder"

# 3. NTFS Vererbung deaktivieren auf C:\Daten
$Acl = Get-Acl -Path "C:\Daten"
$Acl.SetAccessRuleProtection($true, $false) # Deaktiviert Vererbung, entfernt vererbte Rechte
Set-Acl -Path "C:\Daten" -AclObject $Acl
```

#### Samba 4 AD auf `DC02` (`CLOUD-AH.COM`)

```bash
# CLOUD-AH.COMe Gruppen im Samba 4 AD anlegen
samba-tool group add CLOUD-AH.COM
samba-tool group add Partner
samba-tool group add Promoter
samba-tool group addmembers CLOUD-AH.COM Partner
samba-tool group addmembers CLOUD-AH.COM Promoter

# Beispielbenutzer anlegen und den Abteilungen zuweisen
samba-tool user add partner1 --random-password
samba-tool user add promoter1 --random-password
samba-tool group addmembers Partner partner1
samba-tool group addmembers Promoter promoter1

# Mitglieder der Hauptgruppe CLOUD-AH.COM prüfen
sudo samba-tool group listmembers CLOUD-AH.COM
```

**Erwartete Ausgabe:**

```text
Partner
Promoter
```

> Die NTFS-ACLs werden nicht durch dieses Basis-Script gesetzt, sondern gemäss Berechtigungsmatrix bzw. AGDLP-Konzept in Abschnitt 7 konfiguriert.

---

## 5. Access-Based Enumeration (ABE)

### 5.1 Funktionsweise & Mehrwert

**Access-Based Enumeration (ABE)** filtert die Anzeige von Dateien und Ordnern auf Freigaben basierend auf den individuellen NTFS-Berechtigungen des angemeldeten Benutzers.

- **Mit ABE:** Benutzer sehen ausschliesslich Ordner/Dateien, für die sie mindestens **Lesezugriff** besitzen.
- **Ohne ABE:** Benutzer sehen alle Ordner, erhalten beim Zugriff jedoch eine Fehlermeldung ("Zugriff verweigert").

ABE funktioniert auch für Benutzer aus vertrauenswürdigen Domänen, sofern der CLOUD-AH.COMal Trust korrekt eingerichtet ist und die SIDs der cloud-ah.comen Gruppen aufgelöst werden können.

---

### 5.2 Aktivierung der ABE-Konfiguration

ABE kann im Server-Manager unter *Datei- und Speicherdienste -> Freigaben* in den Eigenschaften der Freigabe aktiviert werden oder direkt per PowerShell auf `DC01`:

```powershell
# ABE aktivieren für alle relevanten SMB Shares auf DC01
Set-SmbShare -Name "Daten" -FolderEnumerationMode AccessBased
Set-SmbShare -Name "Pool" -FolderEnumerationMode AccessBased
Set-SmbShare -Name "Abteilungen" -FolderEnumerationMode AccessBased
Set-SmbShare -Name "Intern" -FolderEnumerationMode AccessBased
Set-SmbShare -Name "CLOUD-AH.COM" -FolderEnumerationMode AccessBased
```

---

## 6. Berechtigungstests & Validierung

Zur Verifizierung der Konfiguration wurden Tests von einem Windows Server Client durchgeführt.  
Dabei wurden sowohl interne Benutzer aus `DC1.CLOUD-AH.LOCAL` als auch cloud-ah.come Benutzer aus `CLOUD-AH.COM` getestet.

| Test-Szenario / Benutzer | Domäne | Ziel-Pfad / UNC | Erwartetes Ergebnis | Tatsächliches Ergebnis | Status |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **Sekretariat**-User | `INTERN` | `\\DC01\Abteilungen\Buchhaltung` | Lesezugriff erlaubt (`R`), Schreiben verweigert | Ordner einsehbar, kein Erstellen von Dateien | **Erfolgreich** |
| **GL**-User | `INTERN` | `\\DC01\Pool` | Schreib- & Ändern-Zugriff erlaubt (`C`) | Vollständiger Schreib- und Ändern-Zugriff | **Erfolgreich** |
| **Promoter**-User | `CLOUD-AH.COM` | `\\DC01\Abteilungen\Aussendienst` | Kein Zugriff (`-`), ABE blendet Ordner aus | Ordner wird nicht im Explorer angezeigt | **Erfolgreich** |
| **Promoter**-User | `CLOUD-AH.COM` | `\\DC01\Abteilungen\Promoter` | Ändern-Zugriff erlaubt (`C`) | Vollständiger Schreib- und Ändern-Zugriff | **Erfolgreich** |
| **Partner**-User | `CLOUD-AH.COM` | `\\DC01\CLOUD-AH.COM` | Ändern-Zugriff erlaubt (`C`) | Vollständiger Schreib- und Ändern-Zugriff | **Erfolgreich** |
| **Partner**-User | `CLOUD-AH.COM` | `\\DC01\Abteilungen\Partner` | Ändern-Zugriff erlaubt (`C`) | Vollständiger Schreib- und Ändern-Zugriff | **Erfolgreich** |
| **Partner**-User | `CLOUD-AH.COM` | `\\DC01\Intern` | Kein Zugriff (`-`), ABE blendet Ordner aus | Ordner wird nicht im Explorer angezeigt | **Erfolgreich** |
| **Partner**-User | `CLOUD-AH.COM` | `\\DC01\Abteilungen\Sekretariat` | Lesezugriff erlaubt (`R`) | Ordner einsehbar, Schreiben verweigert | **Erfolgreich** |

---

## 7. Eigenes Group Nesting Konzept nach AGDLP

### 7.1 Schwachstellenanalyse des Ist-Zustands

Im bisherigen Setup wurden die globalen Abteilungsgruppen direkt in die NTFS-ACLs der Zielordner eingetragen. Durch die neue Domänentrennung kommt erschwerend hinzu, dass cloud-ah.come Gruppen aus `CLOUD-AH.COM` direkt in ACLs auf `DC01` verwendet werden.

**Probleme dieses Vorgehens:**
- **Hoher Wartungsaufwand:** Änderungen an Berechtigungsstrukturen erfordern Anpassungen im NTFS-Dateisystem.
- **Fehlende Skalierbarkeit:** In Domänen-Landschaften mit CLOUD-AH.COMal Trusts können globale Gruppen nicht domänenübergreifend flexibel und sauber verschachtelt werden.
- **Cross-Domain-Abhängigkeiten:** Direkte ACL-Einträge mit `CLOUD-AH.COM\...` erfordern eine funktionierende Vertrauensstellung und Namensauflösung.
- **SID-Filtering:** CLOUD-AH.COMal Trusts haben standardmässig SID-Filtering aktiviert. Direkte Cross-Domain-ACLs sind dadurch fehleranfälliger.
- **Mangelnde Dokumentation:** NTFS-ACLs werden unübersichtlich und schwer prüfbar.

---

### 7.2 Das AGDLP-Prinzip

Das **AGDLP-Modell** löst diese Probleme durch eine saubere Kaskadierung:

1. **A** = **Account**: Der Endbenutzer.
2. **G** = **Global Group**: Repräsentiert die Organisationseinheit / Rolle.  
   - Interne Benutzer: globale Gruppe in `DC1.CLOUD-AH.LOCAL`.
   - CLOUD-AH.COMe Benutzer: globale Gruppe in `CLOUD-AH.COM` (z. B. `G_Partner`, `G_Promoter`).
3. **DL** = **Domain Local Group**: Repräsentiert die Zugriffsressource und das Recht.  
   - Diese Gruppen liegen immer in der Ressourcendomäne `DC1.CLOUD-AH.LOCAL` auf `DC01`.
4. **P** = **Permissions**: Das tatsächliche NTFS-Recht auf dem Ordner.

```text
Interne Benutzer:
[INTERN\User (A)] ──> [INTERN\G_Sekretariat (G)] ──> [INTERN\DL_Ordner_Sekretariat_Change (DL)] ──> [NTFS Change (P)]

CLOUD-AH.COMe Benutzer:
[CLOUD-AH.COM\User (A)] ──> [CLOUD-AH.COM\G_Partner (G)] ──> [INTERN\DL_Ordner_Partner_Change (DL)] ──> [NTFS Change (P)]

CLOUD-AH.COMe Benutzer Promoter:
[CLOUD-AH.COM\User (A)] ──> [CLOUD-AH.COM\G_Promoter (G)] ──> [INTERN\DL_Ordner_Promoter_Change (DL)] ──> [NTFS Change (P)]
```

**Entscheidend:**  
Die globalen Gruppen verbleiben in ihrer jeweiligen Benutzerdomäne. Die domänenlokalen Gruppen liegen immer in der Ressourcendomäne `DC1.CLOUD-AH.LOCAL`. Dadurch bleiben NTFS-ACLs stabil und wartbar.

---

### 7.3 Visualisierung der Ziel-Architektur

```text
+-----------------------------------------------------------------------------------+
| WINDOWS AD DC (DC01) - DC1.CLOUD-AH.LOCAL                                         |
| Ressourcen: C:\Daten, C:\Intern, C:\CLOUD-AH.COM, SMB-Freigaben                         |
+-----------------------------------------------------------------------------------+
                                   ^
                                   | CLOUD-AH.COMal Trust
                                   v
+-----------------------------------------------------------------------------------+
| SAMBA 4 AD DC (DC02) - CLOUD-AH.COM                                               |
| CLOUD-AH.COMe Benutzer & globale Gruppen: G_Partner, G_Promoter, G_CLOUD-AH.COM               |
+-----------------------------------------------------------------------------------+

Interne Kette:
+------------------+     +---------------------+     +--------------------------------------+     +------------------+
| INTERN\User (A)  | --> | INTERN\G_Sekretariat| --> | INTERN\DL_Ordner_Sekretariat_Change  | --> | NTFS Change (P)  |
+------------------+     +---------------------+     +--------------------------------------+     +------------------+

CLOUD-AH.COMe Kette Partner:
+------------------+     +------------------+     +----------------------------------+     +------------------+
| CLOUD-AH.COM\User (A)  | --> | CLOUD-AH.COM\G_Partner | --> | INTERN\DL_Ordner_Partner_Change  | --> | NTFS Change (P)  |
+------------------+     +------------------+     +----------------------------------+     +------------------+

CLOUD-AH.COMe Kette Promoter:
+------------------+     +-------------------+     +-----------------------------------+     +------------------+
| CLOUD-AH.COM\User (A)  | --> | CLOUD-AH.COM\G_Promoter | --> | INTERN\DL_Ordner_Promoter_Change  | --> | NTFS Change (P)  |
+------------------+     +-------------------+     +-----------------------------------+     +------------------+
```

---

### 7.4 Praktische Umkonfiguration für zwei Abteilungen

Zur Demonstration kann die zwei Bereiche **Sekretariat** (intern, `DC1.CLOUD-AH.LOCAL`) und **Partner** (cloud-ah.com, `CLOUD-AH.COM`) gemäss AGDLP neu konfiguriert.  
Die cloud-ah.come Abteilung **Promoter** kann analog behandelt.

#### 1. Erstellung der domänenlokalen Gruppen (DL) auf `DC01`

Die domänenlokalen Gruppen werden in der Ressourcendomäne `DC1.CLOUD-AH.LOCAL` angelegt:

- `DL_Ordner_Sekretariat_Change`
- `DL_Ordner_Sekretariat_Read`
- `DL_Ordner_Partner_Change`
- `DL_Ordner_Promoter_Change`
- `DL_Ordner_Buchhaltung_Read`

```powershell
# Auf DC01 – DC1.CLOUD-AH.LOCAL
New-ADGroup -Name "DL_Ordner_Sekretariat_Change" -GroupScope DomainLocal -GroupCategory Security
New-ADGroup -Name "DL_Ordner_Sekretariat_Read"   -GroupScope DomainLocal -GroupCategory Security
New-ADGroup -Name "DL_Ordner_Partner_Change"     -GroupScope DomainLocal -GroupCategory Security
New-ADGroup -Name "DL_Ordner_Promoter_Change"    -GroupScope DomainLocal -GroupCategory Security
New-ADGroup -Name "DL_Ordner_Buchhaltung_Read"   -GroupScope DomainLocal -GroupCategory Security
```

#### 2. Zuweisung der NTFS-Berechtigungen (P)

- Ordner `C:\Daten\Abteilungen\Sekretariat`:
  - `INTERN\DL_Ordner_Sekretariat_Change` → NTFS-Berechtigung **Ändern**
  - `INTERN\DL_Ordner_Sekretariat_Read` → NTFS-Berechtigung **Lesen**
- Ordner `C:\Daten\Abteilungen\Partner`:
  - `INTERN\DL_Ordner_Partner_Change` → NTFS-Berechtigung **Ändern**
- Ordner `C:\Daten\Abteilungen\Promoter`:
  - `INTERN\DL_Ordner_Promoter_Change` → NTFS-Berechtigung **Ändern**
- Ordner `C:\Daten\Abteilungen\Buchhaltung`:
  - `INTERN\DL_Ordner_Buchhaltung_Read` → NTFS-Berechtigung **Lesen**

#### 3. Gruppen-Verschachtelung (Nesting)

- **Interne Benutzer – Sekretariat:**
  - `INTERN\G_Sekretariat` wird Mitglied von `INTERN\DL_Ordner_Sekretariat_Change`.
  - `INTERN\G_Sekretariat` wird Mitglied von `INTERN\DL_Ordner_Buchhaltung_Read`.

- **CLOUD-AH.COMe Benutzer – Partner:**
  - `CLOUD-AH.COM\G_Partner` wird Mitglied von `INTERN\DL_Ordner_Partner_Change`.
  - `CLOUD-AH.COM\G_Partner` wird Mitglied von `INTERN\DL_Ordner_Sekretariat_Read`.
  - `CLOUD-AH.COM\G_Partner` wird Mitglied von `INTERN\DL_Ordner_Buchhaltung_Read`.

- **CLOUD-AH.COMe Benutzer – Promoter:**
  - `CLOUD-AH.COM\G_Promoter` wird Mitglied von `INTERN\DL_Ordner_Promoter_Change`.
  - `CLOUD-AH.COM\G_Promoter` wird Mitglied von `INTERN\DL_Ordner_Sekretariat_Read`.
  - `CLOUD-AH.COM\G_Promoter` wird Mitglied von `INTERN\DL_Ordner_Buchhaltung_Read`.

```powershell
# Auf DC01 – DC1.CLOUD-AH.LOCAL
Add-ADGroupMember -Identity "DL_Ordner_Sekretariat_Change" -Members "INTERN\G_Sekretariat"
Add-ADGroupMember -Identity "DL_Ordner_Buchhaltung_Read"   -Members "INTERN\G_Sekretariat"

Add-ADGroupMember -Identity "DL_Ordner_Partner_Change"     -Members "CLOUD-AH.COM\G_Partner"
Add-ADGroupMember -Identity "DL_Ordner_Sekretariat_Read"   -Members "CLOUD-AH.COM\G_Partner"
Add-ADGroupMember -Identity "DL_Ordner_Buchhaltung_Read"   -Members "CLOUD-AH.COM\G_Partner"

Add-ADGroupMember -Identity "DL_Ordner_Promoter_Change"    -Members "CLOUD-AH.COM\G_Promoter"
Add-ADGroupMember -Identity "DL_Ordner_Sekretariat_Read"   -Members "CLOUD-AH.COM\G_Promoter"
Add-ADGroupMember -Identity "DL_Ordner_Buchhaltung_Read"   -Members "CLOUD-AH.COM\G_Promoter"
```

> **Hinweis:** Die globalen Gruppen `G_Sekretariat`, `G_Partner` und `G_Promoter` verbleiben in ihrer jeweiligen Domäne.  
> `G_Sekretariat` liegt in `DC1.CLOUD-AH.LOCAL`, `G_Partner` und `G_Promoter` liegen in `CLOUD-AH.COM`.  
> Die domänenlokalen Gruppen und die NTFS-Berechtigungen liegen ausschliesslich in `DC1.CLOUD-AH.LOCAL` auf `DC01`.

---

## Zusammenfassung

Durch die Trennung in eine interne Windows-Domäne (`DC1.CLOUD-AH.LOCAL`) und eine cloud-ah.come Samba-4-Domäne (`CLOUD-AH.COM`) sowie den CLOUD-AH.COMal Trust können cloud-ah.come Benutzer kontrolliert auf Freigaben von `DC01` zugreifen.  
Die NTFS-Berechtigungen auf `DC01` bleiben dabei die zentrale Steuerungsinstanz. ABE sorgt dafür, dass Benutzer nur die Ordner sehen, für die sie tatsächlich berechtigt sind.  
Mit dem AGDLP-Konzept werden direkte Cross-Domain-ACLs vermieden und die Rechtevergabe langfristig wartbar, skalierbar und auditierbar gestaltet.  
Die cloud-ah.come Hauptgruppe `CLOUD-AH.COM` enthält in `CLOUD-AH.COM` die Abteilungsgruppen `Partner` und `Promoter`.