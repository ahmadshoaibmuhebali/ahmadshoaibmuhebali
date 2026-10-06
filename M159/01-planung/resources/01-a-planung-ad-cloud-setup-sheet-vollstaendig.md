# M159 - Projekt-Setup-Sheet (ausgefüllt)

In diesem Dokument werden die konfigurierten Angaben sowie die zu verwendenden Zugangsdaten für die M159-Umgebung festgehalten. Es dient als vollständige Planungs- und Betriebsdokumentation für die Umsetzung im AWS- und Microsoft-Cloud-Kontext.

![Modul_159_Architekturdiagramm](/M159/images/nework-diagramm.svg)

---

## 1. Übersicht Umgebung

Diese Umgebung umfasst:

- 1x Windows Server (Client) auf AWS EC2
- 1x Linux-Server für Samba 4 AD auf AWS EC2
- 1x Server für Authentik als Identity Provider auf eVPS
- 2x Windows Server als Domain Controller für `dc1.cloud-ah.local`
- Samba 4 AD als separaten Verzeichnisdienst mit Kerberos und LDAP für `cloud-ah.com`
- Authentik als SSO-/OIDC-Identity-Provider für Webanwendungen
- Eine Windows-AD-Domäne und eine separate Samba-AD-Domäne

Windows AD und Samba AD sind getrennte Domänen. Eine gemeinsame Anmeldung oder
Ressourcennutzung zwischen beiden Domänen setzt eine explizit konfigurierte
Trust-Beziehung und passende DNS-Auflösung voraus.

---

## 2. Allgemeine Angaben

| Feld | Wert |
| ----- | ---- |
| Vorname | AhmadShoaib |
| Nachname | MuhebAli |
| Klasse | PE24e |
| Dokumentation (GIT-Repository-Link) | [https://github.com/ahmadshoaibmuhebali/ahmadshoaibmuhebali/tree/main/M159](https://github.com/ahmadshoaibmuhebali/ahmadshoaibmuhebali/tree/main/M159) |
| Projektname | M159 - Active Directory und Cloud-Integration |
| Verantwortlicher | AhmadShoaib MuhebAli |

---

## 3. Ressourcen

| Feld | Wert |
| ---- | ---- |
| Samba 4 AD Realm | CLOUD-AH.COM |
| Samba-Domänenname (NetBIOS) | CLOUD-AH |
| Samba Forest | cloud-ah.com |
| Samba Domain Controller FQDN | dc2.cloud-ah.com |
| Samba Domain Controller NetBIOS | DC2 |
| Windows AD-Domäne | DC1.CLOUD-AH.LOCAL |
| Windows AD LDAP-Basis-DN | DC=dc1,DC=cloud-ah,DC=local |
| Samba LDAP-Basis-DN | DC=cloud-ah,DC=com |
| UPN-/Mail-Domäne | Wird je Domäne separat festgelegt |
| Authentik URL | https://auth.cloud-ah.com |
| Authentik Admin Benutzer | akadmin |
| Authentik Admin Passwort | Wird beim Setup gesetzt |
| Samba 4 AD Admin Benutzer | Administrator |
| Samba 4 AD Admin Passwort | Wird beim Setup gesetzt |
| Authentik-Hostname | auth.cloud-ah.com |
| LDAP-Basis-DN Samba | DC=cloud-ah,DC=com |
| LDAP-Basis-DN Windows | DC=dc1,DC=cloud-ah,DC=local |

---

## 4. AWS VPC Setup

Hinweis:
Die Domain Controller liegen in einem öffentlichen Subnetz, die Client-Instanzen
in einem privaten Subnetz. Die aktuell konfigurierte RDP-Regel ist in Abschnitt 5
dokumentiert. Für den produktiven Betrieb muss RDP auf eine feste
Administrations-IP, einen VPN-Zugang oder einen Bastion Host beschränkt werden.

| Komponente | VPC-ID | CIDR | Name |
| ---------- | ------ | ---- | ---- |
| VPC | vpc-0e471f74bd9dc771d | 10.0.0.0/16 | M159-VPC |
| M159-subnet-public1-us-east-1a | subnet-pub-1a | 10.0.0.0/20 | AD-DC-Subnet |
| M159-subnet-private1-us-east-1b | subnet-priv-1b | 10.0.128.0/20 | Client-Subnet |


---

## 5. AWS Sicherheitsgruppen

### Sicherheitsgruppe für Windows AD

Security Group: `security group for windows AD` (`sg-019b02464dbe86f29`)

| Name | Security group rule ID | IP version | Type | Protocol | Port range | Source | Description |
| ---- | ---------------------- | ---------- | ---- | -------- | ---------- | ------ | ----------- |
| – | `sgr-0c6394efa78a4b180` | IPv4 | All traffic | All | All | `10.0.128.0/20` | Allow traffic only from the client subnet |
| – | `sgr-074c7838f070d3d20` | IPv4 | All traffic | All | All | `10.0.0.0/20` | Allow traffic only from the AD-DC subnet |
| – | `sgr-0bddf8e9c979d3cd2` | IPv4 | Custom TCP | TCP | 636 | `94.156.189.247/32` | Authentik eVPS LDAPS access |
| – | `sgr-00456f75a40c222e3` | IPv4 | RDP | TCP | 3389 | `0.0.0.0/0` | Currently configured; restrict to the administration IP |




### Sicherheitsgruppe für Samba 4 AD

Security Group: `samba-ad-security-group`

| Name | Security group rule ID | IP version | Type | Protocol | Port range | Source | Description |
| ---- | ---------------------- | ---------- | ---- | -------- | ---------- | ------ | ----------- |
| – | `sgr-017f2011f9c207c6b` | IPv4 | Custom TCP | TCP | 636 | `94.156.189.247/32` | Authentik eVPS LDAPS access |
| – | `sgr-06f94f52186f3d55d` | IPv4 | All traffic | All | All | `10.0.0.0/20` | Internal traffic from the AD-DC subnet |
| – | `sgr-03a88d60415d7ba0c` | IPv4 | SSH | TCP | 22 | `0.0.0.0/0` | Currently configured SSH access; restrict to the administration IP |

Die SSH-Regel ist aktuell weltweit offen. Für den produktiven Betrieb muss
Port 22 auf eine feste Administrations-IP, einen VPN-Zugang oder einen Bastion
Host beschränkt werden.


### Sicherheitsgruppe für Clients

Security Group: `Client-Sgr`

| Name | Security group rule ID | IP version | Type | Protocol | Port range | Source | Description |
| ---- | ---------------------- | ---------- | ---- | -------- | ---------- | ------ | ----------- |
| – | `sgr-095af8d77db1648d6` | IPv4 | All traffic | All | All | `10.0.0.0/20` | Internal traffic from the AD-DC subnet |
| – | `sgr-0ea6264ddb523c905` | IPv4 | HTTPS | TCP | 443 | `0.0.0.0/0` | Currently configured HTTPS access; restrict if the service is not public |
| – | `sgr-0cd29c99e7c46fd5d` | IPv4 | RDP | TCP | 3389 | `0.0.0.0/0` | Currently configured; restrict to the administration IP |


Da sich der Client in einem privaten Subnetz befindet, ist kein direkter Zugriff
aus dem Internet möglich. Deshalb wurde eine Route für den administrativen
Zugriff auf das C<slient-Subnetz konfiguriert, wie im folgenden Beispielbild
dargestellt.

![Routing Client](/M159/images/Private_Subnet_Route.png)
---

## 6. Active Directory Umgebung

### On-Premises Active Directory (AWS EC2)

| Feld | Wert |
| ---- | ---- |
| Active Directory-Domäne | dc1.cloud-ah.local |
| Windows-AD-UPN-Suffix | @dc1.cloud-ah.local, sofern kein alternativer Suffix konfiguriert ist |
| Domänenadministrator | Administrator |
| Kennwort Domänenadministrator | Wird beim Aufbau der Domain gesetzt |
| Kennwort-Demote (Herunterstufen) | Wird bei der Demotion dokumentiert |
| DNS-Server 1 | 127.0.0.1 |
| LDAP-Basis-DN | DC=dc1,DC=cloud-ah,DC=local |
| LDAP-Port |636 |
| Kerberos-Port | 88 |
| Subnetz 1 | M159-subnet-public1-us-east-1a (`10.0.0.0/20`) |

### Zweiter Domain Controller: `dc1-replica`

Der zweite Windows Server wird als zusätzlicher Domain Controller in die bestehende
Domäne `dc1.cloud-ah.local` aufgenommen. Dabei wird keine neue Gesamtstruktur und keine
neue Domäne erstellt. Die Replikation erfolgt zwischen dem bestehenden Domain Controller
`DC1` und `dc1-replica`.

| Feld | Wert |
| --- | --- |
| Hostname | `dc1-replica` |
| Rolle | Zusätzlicher Domain Controller / AD-DS-Replikat |
| Domäne | `dc1.cloud-ah.local` |
| Öffentliche IPv4-Adresse | `107.22.97.11` |
| Private IPv4-Adresse | `10.0.12.83` |
| Bevorzugter DNS-Server | Private IPv4-Adresse des bestehenden DC1: `10.0.9.193` |
| LDAP-Basis-DN | `DC=dc1,DC=cloud-ah,DC=local` |
| AWS-Netzwerk | AD-DC-Subnetz `10.0.0.0/20` |

Vor der Heraufstufung wird als DNS-Server die private Adresse des bestehenden Domain
Controllers (`10.0.9.193`) eingetragen. Nach erfolgreicher Heraufstufung kann der Server
zusätzlich sich selbst beziehungsweise den bestehenden DC als alternativen DNS-Server
verwenden. Die DNS-Auflösung muss weiterhin auf die AD-integrierte DNS-Zone zeigen.



### Authentik Identity Provider

| Feld | Wert |
| ---- | ---- |
| Authentik Domain | auth.cloud-ah.com |
| Authentik Admin Benutzer | akadmin |
| Authentik Admin Passwort | Wird sicher im Setup gesetzt; nicht in Git dokumentieren |
| Authentik Version | Latest stable |
| OIDC Provider | Authentik |
| Gruppen- und User-Federation | Samba 4 AD via LDAPS|
| SSO-Flow | OIDC / OAuth2 / OpenID Connect |
| App-Integration | Portainer mit Login über Authentik |

### Samba 4 AD

| Feld | Wert |
| ---- | ---- |
| Active Directory Realm | CLOUD-AH.COM |
| Kerberos Realm | CLOUD-AH.COM |
| NetBIOS-Domainname | CLOUD-AH |
| Samba 4 Domain Controller | dc2.cloud-ah.com |
| Samba 4 Domain Controller NetBIOS | DC2 |
| Samba 4 Admin User | Administrator |
| Samba 4 Admin Passwort | Wird beim Setup gesetzt |
| DNS-Server 1 | 127.0.0.1 |
| LDAP-Basis-DN | DC=cloud-ah,DC=com |
| LDAP-Port |636 |
| Kerberos-Port | 88 |
| Subnetz 1 | M159-subnet-public1-us-east-1a (`10.0.0.0/20`) |

---


> Hinweis: Die Elastic-IPs und IP-Adressen werden bei der tatsächlichen Erstellung der EC2-Instanzen mit den AWS-Angaben abgeglichen und dokumentiert.

---

## 7. Abteilungen & Benutzer

Definiert wurden je ein Benutzer für die folgenden 3 Abteilungen sowie ein externer Bereich.

| Abteilung | Name der Abteilung | Benutzername | Vorname | Nachname | Kennwort | Bereiche |
| --------- | ------------------ | ------------ | ------- | -------- | -------- | -------- |
| 1 | Sekretariat | sekretaer1 | Anna | Meier | Wird beim Aufbau gesetzt | intern |
| 2 | Buchhaltung | buchhaltung1 | Lukas | Weber | Wird beim Aufbau gesetzt | intern |
| 3 | GL | geschaeftsleitung1 | Sara | Mueller | Wird beim Aufbau gesetzt | intern |
| 4 | Promoter | promoter1 | Daniel | Brandt | Wird beim Aufbau gesetzt | extern |

### Beispielhafte Benutzer-Attribute

- Sekretariat: `sekretaer1` / `Anna.Meier`
- Buchhaltung: `buchhaltung1` / `Lukas.Weber`
- GL: `geschaeftsleitung1` / `Sara.Mueller`
- Promoter: `promoter1` / `Daniel.Brandt`

---

## 9. Portainer-App-Registration (Authentik / OIDC)

| Name | Wert |
| ---- | ---- |
| Authentik Issuer URL | https://auth.cloud-ah.com/application/o/portainer/ |
| Client ID | Wird nach Erstellung der Authentik-Application dokumentiert |
| Client Secret | Wird nach Erstellung des Secrets dokumentiert |
| Redirect URI | https://portainer.cloud-ah.com/oauth/callback |
| Provider Type | OpenID Connect |
| App Name | Portainer |
| Gruppen- oder Scope-Zuordnung | users, admins |
| Signin-Flow | Authentik login page |

---
