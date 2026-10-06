# Netzlaufwerk to Azure Files Migration

Der Zugriff auf einen File Share bei Azure Files kann über verschiedene **Identity-based Access**-Authentifizierungsmechanismen erfolgen:

- **Active Directory Domain Services (AD DS)**
- **Microsoft Entra Domain Services**
- **Microsoft Entra Kerberos**

Theoretisch wären in unserem Setup alle drei Varianten möglich, jedoch gibt es Unterschiede und Einschränkungen:

### Active Directory Domain Services (AD DS)

Bei dieser Variante stellt der lokale On-Premises DC (KDC) dem Client, der auf den Share zugreifen will, ein Kerberos-Ticket aus.
 Damit dies möglich ist, muss der Storage Account als Computerobjekt im lokalen AD registriert werden.
 Dies geschieht mit dem Befehl: `Join-AzStorageAccount`.

> [!IMPORTANT]
>
> Diese Variante sollen Sie im Auftrag verwenden, wenn Sie mit dem AWS Learner Lab arbeiten.

### Microsoft Entra Domain Services

Funktioniert ähnlich wie AD DS, jedoch wird das Directory in Azure bereitgestellt und mit Entra ID synchronisiert.
 Diese Variante verursacht jedoch zusätzliche Kosten und Ressourcenaufwand, ohne dass sie in unserem Szenario einen Vorteil bringt.

### Microsoft Entra Kerberos

Dies wäre eigentlich die eleganteste Lösung, da sich die Clients direkt gegenüber einem KDC in Entra authentifizieren.
 Ein lokales Storage Account Objekt wird hierbei nicht benötigt, da Entra selbst Kerberos-Tickets mit den korrekten SPNs ausstellen kann.

**Einschränkung:** Aktuell ist der Zugriff mit Microsoft Entra Kerberos nur von Windows-Clientbetriebssystemen aus möglich – daher für unser Szenario nicht geeignet.



## Ressourcen

- [Bewertungskriterien](../../08-kompetenznachweise/lb2/kompetenzmatrix-lb2.md)
- `Test-NetConnection -ComputerName modul159tbz.file.core.windows.net -Port 445` (Befehlt um den Port 445 zu testen)
- `New-PSDrive -Name Z -PSProvider FileSystem -Root "\\modul159tbz.file.core.windows.net\daten" -Persist` (Befehl zum den Azure Share verbinden)
- `Start-ADSyncSyncCycle -PolicyType Initial`  oder `Start-ADSyncSyncCycle -PolicyType Delta` (Befehl um den DC mit dem Entra ID via AD-Connect zu synchronisieren)
- `dsregcmd /status`



# Allgemein

## Speicherkonto (Storage Account) einrichten

| Schritte  | Printscreens                                      |
| --------- | ------------------------------------------------- |
| Schritt 1 | ![Storage Account](/M159/12-netzlaufwerk-to-azure-migration/resources/storage-account.png) |
| Schritt 2 | Rest mit den Standardeinstellungen                |



## Share anlegen

| Schritte  | Printscreens                               |
| --------- | ------------------------------------------ |
| Schritt 1 | ![share](/M159/12-netzlaufwerk-to-azure-migration/resources/create-new-share-1.png) |
| Schritt 2 | ![share](/M159/12-netzlaufwerk-to-azure-migration/resources/create-new-share-2.png) |
| Schritt 3 | ![share](/M159/12-netzlaufwerk-to-azure-migration/resources/create-new-share-3.png) |



# AD DS - Authentifizierung

| Schritte                          | Printscreens                                                 |
| --------------------------------- | ------------------------------------------------------------ |
| Schritt 1 (Zugriff konfigurieren) | ![Entra_Kerberos_einrichten](/M159/12-netzlaufwerk-to-azure-migration/resources/zugriff-aktivieren.png) |
| Schritt 2                         | ![Entra_Kerberos_einrichten](/M159/12-netzlaufwerk-to-azure-migration/resources/ad-ds-access.png)     |

## Domain join the storage account to your Domain

https://www.youtube.com/watch?v=a-Twfus0HWE (Den ganzen VPN-Teil vom Video können Sie ignorieren, da wir über die öffentliche IP-Adresse und dem SMB-Port zugreifen können.)

### Installation von **AzFilesHybrid**

1. PowerShell als Admin starten.

2. Repository von Microsoft herunterladen und entpacken:

   ```
   # Zielordner definieren
   $downloadPath = "C:\AzFilesHybrid"
   
   # ZIP von Microsoft runterladen
   Invoke-WebRequest -Uri "https://github.com/Azure-Samples/azure-files-samples/releases/download/v0.2.3/AzFilesHybrid.zip" -OutFile "$downloadPath\AzFilesHybrid.zip"
   
   # Entpacken
   Expand-Archive "$downloadPath\AzFilesHybrid.zip" -DestinationPath $downloadPath
   ```

3. Modul importieren:

   ```
   Import-Module "$downloadPath\AzFilesHybrid\AzFilesHybrid.psd1" -Force
   ```

> [!TIP]
>
> Wenn Fehler kommt folgendes versuchen

Öffne **PowerShell als Administrator** und führe nacheinander aus:

```
# TLS 1.2 erzwingen (falls alte Defaults)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# NuGet-Provider sicherstellen
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

# PowerShellGet aktualisieren (>= 1.6)
Install-Module -Name PowerShellGet -MinimumVersion 2.2.5 -Force -AllowClobber
```

> Danach **ALLE** PowerShell-Fenster schließen (auch ISE/VSCode-Terminals).



#### PowerShell neu öffnen (wieder als Admin) und Modul importieren

Optional: entblocke die entpackten Dateien, damit Windows nicht blockt:

```
Get-ChildItem C:\AzFilesHybrid -Recurse | Unblock-File
```

Dann importieren:

```
# Variante A: über das Manifest (normal)
Import-Module "C:\AzFilesHybrid\AzFilesHybrid.psd1" -Force
# Falls das erneut meckert, direkt die psm1 laden:
# Import-Module "C:\AzFilesHybrid\AzFilesHybrid.psm1" -Force
```

Check:

```
Get-Command -Module AzFilesHybrid
```

Wenn du die Cmdlets (z. B. `Join-AzStorageAccountForAuth`, `Update-AzStorageFileShareAcl`) siehst, ist das Modul korrekt geladen.



### Storage Account als lokalen AD-Objekt anlegen

| Schritte                                                | Printscreens                                                 |
| ------------------------------------------------------- | ------------------------------------------------------------ |
| Schritt 1 (Überprüfen ob die PS-Befehle vorhanden sind) | ![Entra_Kerberos_einrichten](/M159/12-netzlaufwerk-to-azure-migration/resources/domainjoinstorageaccount/azfileshybrid-ps.png) |
| Schritt 2 (Connect to Azure)                            | ![Entra_Kerberos_einrichten](/M159/12-netzlaufwerk-to-azure-migration/resources/domainjoinstorageaccount/connect-azaccount.png) |
| Schritt 3 (Join-AzStorageAccount)                       | ![Entra_Kerberos_einrichten](/M159/12-netzlaufwerk-to-azure-migration/resources/domainjoinstorageaccount/join-azstorageaccount.png) |
| Schritt 4 (StorageAccountObjekt-AD verifizieren)        | ![Entra_Kerberos_einrichten](/M159/12-netzlaufwerk-to-azure-migration/resources/domainjoinstorageaccount/storageaccountobjekt-ad.png) |



### GPO - Define host name-to-Kerberos realm mappings

Damit der lokale KDC ein Kerberos-Ticket für den Azure File Share ausstellen kann, muss noch eine zusätzliche GPO konfiguriert werden.

Hintergrund: Der Benutzer kann sich zwar mit dem Custom-UPN anmelden, aber Kerberos verwendet immer den Realm der lokalen AD-Domäne. Ohne Mapping würde der Client den Hostnamen `<storageaccount>.file.core.windows.net` einem falschen Realm zuordnen und die Fehlermeldung erhalten, dass der KDC kein passendes Computerkonto findet.

Die Gruppenrichtlinie „Define host name-to-Kerberos realm mappings“ sorgt dafür, dass der Client für den Zugriff auf den Storage Account den korrekten Realm der lokalen Domäne z.B. (`EC2.TBZ.M159`) verwendet.

| Schritte                                                | Printscreens                                                 |
| ------------------------------------------------------- | ------------------------------------------------------------ |
| Schritt 1 (Überprüfen ob die PS-Befehle vorhanden sind) | ![Entra_Kerberos_einrichten](/M159/12-netzlaufwerk-to-azure-migration/resources/domainjoinstorageaccount/azfileshybrid-ps.png) |
| Schritt 2 (Connect to Azure)                            | ![Entra_Kerberos_einrichten](/M159/12-netzlaufwerk-to-azure-migration/resources/domainjoinstorageaccount/connect-azaccount.png) |



## Berechtigungen und Rollen auf dem Share zuweisen

- Geben Sie Ihrem User aus der Abteilung Sekretariat die Rolle: Storage File Data SMB Share Reader
- Geben Sie Ihrem User aus der Buchhaltung die Rolle: Storage File Data SMB Share Contributor

| Schritte  | Printscreens                                      |
| --------- | ------------------------------------------------- |
| Schritt 1 | ![Entra_Kerberos_einrichten](/M159/12-netzlaufwerk-to-azure-migration/resources/roles.png) |



## Zum Azure Share verbinden

- Testen Sie nach dem verbinden die Berechtigung der beiden User aus den Abteilungen Sekretariat (Read) & Buchhaltung (Write)

| Schritte                                                     | Printscreens                                                 |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| Schritt 1 (Device State Hybrid&SSO mit `dsregcmd /status` überpüfen) | ![Entra_Kerberos_einrichten](/M159/12-netzlaufwerk-to-azure-migration/resources/verbinden/azureadprt-yes.png) |
| Schritt 2                                                    | ![Entra_Kerberos_einrichten](/M159/12-netzlaufwerk-to-azure-migration/resources/verbinden/netuse.png) |
| Schritt 3                                                    | ![Entra_Kerberos_einrichten](/M159/12-netzlaufwerk-to-azure-migration/resources/verbinden/explorer.png) |









##  Microsoft Entra Kerberos auf dem Share aktivieren (Im Moment inaktiv)

> [!WARNING]
>
> (Funktioniert nur wenn man Win11 Client OS hat)

| Schritte  | Printscreens                                                 |
| --------- | ------------------------------------------------------------ |
| Schritt 1 | ![Entra_Kerberos_einrichten](/M159/12-netzlaufwerk-to-azure-migration/resources/zugriff/identitaetsbasierter-zugriff1.png) |
| Schritt 2 | ![Entra_Kerberos_einrichten](/M159/12-netzlaufwerk-to-azure-migration/resources/zugriff/identitaetsbasierter-zugriff2-1.png) |
| Schritt 3 | ![Entra_Kerberos_einrichten](/M159/12-netzlaufwerk-to-azure-migration/resources/zugriff/identitaetsbasierter-zugriff2.png) |
| Schritt 4 | ![Entra_Kerberos_einrichten](/M159/12-netzlaufwerk-to-azure-migration/resources/zugriff/identitaetsbasierter-zugriff3.png) |
