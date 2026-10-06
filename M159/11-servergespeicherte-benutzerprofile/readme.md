# 11 Servergespeicherte Profile

## FSLogix

### 1. Was ist FSLogix?

FSLogix ist eine Microsoft-Technologie zur Bereitstellung von Benutzerprofilen in
virtuellen und physischen Windows-Umgebungen. Statt die Profildaten bei jeder Anmeldung
vollständig auf den Client zu kopieren, speichert FSLogix das Profil in einem virtuellen
Container. Dieser Container liegt als VHD oder VHDX auf einer zentralen SMB-Freigabe und
wird bei der Anmeldung dynamisch eingebunden.

Für die Benutzer wirkt das Profil wie ein lokales Windows-Profil. Desktop, Dokumente,
Anwendungsdaten und weitere Profildaten bleiben dabei auf dem zentralen Speicher erhalten.
Bei der Abmeldung wird der Container geschlossen und die Änderungen werden gespeichert.

### 2. Vorteile und Grenzen

**Vorteile:**

- Schnelle Anmeldung, da nicht bei jeder Anmeldung ein vollständiges Roaming-Profil kopiert wird.
- Einheitliche Benutzerumgebung bei der Anmeldung an mehreren Domänen-Clients.
- Zentrale Sicherung und Administration der Profilcontainer.
- Gute Eignung für RDS-, VDI- und Mehrbenutzerumgebungen.

**Grenzen:**

- Der zentrale Dateiserver und die SMB-Freigabe müssen erreichbar sein.
- Ein Profilcontainer sollte nicht gleichzeitig von mehreren Sitzungen beschreibend geöffnet werden.
- Die Freigabe benötigt ausreichend Speicherplatz und muss in die Datensicherung einbezogen werden.
- FSLogix ersetzt kein Backup- und Wiederherstellungskonzept.

### 3. Architektur in dieser Umgebung

| Komponente | Konfiguration |
| :--- | :--- |
| Profilserver | `DC01` |
| Profilfreigabe | `\\DC01\FSLogixProfiles$` |
| GPO | `GPO_FXLogix` |
| Profilformat | VHD/VHDX pro Benutzer |
| Zugriff | Domänenbenutzer über SMB und NTFS-Berechtigungen |

Der Freigabename endet mit `$`. Dadurch wird die Freigabe bei einer normalen
Netzwerkumgebung nicht automatisch aufgelistet. Sie bleibt trotzdem über den UNC-Pfad
erreichbar.

### 4. Voraussetzungen

- Active-Directory-Domäne und funktionierende DNS-Auflösung.
- Windows-Client, der Mitglied der Domäne ist.
- Installierte und passende FSLogix-App-Version auf dem Client.
- Erreichbarer Server `DC01` über SMB, normalerweise TCP-Port 445.
- Ausreichender Speicherplatz auf dem Datenträger von `DC01`.
- Benutzer mit einer gültigen Domänenanmeldung.
- Eine GPO-Verknüpfung mit der OU, in der sich die betroffenen Computer oder Benutzer befinden.

### 5. Freigabe und Berechtigungen

Die Freigabe `FSLogixProfiles$` wird auf `DC01` angelegt. Für den Zugriff müssen sowohl
die SMB-Freigabeberechtigungen als auch die NTFS-Berechtigungen korrekt gesetzt sein.
Die restriktiveren effektiven Berechtigungen aus beiden Ebenen gelten.

Empfohlene Grundstruktur auf dem Profilordner:

| Identität | NTFS-Berechtigung | Geltungsbereich |
| :--- | :--- | :--- |
| `SYSTEM` | Vollzugriff | Dieser Ordner, Unterordner und Dateien |
| Lokale Administratoren / Domänen-Admins | Vollzugriff | Dieser Ordner, Unterordner und Dateien |
| `CREATOR OWNER` | Vollzugriff | Unterordner und Dateien |
| Domänenbenutzer | Ordner erstellen / Daten anhängen sowie Ordnerinhalt auflisten | Nur dieser Ordner |

Die konkreten Berechtigungen müssen an die Sicherheitsrichtlinien der Umgebung angepasst
und anschliessend mit einem Testbenutzer geprüft werden. Benutzer sollten keinen Zugriff
auf die Profilcontainer anderer Benutzer erhalten.

### 6. Konfiguration über `GPO_FXLogix`

Die FSLogix-Einstellungen werden über die Gruppenrichtlinie `GPO_FXLogix` verteilt.
Typische Einstellungspfade befinden sich unter:

`Computerkonfiguration -> Administrative Vorlagen -> FSLogix -> Profile`

Dort werden mindestens folgende Einstellungen konfiguriert:

| Einstellung | Wert für diese Umgebung |
| :--- | :--- |
| Enable Profile Containers | Aktiviert |
| VHD Locations | `\\DC01\FSLogixProfiles$` |
| Profile Container Type | VHDX, sofern in der Umgebung verfügbar |
| Delete local profile when FSLogix profile should be applied | Nach Bedarf, zunächst deaktiviert testen |
| Size in MBs | Nach verfügbarem Speicher und Benutzerzahl festlegen |

Die GPO muss auf die richtigen Computerobjekte wirken. Nach Änderungen kann die Richtlinie
auf einem Testclient mit folgendem Befehl aktualisiert werden:

```powershell
gpupdate /force
```

Die tatsächlich angewendeten Richtlinien lassen sich anschliessend mit `gpresult` prüfen:

```powershell
gpresult /h "$env:TEMP\gpresult.html"
```

### 7. Ablauf bei der ersten Anmeldung

1. Der Benutzer meldet sich an einem Domänen-Client an.
2. Die GPO `GPO_FXLogix` wird angewendet.
3. FSLogix prüft die konfigurierte VHD/VHDX-Freigabe.
4. Für den Benutzer wird ein Profilcontainer erstellt oder der vorhandene Container geöffnet.
5. Der Container wird als Benutzerprofil eingebunden.
6. Bei der Abmeldung wird der Container geschlossen und die Änderungen werden gespeichert.

Die Container liegen normalerweise in einer vom FSLogix-Dienst verwalteten Ordnerstruktur.
Sie sollten nicht manuell umbenannt, verschoben oder gleichzeitig geöffnet werden.

### 8. Funktionstest

Der Test wird mit einem normalen Domänen-Testbenutzer durchgeführt:

1. Am Client mit dem Testbenutzer anmelden.
2. Auf dem Desktop die Datei `FSLogix-Test.txt` erstellen.
3. Abmelden und prüfen, ob der Container auf `DC01` erstellt oder aktualisiert wurde.
4. An einem zweiten Domänen-Client mit demselben Benutzer anmelden.
5. Prüfen, ob die Datei `FSLogix-Test.txt` im Profil vorhanden ist.
6. Eine zweite Datei erstellen, abmelden und die Synchronisation erneut kontrollieren.

Zusätzlich sollte auf dem Client geprüft werden, ob die GPO angewendet wurde:

```powershell
gpresult /r
```

### 9. Fehleranalyse

| Symptom | Mögliche Ursache | Prüfung |
| :--- | :--- | :--- |
| Kein Container wird erstellt | GPO nicht angewendet oder FSLogix deaktiviert | `gpresult /r`, GPO-Verknüpfung und FSLogix-Einstellungen prüfen |
| Anmeldung bleibt hängen | SMB, DNS oder Berechtigungen fehlerhaft | `Test-NetConnection DC01 -Port 445` und Zugriff auf die Freigabe prüfen |
| Zugriff verweigert | Fehlende Share- oder NTFS-Berechtigung | Effektive Berechtigungen des Testbenutzers prüfen |
| Neues Profil statt vorhandener Daten | Container nicht gefunden oder Profilfehler | FSLogix- und Ereignisprotokolle prüfen |
| Profil bleibt gesperrt | Vorherige Sitzung nicht sauber beendet | Offene Sitzungen und VHDX-Sperren auf dem Server prüfen |

Relevante Protokolle befinden sich typischerweise unter:

- **Anwendungs- und Dienstprotokolle -> Microsoft -> FSLogix -> Apps -> Operational**
- **Windows-Protokolle -> Anwendung**
- **Windows-Protokolle -> System**

### 10. Sicherheit und Betrieb

- Profilcontainer dürfen nur von den vorgesehenen Benutzern und Administratoren gelesen werden.
- Die Freigabe muss regelmässig gesichert werden.
- Vor Änderungen an GPOs oder Berechtigungen sollte ein Test mit einem einzelnen Benutzer erfolgen.
- Verwaiste Container und nicht mehr benötigte Benutzerprofile sollten nach einem definierten Prozess entfernt werden.
- Der Speicherplatz und die Grösse der VHDX-Dateien müssen regelmässig überwacht werden.

### 11. Ergebnis

FSLogix stellt in dieser Umgebung servergespeicherte Benutzerprofile über die SMB-Freigabe
`\\DC01\FSLogixProfiles$` bereit. Die zentrale Steuerung erfolgt über `GPO_FXLogix`.
Damit kann sich ein Benutzer an mehreren Domänen-Clients anmelden und dieselbe
Profilumgebung verwenden.

> [!IMPORTANT]
>
> OneDrive kann im Moment nicht als zentraler Profilspeicher verwendet werden. Die
> FSLogix-Konfiguration ist deshalb die vorgesehene Lösung für servergespeicherte Profile.

## 12. Nachweis und Screenshots

Die folgenden Screenshots dienen als Beweis für die Umsetzung der FSLogix-Umgebung. In
jedem Screenshot sollten der relevante Hostname, der GPO-Name oder der konfigurierte Pfad
sichtbar sein. Benutzernamen, Kennwörter und andere vertrauliche Informationen müssen vor
der Abgabe unkenntlich gemacht werden.

### 12.1 Empfohlene Nachweise

| Nachweis | Was auf dem Screenshot sichtbar sein sollte | Screenshot |
| :--- | :--- | :--- |
| SMB-Freigabe | Server `DC01` und Freigabe `FSLogixProfiles$` | ![FSLogix_Share](/images/FSLogix_Share.png) |
| GPO-Übersicht | Gruppenrichtlinienobjekt `GPO_FXLogix` und dessen Verknüpfung | ![FSLogix_GPO](/images/FSLogix_GPO.png) |
| GPO-Konfiguration | Aktivierte Profile-Container-Einstellung und `VHD Locations` mit `\\DC01\FSLogixProfiles$` | ![FSLogix_GPO_Conf](/images/FSLogix_GPO_Config.png) |
| Berechtigungen | NTFS-Berechtigungen des Profilordners | ![FSLogix_NTFS_Permissions](/images/FSLogix_NTFS_Permissions.png) |
| Erstellter Container | Profilcontainer nach der ersten Testanmeldung auf `DC01` | ![FSLogix_Folder_Content](/images/FSLogix_Folder_Content.png) |
| GPO-Nachweis | Ausgabe von `gpresult /r /scope computer` auf dem Testclient mit `GPO_FXLogix` | ![FSLogix_GPO_Result_Computer](/images/FSLogix_GPO_Result_Computer.png) |


> [!NOTE]
> **Details zum Gruppenrichtlinien-Bericht**
> Weitere Informationen zu Benutzerprofilen und zur Ergebnisanalyse finden Sie im Leitfaden für [servergespeicherte Benutzerprofile](./gpresult.html).