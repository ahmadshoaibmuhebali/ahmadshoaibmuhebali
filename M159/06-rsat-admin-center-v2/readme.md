# RSAT Tools + Admin Center V2 (WAC)


## Zielsetzung

Auf dem Windows-Client **WIN** wurden die **Remote Server Administration Tools (RSAT)** und das **Windows Admin Center (WAC)** installiert. Damit können Windows-Server und die Active-Directory-Umgebung zentral verwaltet werden.

Das Windows Admin Center ist über den DNS-Namen `rsat.cloud-ah.com` erreichbar. Für diesen Namen wurde beim DNS-Provider Hostinger ein A-Record auf die öffentliche IP-Adresse des Admin-Center-Systems eingerichtet.

> [!WARNING]
> Ein öffentlich erreichbares Admin-Portal ist ein sensibles Ziel. Der Zugriff sollte möglichst über VPN oder eine erlaubte Quell-IP eingeschränkt werden. Eine direkte Freigabe für `0.0.0.0/0` ist zu vermeiden. Weil es hier nur um die Testumgebung geht, ist es in Ordnung.

## Verwendete Komponenten

| Komponente | Zweck |
| --- | --- |
| RSAT | Verwaltung von Active Directory, DNS und Gruppenrichtlinien über Windows-Konsolen |
| Windows Admin Center | Webbasierte Verwaltung von Windows-Servern |
| DC01 | Windows-Domänencontroller der Domäne `dc1.cloud-ah.local` |
| WIN | Windows-Client für RSAT und Windows Admin Center |
| `rsat.cloud-ah.com` | DNS-Name für den Zugriff auf das Windows Admin Center |

## RSAT installieren

RSAT wird auf dem Windows-Client installiert, damit die Verwaltungswerkzeuge lokal zur Verfügung stehen. Die Installation kann in einer PowerShell-Sitzung mit Administratorrechten erfolgen:

```powershell
Get-WindowsCapability -Online -Name RSAT* | Add-WindowsCapability -Online
```

Anschliessend stehen unter anderem folgende Verwaltungskonsolen zur Verfügung:

| Befehl | Verwaltung |
| --- | --- |
| `dsa.msc` | Active-Directory-Benutzer und -Computer |
| `gpmc.msc` | Gruppenrichtlinienverwaltung |
| `dnsmgmt.msc` | DNS-Verwaltung |
| `dsac.exe` | Active Directory Administrative Center |
| `servermanager.exe` | Serververwaltung |

Die Verbindung zu den Domänendiensten funktioniert nur zuverlässig, wenn der Client den internen DNS-Server der Domäne verwendet und die erforderlichen Netzwerkverbindungen zu **DC01** erlaubt sind.

## Windows Admin Center installieren

Das Windows Admin Center wurde auf dem Client **WIN** installiert. Nach der Installation wird der Dienst lokal betrieben und stellt die Weboberfläche über HTTPS bereit.

Falls das Installationsprogramm auf einem Windows-Server bereits vorhanden ist, kann es mit PowerShell gesucht werden:

```powershell
Get-ChildItem -Path C:\ -Filter *AdminCenter*.exe -Recurse -ErrorAction SilentlyContinue
```

Bei der Installation sind insbesondere folgende Einstellungen relevant:

1. Installation des Windows Admin Center als Gateway.
2. Verwendung von HTTPS für die Weboberfläche.
3. Festlegung eines Administratorkontos für die lokale Anmeldung.
4. Auswahl eines gültigen Zertifikats für den verwendeten DNS-Namen.
5. Freigabe des HTTPS-Ports nur für berechtigte Quellnetze.

## Active-Directory-Erweiterung

Im Windows Admin Center wurde die **Active Directory-Erweiterung** installiert. Dadurch können Active-Directory-Funktionen für den Windows-Domänencontroller **DC01** innerhalb der Weboberfläche verwaltet werden.

Für die Verbindung wird der Windows-Server als Serververbindung im Windows Admin Center hinzugefügt. Dabei müssen der DNS-Name des Servers, ein berechtigtes Windows-Konto und eine funktionierende WinRM-Verbindung verwendet werden.

## WinRM-Verbindung zu DC01

Das Windows Admin Center verwendet **Windows Remote Management (WinRM)** für die Verwaltung des Zielservers. Auf **DC01** muss WinRM aktiviert und in der Windows-Firewall erlaubt sein:

```powershell
Enable-PSRemoting -Force
```

Für WinRM sind je nach Konfiguration folgende Ports relevant:

| Port | Protokoll | Verwendung |
| --- | --- | --- |
| 5985 | TCP | WinRM über HTTP |
| 5986 | TCP | WinRM über HTTPS |

Die Sicherheitsgruppe und die Windows-Firewall sollten den Zugriff ausschliesslich vom Admin-Center-System oder vom internen Verwaltungsnetz erlauben. Nach der Konfiguration kann die Verbindung mit folgendem Befehl getestet werden:

```powershell
Test-WSMan -ComputerName DC01
```

## DNS und externer Zugriff

Für `rsat.cloud-ah.com` wurde ein A-Record beim DNS-Provider Hostinger eingerichtet. Der Record zeigt auf die öffentliche IP-Adresse, unter der das Windows Admin Center erreichbar ist.

Für einen produktiven Betrieb sollten zusätzlich folgende Punkte umgesetzt werden:

- HTTPS-Zertifikat für `rsat.cloud-ah.com` verwenden.
- HTTP-Zugriff deaktivieren oder auf HTTPS umleiten.
- Zugriff über eine VPN-Verbindung oder eine IP-Allowlist einschränken.
- Nur den benötigten HTTPS-Port veröffentlichen.
- Administrative Konten mit starken, individuellen Kennwörtern und möglichst MFA schützen.
- Zugriffs- und Anmeldeprotokolle regelmässig prüfen.
- Das Windows Admin Center und das Betriebssystem aktuell halten.

Die öffentliche DNS-Auflösung allein ermöglicht noch keinen Zugriff. Zusätzlich müssen Routing, Sicherheitsgruppen, Firewallregeln, Zertifikat und Authentifizierung korrekt eingerichtet sein.

## Samba-4-Active-Directory

Das Windows Admin Center wurde für die Verwaltung von Windows-Servern entwickelt. In dieser Umgebung kann der Samba-4-Domänencontroller daher nicht als gleichwertiger Windows-Server im Windows Admin Center verwaltet werden.

Samba 4 wird stattdessen mit den dafür vorgesehenen Linux- und Samba-Werkzeugen verwaltet, zum Beispiel:

```bash
samba-tool domain level show
samba-tool user list
samba-tool group list
```

RSAT kann je nach Konfiguration einzelne LDAP-, DNS- oder Active-Directory-Funktionen eines Samba-Controllers erreichen. Das ersetzt jedoch nicht die vollständige native Verwaltung mit Samba-Werkzeugen, und die unterstützten Funktionen können von einer Windows-AD-Umgebung abweichen.

## Ergebnis

RSAT und Windows Admin Center wurden auf **WIN** eingerichtet. Der Windows-Domänencontroller **DC01** kann über die Active-Directory-Erweiterung und WinRM verwaltet werden. Der externe Zugriff erfolgt über `rsat.cloud-ah.com` und muss durch HTTPS sowie geeignete Netzwerk- und Zugriffsbeschränkungen abgesichert werden. Der Samba-4-Domänencontroller wird getrennt mit Samba-Werkzeugen administriert.

![RSAT-Admin-Join](/images/RSAT-Amin-Join.png)
![RSAT-DC01](/images/RSAT-DC01.png)