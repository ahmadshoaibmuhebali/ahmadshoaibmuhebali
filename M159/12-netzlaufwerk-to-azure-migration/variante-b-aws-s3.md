# Auftrag 12 – Variante B: Hybrid Cloud Storage & Backup mit AWS

> [!IMPORTANT]
>
> Dies ist die **Ausweichvariante** zu [Auftrag 12](readme.md). Sie bearbeiten diese Variante
> nur dann, wenn Ihr Azure-Zugang nachweislich nicht funktioniert.
>
> **Voraussetzungen für den Wechsel:**
>
> 1. Sie belegen den Fehlschlag mit einem Screenshot (Fehlermeldung oder Ablehnung bei der
>    Aktivierung von Azure for Students).
> 2. Die Lehrperson gibt den Wechsel frei.
>
> Der dokumentierte Fehlschlag ist Teil Ihrer Abgabe. Variante B wird nach denselben vier
> Stufen bewertet wie Variante A.
>
> **Abweichung bei den Kompetenzfeldern:** Variante A deckt G und H ab, Variante B nur H.
> Das Kompetenzfeld G bleibt über Auftrag 05 (AWS Managed Microsoft AD) abgedeckt.

## 1. Einleitung & Szenario
In modernen Unternehmen werden Daten nicht mehr nur lokal gespeichert. Um die Ausfallsicherheit zu erhöhen und Kosten zu optimieren, werden "kalte Daten" (Archive oder Backups) oft in die Cloud ausgelagert. In dieser Aufgabe simulieren Sie ein solches Hybrid-Szenario mit AWS S3.

**Szenario:**
Der lokale Speicherplatz auf Ihrem Fileserver wird knapp. Die Geschäftsleitung hat entschieden, dass wichtige AD-Berichte und Archivdaten automatisch in die AWS Cloud gesichert werden sollen. Da Azure für dieses Projekt nicht zur Verfügung steht, nutzen Sie den Marktführer AWS.

## 2. Lernziele
* Unterschied zwischen Block-Storage (NTFS) und Object-Storage (S3) verstehen.
* Installation und Konfiguration der AWS CLI auf einem Windows Server.
* Automatisierung von Cloud-Uploads mittels PowerShell.
* Grundverständnis für Cloud-IAM (Identity & Access Management).

---

## 3. Vorbereitung der Umgebung
Für diese Aufgabe benötigen Sie Zugriff auf die AWS Management Console (Free Tier ist ausreichend).

1. **AWS Cloud Setup:**
    * Erstellen Sie einen **S3 Bucket** (Name: `tbz-m159-backup-[ihr-nachname]`).
    * Erstellen Sie unter **IAM** einen neuen User `BackupAdmin` mit dem Zugriffstyp "Programmatic Access".
    * Weisen Sie dem User die Berechtigung `AmazonS3FullAccess` zu.
    * **Wichtig:** Speichern Sie die `Access Key ID` und den `Secret Access Key` sicher ab.
2. **Lokale Datenquelle:**
    * Erstellen Sie auf Ihrem DC den Ordner `C:\CompanyArchive\`.
    * Kopieren Sie einige Testdateien (PDFs, TXT) hinein.
3. **AWS CLI:**
    * Laden Sie den "AWS CLI MSI Installer for Windows" auf Ihren DC herunter und installieren Sie ihn.
    * Öffnen Sie die PowerShell und führen Sie `aws configure` aus. Geben Sie dort Ihre Keys und die Region (z.B. `eu-central-1`) ein.

---

## 4. Das Skript ("Backup-Automation")
Erstellen Sie ein neues PowerShell-Skript namens `Sync-ToCloud.ps1`. Dieses Skript soll den Inhalt des lokalen Ordners mit dem Cloud-Bucket synchronisieren.

**Anforderung:** Nutzen Sie den Befehl `aws s3 sync`. Recherchieren Sie in der AWS Dokumentation, wie dieser Befehl syntaktisch aufgebaut ist, um einen lokalen Pfad mit einem S3-URI abzugleichen.

---

## 5. Arbeitsauftrag

### Teil A: Implementierung & Konfiguration
Setzen Sie die Hybrid-Sicherung technisch um. Achten Sie auf folgende Punkte:

1. **CLI-Verbindung:** Testen Sie die Verbindung zum Bucket mit `aws s3 ls`. Erhalten Sie eine Liste Ihrer Buckets?
2. **Synchronisation:** Führen Sie Ihr Skript aus. Verifizieren Sie in der AWS Web-Console, ob die Dateien aus `C:\CompanyArchive\` nun im Bucket erscheinen.
3. **Automatisierung:** Richten Sie im Windows **Task Scheduler** (Aufgabenplanung) eine Aufgabe ein, die Ihr Skript alle 15 Minuten (oder einmal täglich) automatisch ausführt.

### Teil B: Disaster Recovery Test
Ein Backup ist nur so gut wie sein Restore.
* Löschen Sie lokal eine Datei aus dem Ordner `C:\CompanyArchive\`.
* Schreiben Sie einen Befehl (oder ein kleines Skript), um genau diese Datei wieder aus dem AWS S3 Bucket auf Ihren Server herunterzuladen.

---

## 6. Abgabe-Kriterien
1. **Konfigurations-Nachweis:** Ein Screenshot Ihrer AWS Console, der den gefüllten S3 Bucket zeigt.
2. **Automatisierungs-Nachweis:** Ein Screenshot des Task Schedulers, der den eingerichteten Backup-Job zeigt.
3. **Skript:** Ihr PowerShell-Skript für den Sync und den dokumentierte Restore-Befehl.