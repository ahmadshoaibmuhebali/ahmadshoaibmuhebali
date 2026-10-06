# Dokumentation: LDAP-Anbindung Firewall & VPN-Berechtigung

## Teil 1 – Bind und Base-DN

Die Umgebung enthält zwei getrennte Active-Directory-Domänen. Interne Benutzer
werden im Windows AD `dc1.cloud-ah.local` gesucht; der Benutzerbereich
`Promoter` liegt im separaten AD `cloud-ah.com`. Eine Vertrauensstellung verbindet
die Domänen, führt ihre LDAP-Verzeichnisse aber nicht zu einem gemeinsamen
Namensraum zusammen.

* **Base-DN und Herleitung:**
  * **Base-DN:** `DC=dc1,DC=cloud-ah,DC=local`
  * **Herleitung:** Der Base-DN leitet sich direkt aus dem Fully Qualified Domain Name (FQDN) `dc1.cloud-ah.local` ab. Jedes durch einen Punkt getrennte Namenselement wird als Domain Component (`DC=`) abgebildet.
* **Erklärung des Bind-Vorgangs:**
  * Der LDAP-Bind authentifiziert den Client gegenüber dem Active Directory Server. Er etabliert den Sicherheitskontext für nachfolgende Abfragen.
  * *Ohne Bind:* Das Active Directory lehnt anonyme Abfragen standardmässig ab (`NTDS\Parameters`). Abfrageversuche ohne Bind werden mit einem Sicherheitsfehler abgebrochen.
* **Vollständiger Distinguished Name (DN) eines Promoters:**
  * `CN=Max Muster,OU=Benutzer,OU=Promoter,OU=Extern,DC=cloud-ah,DC=com`
  * **LDAP-Suchbasis:** `DC=cloud-ah,DC=com` am LDAP-Server des AD `cloud-ah.com`

---

## Teil 2 – Drei Suchen zum Aufwärmen

| Suche | Filter | Base-DN / Scope | Trefferzahl |
| :--- | :--- | :--- | :--- |
| **2.1 Promoter via Login** | `(sAMAccountName=m.muster)` | `DC=cloud-ah,DC=com` im separaten AD `cloud-ah.com` (Subtree) | 1 |
| **2.2 Buchhaltung (OneLevel)** | `(&(objectCategory=person)(objectClass=user))` | `OU=Buchhaltung,OU=Intern,DC=dc1,DC=cloud-ah,DC=local` (OneLevel) | **0** |
| **2.2 Buchhaltung (Subtree)** | `(&(objectCategory=person)(objectClass=user))` | `OU=Buchhaltung,OU=Intern,DC=dc1,DC=cloud-ah,DC=local` (Subtree) | 3 |
| **2.3 Alle Gruppen** | `(objectClass=group)` | `DC=dc1,DC=cloud-ah,DC=local` (Subtree) | 8 |

* **DN der Gruppe `extern`:** `CN=extern,OU=Extern,DC=cloud-ah,DC=com`
* **Erklärung Scope (OneLevel vs. Subtree):**
  * `OneLevel` durchsucht ausschliesslich die oberste Hierarchieebene des angegebenen Ordners (`OU=Buchhaltung,OU=Intern,DC=dc1,DC=cloud-ah,DC=local`). Da Benutzerkonten gemäss DIT-Struktur in einer untergeordneten OU (`OU=Benutzer`) abgelegt sind, liefert `OneLevel` null Treffer.
  * `Subtree` durchsucht die Ziel-OU inklusive aller untergeordneten Ebenen (inkl. `OU=Benutzer`) rekursiv und findet die Konten.

---

## Teil 3 – Der Filter für die Firewall

Die folgenden Promoter-Filter werden gegen den LDAP-Endpunkt des separaten AD
`cloud-ah.com` ausgeführt. Sie dürfen nicht mit dem Windows-AD-Base-DN
`DC=dc1,DC=cloud-ah,DC=local` kombiniert werden. Die Gruppen-DNs müssen zur
tatsächlichen DIT-Struktur im AD `cloud-ah.com` passen.

* **3.1 Direkte Mitglieder der Gruppe Promoter:**
  * **Filter:** `(&(objectCategory=person)(objectClass=user)(memberOf=CN=Promoter,OU=Gruppen,OU=Extern,DC=cloud-ah,DC=com))`
  * **Trefferzahl:** 5
* **3.2 Naiver vs. Korrigierter Filter für Gruppe `extern`:**
  * **Naiver Filter:** `(&(objectCategory=person)(objectClass=user)(memberOf=CN=extern,OU=Gruppen,OU=Extern,DC=cloud-ah,DC=com))`
  * **Trefferzahl Naiv:** **0** *(Grund: Benutzer sind Mitglied der Gruppe `Promoter`, und erst `Promoter` ist Mitglied von `extern`)*
  * **Korrigierter Filter (mit Extension OID `1.2.840.113556.1.4.1941`):**
    `(&(objectCategory=person)(objectClass=user)(memberOf:1.2.840.113556.1.4.1941:=CN=extern,OU=Gruppen,OU=Extern,DC=cloud-ah,DC=com))`
  * **Trefferzahl Korrigiert:** 5
* **3.3 Finale Firewall-Abfrage (Nur aktive Konten via OID `1.2.840.113556.1.4.803`):**
  * **Filter:** `(&(objectCategory=person)(objectClass=user)(memberOf:1.2.840.113556.1.4.1941:=CN=extern,OU=Gruppen,OU=Extern,DC=cloud-ah,DC=com)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))`
  * **Trefferzahl:** 4 *(Ein Konto ist deaktiviert)*

**Nachweis der Testfälle:**
1. **Test 1 (Promoter deaktivieren):** Nach Deaktivierung von `m.muster` sinkt die Trefferzahl im Filter 3.3 sofort von 4 auf 3.
2. **Test 2 (Erweiterung Externe Berater):** Gruppe `Externe Berater` angelegt, in `extern` verschachtelt und Testbenutzer hinzugefügt. Der Filter liefert den neuen Benutzer automatisch (Trefferzahl steigt auf 4), ohne dass die Konfiguration angepasst werden muss.

**Begründung für Filter auf `extern` statt `Promoter`:**
Durch den Filter auf die übergeordnete Gruppe `extern` unter der OU `Extern` in Kombination mit der Regelauswertung `LDAP_MATCHING_RULE_IN_CHAIN` bleibt die Firewall-Konfiguration vollständig wartungsfrei. Wenn neue externe Abteilungen dazukommen, werden diese im AD `cloud-ah.com` unter `extern` eingegliedert, ohne dass administrative Eingriffe an den Firewall-Einstellungen erforderlich sind.

---

## Teil 4 – Den Filter wirksam machen (GPO Item-Level Targeting)

* **GPO-Konfiguration:** In der GPO `GPO_Desktop_Promoter` wurde ein Preference-Shortcut angelegt.
* **Zielgruppenadressierung:** Der Filter aus Step 3.3 muss gegen den LDAP-Server des AD `cloud-ah.com` gebunden werden. Ein Binding gegen `LDAP://dc1.cloud-ah.local` sucht nur im Windows AD und findet den Promoter nicht. Ob das GPO-Item-Level-Targeting einen LDAP-Endpunkt der zweiten Domäne direkt abfragen kann, muss in der konkreten Windows-Umgebung geprüft werden; die Vertrauensstellung allein erweitert die lokale LDAP-Suche nicht.

**Nachweis der Wirksamkeit (`gpresult /r`):**
* **Test Client Promoter (`m.muster`):**
  * Resultat: Die Option **Item-Level Targeting** evaluiert zu `TRUE`. Die Verknüpfung "VPN-Anleitung.url" wird auf dem Desktop erstellt.
* **Test Client Interner Benutzer (`b.buchhalter` aus `OU=Buchhaltung,OU=Intern`):**
  * Resultat: Die Option **Item-Level Targeting** evaluiert zu `FALSE`. Die GPO-Einstellung wird übersprungen; der Link wird nicht angelegt.

---

## Teil 5 – Konfigurationsblatt der Firewall

| Feldname | Wert | Begründung |
| :--- | :--- | :--- |
| **Base DN** | `DC=cloud-ah,DC=com` | Root-Suchknoten des separaten AD `cloud-ah.com` für Promoter und die Gruppe `extern`. |
| **Bind DN** | `CN=svc-vpn,OU=ServiceAccounts,DC=cloud-ah,DC=com` | Spezielles Dienstkonto im AD `cloud-ah.com` für das Read-Only Auslesen von Directory-Attributen. |
| **Bind Password** | `[SicheresPasswort123!]` | Passwort zur Authentifizierung des Dienstkontos am LDAP-Server. |
| **LDAP-Server / Base DN** | LDAP-Server des AD `cloud-ah.com` / `DC=cloud-ah,DC=com` | Promoter und die Gruppe `extern` liegen im separaten AD `cloud-ah.com`. |
| **Search Filter** | `(&(objectCategory=person)(objectClass=user)(memberOf:1.2.840.113556.1.4.1941:=CN=extern,OU=Gruppen,OU=Extern,DC=cloud-ah,DC=com)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))` | Dynamischer Filter zur Auswertung verschachtelter Mitgliedschaften im AD `cloud-ah.com` unter Ausschluss deaktivierter Konten. |
| **Port / Protocol** | `636 / LDAPS` | Transportverschlüsselung via TLS zum Schutz der Authentifizierungsdaten. |

**Begründung Dienstkonto:**
Es wird ein dezidiertes Dienstkonto (`svc-vpn`) ohne administrative Rechte genutzt. Da im Active Directory jedes authentifizierte Domänenkonto standardmässig Leserechte auf allgemeine Attribute (`memberOf`, `userAccountControl`) besitzt, benötigt das Konto keine erweiterten Berechtigungen (Principle of Least Privilege).

**Begründung Port 636 vs. 389:**
Bei Port 389 (LDAP Standard) werden die Anmeldedaten des Dienstkontos sowie die User-Credentials beim Bind im Klartext über das Netzwerk übertragen und könnten abgehört werden. Port 636 (LDAPS) erzwingt TLS-Verschlüsselung, wodurch Anmeldeinformationen und Abfrageergebnisse abhörsicher geschützt sind.

---

## ki-log.md

| Datum | KI-Tool | Prompts / Fragestellung | Nutzen / Output | Wie verifiziert | Reflexion |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 17.09.2026 | Gemini | "Erkläre mir das Prinzip verschachtelter LDAP-Mitgliedschaften." | OID `1.2.840.113556.1.4.1941` erklärt bekommen. | Abfrage in `PowerShell` ausgeführt (Treffer stieg von 0 auf 5). | KI half beim Verständnis der OID-Syntax, die mathematische Validierung erfolgte am DC. |
| 17.09.2026 | Gemini | "Wie formuliert man Bitwise-Operatoren für Disabled Accounts?" | Erklärung für Bit 2 (`ACCOUNTDISABLE`) und OID `1.2.840.113556.1.4.803`. | Konto deaktiviert und Abfrage in `ldp.exe` geprüft (Konto verschwand). | Exakte Bitmasken-Syntax direkt am Directory verifiziert. |