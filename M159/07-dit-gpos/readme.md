# Directory Information Tree und Gruppenrichtlinien

## Zielsetzung

In diesem Kapitel wird die Struktur des Active Directory (AD) sowie die Konfiguration zentraler Gruppenrichtlinien (Group Policy Objects, GPOs) dokumentiert. Ziel ist eine übersichtliche Organisation von Benutzern und Computern sowie eine zentral verwaltbare Konfiguration der Clients.

## Directory Information Tree

Für die Umgebung wurde ein Directory Information Tree (DIT) mit folgenden Grundsätzen erstellt:

- Jede Abteilung wird genau einmal als Organisationseinheit (OU) abgebildet.
- Die Bereiche **Intern** und **Extern** werden als getrennte Ebenen geführt.
- Alle OUs und Gruppen erhalten eindeutige und nachvollziehbare Namen.
- Die unterste Ebene wird nach Benutzerkonten und Computerkonten getrennt.

Diese Struktur erleichtert die Delegation von Berechtigungen, die gezielte Verknüpfung von GPOs und die spätere Administration des Verzeichnisses.

![DIT](/images/DIT.svg)

## Gruppenrichtlinien

### 1. Passwortrichtlinien

Die Passwortrichtlinien wurden in der **Default Domain Policy** angepasst. In der Standardrichtlinie werden ausschliesslich die erforderlichen Passworteinstellungen verändert. Andere Einstellungen werden in separaten, thematisch abgegrenzten GPOs konfiguriert.

![Password-Complexity](/images/Password-Complexity.png)

### 2. Netzlaufwerke verteilen

Die Netzlaufwerke werden abhängig von Benutzer- und Abteilungszugehörigkeit über Gruppenrichtlinien bereitgestellt:

- **Pool:** gemeinsames Laufwerk für die gesamte Organisation
- **Abteilungslaufwerk:** Laufwerk für die jeweilige Abteilung
- **Intern:** Laufwerk für interne Abteilungen

Das Laufwerk für externe Benutzer konnte nicht über die Windows-GPO-Infrastruktur bereitgestellt werden. Die externen Benutzer befinden sich auf einem separaten Samba-4-AD-Domänencontroller, während die betreffenden Ressourcen auf dem Windows-Domänencontroller liegen. Für diese Benutzer wäre eine separate Vertrauensstellung oder eine alternative Berechtigungs- und Bereitstellungslösung erforderlich.

![Pool und Intern Drive Map GPO](/images/Pool-Intern-Drive-Map.png)
*Abbildung: GPOs für die Laufwerke Pool und Intern*

![Abteilung Drive Map GPO](/images/Abteillung-Drive-Map.png)
*Abbildung: GPO für die Abteilungslaufwerke*

### 3. Desktop-Verknüpfung mit Sicherheitsfilterung

Für die CRM-Anwendung wurde eine GPO mit einer Desktop-Verknüpfung erstellt und auf der obersten Ebene der Domäne verknüpft. Mithilfe der positiven Sicherheitsfilterung wird die Richtlinie nur auf die dafür vorgesehene Sicherheitsgruppe angewendet. Dadurch erhalten ausschliesslich berechtigte Benutzer die Verknüpfung.

![GPO-Sicherheitfilterung](/images/CRM-GPO-Security-Filter.png)

![GPO-Shortcut](/images/CRM-Shortcut.png)

### 4. GPO mit WMI-Filter

Die Konfiguration einer GPO mit WMI-Filter konnte in dieser Umgebung nicht umgesetzt werden. Die dafür benötigte Gruppen- bzw. Computerstruktur befindet sich auf dem Samba-4-AD-Domänencontroller, während die betroffenen Ressourcen auf dem Windows-Domänencontroller verwaltet werden. Dadurch stehen die für diesen Anwendungsfall benötigten Informationen nicht zentral am selben Ort zur Verfügung.

### 5. Drucker verteilen

Auf dem Server wurden zwei Testdrucker eingerichtet: ein Farb- und ein Schwarz-Weiss-Drucker. Die Drucker werden internen Benutzern über UNC-Pfade bereitgestellt, beispielsweise:

```text
\\dc01.dc1.cloud-ah.local\Drucker_Name
```

Die Verteilung erfolgt über eine Gruppenrichtlinie.

![Printer-GPO](/images/Printern-GPO.png)

### 6. MSI-Paket verteilen

Das MSI-Paket von 7-Zip wird über eine GPO auf ausgewählten Clientcomputern installiert. Für die Bereitstellung wurden folgende Schritte durchgeführt:

1. Eine Netzwerkfreigabe für die Installationsdatei wurde erstellt.
2. Das 7-Zip-MSI-Paket wurde heruntergeladen und in der Freigabe abgelegt.
3. Eine GPO für die Softwarebereitstellung wurde erstellt und mit der Domäne verknüpft.
4. Eine Sicherheitsgruppe für die Zielcomputer wurde erstellt.
5. Der Clientcomputer wurde der Sicherheitsgruppe hinzugefügt.
6. Über die Sicherheitsfilterung wurde festgelegt, dass nur Computer in dieser Gruppe die Softwareinstallation erhalten.

Die Installation wird beim nächsten Aktualisieren der Gruppenrichtlinien beziehungsweise beim nächsten Systemstart des Zielcomputers angewendet. Der Installationsstatus kann zusätzlich in der Ereignisanzeige des Clients überprüft werden.

![7-Zip-Security-Group](/images/7-zip-Security-group.png)

![7-Zip-GPO](/images/7-Zip-GPO.png)

![7-Zip-GPO-Konfiguration](/images/7-zip-gpo-configuration.png)

![7-Zip-Event-Log](/images/7-Zip-Event-Log.png)

> [!TIP]
> Eine ausführlichere Übersicht der GPO-Konfiguration befindet sich in der [GPO-HTML-Dokumentation](/07-dit-gpos/gpo.html).
