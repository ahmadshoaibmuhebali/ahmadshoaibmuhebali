# Variante B: Zweiter Domain Controller und Replikation

## Teil A: Zweiten Domain Controller aufbauen

### 1. Ziel und Ausgangslage

Für die bestehende Windows-AD-Domäne `dc1.cloud-ah.local` wird ein zweiter Windows-
Server als Replikat aufgebaut. Der neue Server heisst `dc1-replica`. Er wird der bereits
vorhandenen Domäne als zusätzlicher Domain Controller hinzugefügt.

Dabei wird **keine neue Gesamtstruktur** und keine zusätzliche Domäne erstellt. Beide
Domain Controller gehören danach zur gleichen Domäne und replizieren die Active-Directory-
und DNS-Daten miteinander.

### 2. Netzwerk- und DNS-Konfiguration

| Einstellung | Wert |
| --- | --- |
| Hostname | `dc1-replica` |
| Domäne | `dc1.cloud-ah.local` |
| Öffentliche IPv4-Adresse | `107.22.97.11` |
| Private IPv4-Adresse | `10.0.12.83` |
| DNS-Server vor der Heraufstufung | `10.0.9.193` (private IP des bestehenden DC1) |
| LDAP-Basis-DN | `DC=dc1,DC=cloud-ah,DC=local` |
| AWS-Subnetz | AD-DC-Subnetz `10.0.0.0/20` |

Die private IP-Adresse wird für die Kommunikation innerhalb der AWS-VPC, für die
Domänenaufnahme und für die AD-Replikation verwendet. Die öffentliche Adresse dient nur
dem administrativen Zugriff gemäss der konfigurierten AWS-Sicherheitsgruppe. Für den
produktiven Betrieb soll RDP nicht weltweit offen sein, sondern auf eine feste
Administrations-IP, einen VPN-Zugang oder einen Bastion Host beschränkt werden.

### 3. Voraussetzungen

1. Die Windows-Server-Instanz mit dem Hostnamen `dc1-replica` ist bereitgestellt.
2. Die statische private IP-Adresse `10.0.12.83` ist konfiguriert.
3. Als DNS-Server ist vor der Domänenaufnahme die private IP des bestehenden DC1
   (`10.0.9.193`) eingetragen.
4. Die Uhrzeit des neuen Servers und des bestehenden Domain Controllers ist synchronisiert.
5. Der neue Server kann den bestehenden DC über die erforderlichen AD-, DNS-, LDAP- und
   Kerberos-Verbindungen erreichen.
6. Ein Domänenkonto mit ausreichenden Berechtigungen für die Heraufstufung steht bereit.

### 4. Server der bestehenden Domäne hinzufügen

Auf `dc1-replica` wird zunächst die Active-Directory-Domänendienste-Rolle installiert.
Danach wird der Server der bestehenden Domäne `dc1.cloud-ah.local` hinzugefügt und als
zusätzlicher Domain Controller heraufgestuft.

Beispiel mit PowerShell:

```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

Install-ADDSDomainController `
    -DomainName "dc1.cloud-ah.local" `
    -InstallDns `
    -Credential (Get-Credential) `
    -NoGlobalCatalog:$false
```

Der Assistent beziehungsweise der PowerShell-Befehl verwendet die bestehende Domäne.
Es darf an dieser Stelle nicht `Install-ADDSForest` verwendet werden, weil damit eine
neue Gesamtstruktur erstellt würde.

Nach dem Neustart wird kontrolliert, dass `dc1-replica` als Domain Controller der Domäne
angehört und die DNS-Rolle installiert ist.

### 5. Prüfung in Active Directory Users and Computers

1. `dsa.msc` auf dem bestehenden DC oder auf `dc1-replica` öffnen.
2. Die Domäne `dc1.cloud-ah.local` auswählen.
3. Unter **Domain Controllers** prüfen, ob `DC1` und `dc1-replica` sichtbar sind.
4. Die Eigenschaften von `dc1-replica` öffnen und kontrollieren, dass der Server als
   Domain Controller der bestehenden Domäne eingetragen ist.

Erwartetes Ergebnis:

![DC1-Replika in Active Directory Users and Computers](/M159/images/dc1-replica-user-and-groups.png)

### 6. Prüfung in der DNS-Konsole

1. `dnsmgmt.msc` öffnen.
2. Die Forward-Lookupzone `dc1.cloud-ah.local` öffnen.
3. Prüfen, ob für `dc1-replica` ein Hosteintrag mit der privaten IP `10.0.12.83`
   vorhanden ist.
4. Die AD-bezogenen SRV-Einträge kontrollieren, insbesondere die Einträge für LDAP und
   Kerberos.
5. Falls eine Reverse-Lookupzone eingerichtet ist, auch den PTR-Eintrag für
   `10.0.12.83` prüfen.

![DC1-Replika-DNS](/M159/images/dc1-replica-dns.png)

## Teil B: Replikationsstatus und FSMO-Rollen

Die folgenden Befehle wurden auf dem Domain Controller ausgeführt. Die Ausgaben sind im
Ordner [Test-Results](Test-Results) gespeichert:

```powershell
repadmin /replsummary
repadmin /showrepl
netdom query fsmo
```

`repadmin /replsummary` weist für `DC01` und `DC1-REPLICA` jeweils `0 / 5` Fehler aus.
Damit ist in diesem Test keine fehlgeschlagene Replikation festgestellt worden.
`repadmin /showrepl` weist für die eingehenden Namenskontexte erfolgreiche Verbindungen
von `DC01` zu `DC1-REPLICA` aus. Die Namen sind in Windows nicht
gross-/kleinschreibungsempfindlich; `DC1-REPLICA` entspricht dem dokumentierten Hostnamen
`dc1-replica`.

Die fünf FSMO-Rollen liegen gemäss [query_fsmo.txt](Test-Results/query_fsmo.txt) auf
`DC01.dc1.cloud-ah.local`.

### Namenskontext

Ein Namenskontext ist ein logisch zusammengehöriger Bereich im Active Directory, der als
Einheit repliziert wird. In der Ausgabe von `repadmin /showrepl` sind dies unter anderem:

- `DC=dc1,DC=cloud-ah,DC=local` für die Domänenpartition
- `CN=Configuration,DC=dc1,DC=cloud-ah,DC=local` für die Konfiguration
- `CN=Schema,CN=Configuration,DC=dc1,DC=cloud-ah,DC=local` für das Schema
- `DC=DomainDnsZones,DC=dc1,DC=cloud-ah,DC=local` und `DC=ForestDnsZones,DC=dc1,DC=cloud-ah,DC=local` für die DNS-Partitionen

## Teil C: Replikation in beide Richtungen

Für den Funktionstest wurde ein eindeutig benannter Benutzer auf `DC1` erstellt und auf
`dc1-replica` kontrolliert. Anschliessend wurde ein Attribut auf dem Replikat geändert und
die Replikation mit folgendem Befehl angestossen:

```powershell
repadmin /syncall /AdeP
```

Die Änderung war nach ungefähr zehn Sekunden auch auf `DC1` sichtbar. Die genaue Zeit ist
als Erfahrungswert dokumentiert; für einen reproduzierbaren Nachweis sollten die beiden
Zeitpunkte zusätzlich mit Uhrzeit und einem Screenshot festgehalten werden.

## Teil D: Ausfalltest

Der Ausfalltest muss dokumentieren, ob der Client bei einem Ausfall von `DC1` weiterhin
einen Anmeldeserver und DNS-Auflösung verwenden kann. Die folgende Tabelle ist mit den
tatsächlichen Testergebnissen zu ergänzen:

1. Fahren Sie DC1 kontrolliert herunter.
2. Melden Sie sich am Client mit einem Domänenbenutzer an.
3. Prüfen Sie mit `nltest /dsgetdc:<ihre-domain>` oder `echo %LOGONSERVER%`, welcher DC die Anmeldung übernimmt.
4. Starten Sie DC1 wieder und prüfen Sie erneut die Replikation.

### Ergebnis

Nach dem Herunterfahren von DC1 wurde auf dem Client eine Anmeldung mit einem
Domänenbenutzer versucht. Die Anmeldung war nicht erfolgreich. Es erschien folgende
Meldung:

> We can't sign you in with these credentials because your domain isn't available. Make sure your device is connected to your organization's network and try again. If you previously signed in on the device with other credentials, you can sign in with those credentials.

Der Ausfalltest ist damit fehlgeschlagen. Es konnte nicht nachgewiesen werden, dass der
Client bei einem Ausfall von DC1 automatisch `dc1-replica` als Anmeldeserver verwendet.
Als mögliche Ursachen sind eine fehlende DNS-Konfiguration auf dem Client, eine fehlende
Netzwerkverbindung zum privaten AD-Subnetz oder eine nicht erreichbare AD-/DNS-Rolle auf
`dc1-replica` zu prüfen. Ein zuvor zwischengespeicherter Domänenlogin kann unabhängig
davon noch funktionieren; dieser Test belegt jedoch keinen erfolgreichen Failover.

![Fehlgeschlagener Client-Verbindungstest](/M159/images/Replica-Client-Connection-Test.png)

### Nachkontrolle und Lösung

Der Ausfall wurde durch die DNS-Konfiguration des Clients verursacht. Als der DNS-Server
von `dc1-replica` in der Client-Konfiguration ergänzt wurde, konnte sich der
Domänenbenutzer am Client anmelden. Damit war der Failover nach der Korrektur der
Client-DNS-Konfiguration erfolgreich.

![Erfolgreicher Client-Verbindungstest](/M159/images/Client-Connection-Test-Posetive.png)


## Teil E: Entscheid zur Verteilung auf zwei Domain Controller

### FSMO-Rollen

Die fünf FSMO-Rollen bleiben vorerst auf `DC01`, weil die vorhandenen Testergebnisse dies
bestätigen und die Umgebung überschaubar ist. Bei einem Ausfall von `DC01` bleiben normale
AD-Anmeldungen und die Replikation grundsätzlich möglich, sofern `dc1-replica` als DNS-
und Global-Catalog-Server verfügbar ist. Einige Vorgänge sind jedoch eingeschränkt:

- Die PDC-Emulator-Rolle ist für Zeitdienst, Kennwortänderungen und bestimmte
   Authentifizierungsabläufe besonders wichtig.
- RID-Master und Infrastrukturmaster werden vor allem beim Erstellen neuer Objekte oder
   bei bestimmten domänenübergreifenden Vorgängen benötigt.
- Schema-Master und Domain-Naming-Master werden nur bei Änderungen an Schema oder
   Domänenstruktur benötigt.

Bei einem länger dauernden Ausfall wird eine geplante Übertragung oder, falls `DC01` nicht
mehr erreichbar ist, eine kontrollierte Übernahme der Rollen geprüft. Eine Übernahme darf
nicht durchgeführt werden, solange der ursprüngliche Rolleninhaber noch unkontrolliert
zurückkehren könnte.

### Global Catalog

`dc1-replica` soll ebenfalls Global Catalog sein. Der Befehl `repadmin /showrepl` weist mit
`DSA Options: IS_GC` bereits darauf hin, dass das Replikat als Global Catalog konfiguriert
ist. Das verbessert die Verfügbarkeit von Anmeldungen und globalen Verzeichnisabfragen
bei einem Ausfall von `DC01`. Der Nachteil ist ein höherer Speicher- und
Replikationsaufwand, der in dieser kleinen Umgebung vertretbar ist.

### DNS

Auch `dc1-replica` soll die DNS-Rolle tragen, weil Active Directory DNS für die Suche nach
Domain Controllern und den AD-Diensten benötigt. Clients sollen nicht nur den ersten DC,
sondern beide internen DNS-Server verwenden:

1. bevorzugter DNS-Server: private IP von `DC1` (`10.0.9.193`)
2. alternativer DNS-Server: private IP von `dc1-replica` (`10.0.12.83`)

Die Clients dürfen für die Domänenauflösung nicht auf öffentliche DNS-Server wie `8.8.8.8`
ausweichen, weil diese die interne Zone `dc1.cloud-ah.local` nicht kennen.
