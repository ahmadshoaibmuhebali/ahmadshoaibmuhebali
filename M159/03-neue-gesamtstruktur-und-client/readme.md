# Gesamtstruktur und Client
----
## AD DS-Rolle
Auf dem Server **DC01** wurde die Rolle **Active Directory-Domänendienste (AD DS)** installiert. Die Domäne lautet ***dc1.cloud-ah.local***. Der NetBIOS-Name der Domäne lautet ***DC1***.

![ADDS](/images/ADDS.png)

## DNS
Nach der Installation der AD DS-Rolle wurde der DNS-Server automatisch installiert. Für diesen DNS-Server wurden die Weiterleitungen ***9.9.9.9*** und ***149.112.112.112*** konfiguriert.
> [!NOTE]
> **Warum Quad9 (9.9.9.9) statt Google Public DNS (8.8.8.8)?**
> - **Sicherheitsfilter:** [Quad9](https://quad9.net/de/ "Offizielle Quad9-Website") blockiert bekannte schädliche und Phishing-Domänen automatisch.
> - **Datenschutz:** Quad9 gibt an, keine personenbezogenen Daten zu speichern, und wird von einer gemeinnützigen Schweizer Stiftung betrieben.
> - **Geschwindigkeit:** Beide DNS-Dienste sind kostenlos und in der Regel schnell erreichbar.
### Forward-Lookupzone
Die Forward-Lookupzone wurde automatisch erstellt. Die zugehörigen Ressourceneinträge wurden ebenfalls automatisch angelegt.

![DNS-Farward-Zone](/images/dns-foward-zone.png)

### Reverse-Lookupzonen
Auf dem DNS-Server wurde für jedes Subnetz eine Reverse-Lookupzone erstellt.

![Revers-Zone](/images/Revers-Zone.png)

## Weitere AD-Einstellungen

### AD-Papierkorb
Der AD-Papierkorb wurde auf dem AD-Server über das **Active Directory Administrative Center** aktiviert.

**Vorgehen**
1. Drücken Sie die Windows-Taste + R
2. Geben Sie `dsac.exe` ein und drücken Sie die Eingabetaste.
3. Klicken Sie im linken Bereich auf den Domänennamen `dc1 (local)`.
4. Klicken Sie auf **Papierkorb aktivieren**.

![Papier-Korb](/images/PapierKorb.jpg)

## Client in die Domäne einbinden
Der Client wurde erfolgreich in die Domäne eingebunden.
![Client-AD-Join](/images/Client-AD-Join.png)

### Remotedesktop für Administratoren und Benutzer
Der Zugriff auf Remotedesktop wurde für den Client über eine Gruppenrichtlinie (GPO) konfiguriert.

![Remote-Desktop](/images/Remote-Desktop-Cients.png)
> [!NOTE]
> Mehr dazu finden Sie in der GPO-Dokumentation.