# Netzlaufwerk to Azure Migration



## Ressourcen

- [Bewertungskriterien](../../08-kompetenznachweise/lb2/kompetenzmatrix-lb2.md)



### **1. Azure Storage Account anlegen**

1. Melden Sie sich unter https://portal.azure.com mit Ihrem Azure for Students Account an.
2. Erstellen Sie einen neuen **Storage Account**:
   - **Resource Group**: `Ihr Projektname`
   - **Name**: `storage<Initialen>`
   - **Region**: `West Europe`
   - **Performance**: `Standard`
   - **Redundancy**: `Locally-redundant storage (LRS)`
3. Warten Sie, bis die Bereitstellung abgeschlossen ist.

------

### **2. File Share erstellen**

1. Öffnen Sie den neuen Storage Account.
2. Gehen Sie zu **Data Storage → File Shares**.
3. Erstellen Sie ein neues File Share:
   - **Name**: `Ihr Projektname`
   - **Quota**: 5 GB (ausreichend für Testzwecke).

------

### **3. Entra ID (Azure AD) Authentifizierung aktivieren**

1. Im Storage Account zu **Configuration → Identity-based access for file shares** wechseln.
2. **Azure AD Authentication for SMB** aktivieren.
3. Unter **Access Control (IAM)**:
   - Fügen Sie **Ihren eigenen Benutzer** hinzu.
   - Rollen:
     - `Storage File Data SMB Share Contributor`
     - `Storage File Data SMB Share Elevated Contributor` (optional für volle Rechte).

------

### **4. Test-VM vorbereiten und Port 445 für SMB öffnen**

- Nutzen Sie eine **Windows 10/11 VM**, die **Azure AD joined** ist (kein On-Prem AD!).
- Fügen Sie Port 445 zur Sicherheitsgruppe des Clients hinzu
- Prüfen Sie, ob die Anmeldung mit Ihrem **Entra-Konto** möglich ist.

------

### **5. File Share manuell mounten (Test)**

Öffnen Sie PowerShell und führen Sie aus:

```
powershell


KopierenBearbeiten
net use Z: \\<storageaccountname>.file.core.windows.net\unterricht
```

**Tipp:** Ersetzen Sie `<storageaccountname>` durch Ihren Storage-Namen.

Falls alles klappt, sehen Sie ein leeres Laufwerk Z:.

------

### **6. Automatisches Mapping per Login-Skript**

Erstellen Sie ein PowerShell-Skript `map_drive.ps1` mit folgendem Inhalt:

```
powershellKopierenBearbeiten$share = "\\<storageaccountname>.file.core.windows.net\unterricht"
# Falls bereits verbunden: trennen
net use Z: /delete /y
# Laufwerk neu verbinden
net use Z: $share /persistent:yes
```

Legen Sie das Skript im Autostart-Ordner des Windows-Benutzers ab oder erstellen Sie eine geplante Aufgabe, die es beim Login ausführt.

------

### **7. Erweiterung (Optional / Bonus)**

- **Berechtigungen testen:** Erstellen Sie eine weitere Entra-ID-Gruppe, vergeben Sie nur **Lesezugriff**, und testen Sie mit einem zweiten Benutzer.
- **Schönes HTML-Log-Skript:** Schreiben Sie ein kleines PowerShell-Skript, das den Mount-Vorgang protokolliert und eine Meldung ausgibt (*„Cloudlaufwerk erfolgreich verbunden!“*).

------

## **Abgabe**

- Dokumentieren Sie alle Schritte mit Screenshots.
- Laden Sie Ihr `map_drive.ps1` Skript mit hoch.
- Beschreiben Sie in 3–4 Sätzen, wie Entra ID bei der Authentifizierung gegen Azure Files wirkt.

------

## **Zusatzwissen für Schüler (Frage)**

- **Wie unterscheidet sich dieser Ansatz von einem klassischen On-Prem File Server?**
- **Warum ist Entra ID sicherer als die Authentifizierung mit Storage Keys?**