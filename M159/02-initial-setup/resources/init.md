# Initiales Setup
Die EC2-Instanzen wurden gemäss Planung erstellt. Drei Instanzen befinden sich
im vorgesehenen Subnetz und verwenden die geplanten IP-Adressen.
![EC2](/images/EC2_Instances.png)

## Init-Skript
Das Init-Skript wurde angepasst und auf jeder Instanz ausgeführt.
```powershell
# 1) Pfade und Hilfsfunktion fuer Verknuepfungen
$DefaultDesktop = Join-Path $env:SystemDrive 'Users\Default\Desktop'
$CurrentDesktop = [Environment]::GetFolderPath('Desktop')

foreach ($desk in @($DefaultDesktop, $CurrentDesktop)) {
    if (-not (Test-Path $desk)) {
        New-Item -Path $desk -ItemType Directory -Force | Out-Null
    }
}

function New-Shortcut {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Target,
        [string] $Arguments,
        [string] $IconLocation
    )
    $shell = New-Object -ComObject WScript.Shell
    $sc = $shell.CreateShortcut($Path)
    $sc.TargetPath = $Target
    if ($Arguments)    { $sc.Arguments    = $Arguments }
    $sc.WorkingDirectory = Split-Path $Target
    if ($IconLocation) { $sc.IconLocation = $IconLocation }
    $sc.Save()
}

function Add-DesktopShortcuts {
    param([Parameter(Mandatory)][string] $DesktopPath)

    $controlExe = Join-Path $env:SystemRoot 'System32\control.exe'
    $psExe      = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $cmdExe     = Join-Path $env:SystemRoot 'System32\cmd.exe'

    # PowerShell
    New-Shortcut -Path (Join-Path $DesktopPath 'PowerShell.lnk') `
        -Target $psExe -IconLocation "$psExe,0"

    # Eingabeaufforderung (cmd)
    New-Shortcut -Path (Join-Path $DesktopPath 'Eingabeaufforderung.lnk') `
        -Target $cmdExe -IconLocation "$cmdExe,0"

    # Netzwerkverbindungen (ncpa.cpl)
    New-Shortcut -Path (Join-Path $DesktopPath 'Netzwerkverbindungen.lnk') `
        -Target $controlExe -Arguments 'ncpa.cpl' `
        -IconLocation "$env:SystemRoot\System32\ncpa.cpl,0"
        
    # Remote Desktop (mstsc)
    New-Shortcut -Path (Join-Path $DesktopPath 'Remote Desktop.lnk') `
        -Target "$env:SystemRoot\System32\mstsc.exe" `
        -IconLocation "$env:SystemRoot\System32\mstsc.exe,0"

    # Systemeigenschaften (sysdm.cpl)
    New-Shortcut -Path (Join-Path $DesktopPath 'Systemeigenschaften.lnk') `
        -Target $controlExe -Arguments 'sysdm.cpl' `
        -IconLocation "$env:SystemRoot\System32\sysdm.cpl,0"

    # Systemsteuerung
    New-Shortcut -Path (Join-Path $DesktopPath 'Systemsteuerung.lnk') `
        -Target $controlExe -IconLocation "$controlExe,0"

    # Firewall (Defender Firewall)
    New-Shortcut -Path (Join-Path $DesktopPath 'Firewall.lnk') `
        -Target $controlExe -Arguments '/name Microsoft.WindowsFirewall' `
        -IconLocation "$env:SystemRoot\System32\FirewallControlPanel.dll,0"
}

# Verknuepfungen fuer Default und aktuellen Benutzer
Add-DesktopShortcuts -DesktopPath $DefaultDesktop
Add-DesktopShortcuts -DesktopPath $CurrentDesktop

# 2) Firewall: Ping (ICMP Echo) fuer alle Profile aktivieren
$icmpRules = @('FPS-ICMP4-ERQ-In','FPS-ICMP6-ERQ-In')
try {
    Enable-NetFirewallRule -Name $icmpRules -ErrorAction Stop
} catch {
    Write-Warning "Konnte ICMP-Regeln nicht aktivieren: $($_.Exception.Message). Versuche generisches Matching..."
    try {
        Get-NetFirewallRule |
            Where-Object { $_.Direction -eq 'Inbound' -and ($_.DisplayName -match 'Echo' -or $_.DisplayName -match 'ICMP') } |
            Enable-NetFirewallRule
    } catch {
        Write-Warning "Generisches Aktivieren der ICMP-Regeln ist ebenfalls fehlgeschlagen: $($_.Exception.Message)"
    }
}

# 3) Explorer-Ansicht: versteckte + Systemdateien anzeigen, Dateiendungen anzeigen
$advDefault = 'Registry::HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$advHKCU    = 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

foreach ($path in @($advDefault,$advHKCU)) {
    New-Item -Path $path -Force | Out-Null
    New-ItemProperty -Path $path -Name 'Hidden'          -PropertyType DWord -Value 1 -Force | Out-Null
    New-ItemProperty -Path $path -Name 'ShowSuperHidden' -PropertyType DWord -Value 1 -Force | Out-Null
    New-ItemProperty -Path $path -Name 'HideFileExt'     -PropertyType DWord -Value 0 -Force | Out-Null
}

# 4) Spracheingabe: Deutsch Schweiz (de-CH) fuer aktuellen Benutzer und neue Benutzer
try {
    $ll = New-WinUserLanguageList -Language de-CH
    Set-WinUserLanguageList -LanguageList $ll -Force
} catch {
    Write-Warning "Set-WinUserLanguageList nicht verfuegbar: $($_.Exception.Message)."
}

# 5) REGION, DATUM und ZEIT fuer die Schweiz (de-CH) fuer System, aktuellen Benutzer und Default-Benutzer

function Set-ChFormats-Registry {
    param(
        [Parameter(Mandatory)] [string] $Hive # 'HKCU' oder 'HKU\.DEFAULT'
    )
    $intlPath = "Registry::$Hive\Control Panel\International"
    New-Item -Path $intlPath -Force | Out-Null

    # Kerneinstellungen fuer de-CH
    $values = @{
        'LocaleName'     = 'de-CH'
        'Locale'         = '00000807'   # LCID de-CH
        'sShortDate'     = 'dd.MM.yyyy'
        'sLongDate'      = "dddd, d. MMMM yyyy"
        'sShortTime'     = 'HH:mm'
        'sTimeFormat'    = 'HH:mm:ss'
        'iTime'          = '1'          # 24h
        'iTLZero'        = '1'          # fuehrende Null
        'iFirstDayOfWeek'= '0'          # Montag
        'sList'          = ';'          # Listentrenner Schweiz
        'sDecimal'       = '.'          # Dezimaltrennzeichen
        'sThousand'      = "'"          # Tausendertrennzeichen
        'sCountry'       = 'Switzerland'
        'iCountry'       = '41'
    }
    foreach ($k in $values.Keys) {
        New-ItemProperty -Path $intlPath -Name $k -Value $values[$k] -PropertyType String -Force | Out-Null
    }

    # Geo (Schweiz)
    $geoPath = "Registry::$Hive\Control Panel\International\Geo"
    New-Item -Path $geoPath -Force | Out-Null
    New-ItemProperty -Path $geoPath -Name 'Name'   -Value 'CHE' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $geoPath -Name 'Nation' -Value '223' -PropertyType String -Force | Out-Null
}

# Bevorzugt: Windows-Cmdlets fuer Systemweite Einstellungen
try {
    Set-Culture -CultureInfo 'de-CH'
    Set-WinSystemLocale -SystemLocale 'de-CH'
    # GeoID 223 = Schweiz
    if (Get-Command Set-WinHomeLocation -ErrorAction SilentlyContinue) {
        Set-WinHomeLocation -GeoId 223
    }
    # Zeitzone Schweiz
    Set-TimeZone -Id 'W. Europe Standard Time'
} catch {
    Write-Warning "Konnte Systemkultur/Zeitzone nicht per Cmdlets setzen: $($_.Exception.Message). Wende Registry-Fallback an."
}

# Registry-Fallback fuer aktuellen Benutzer und Default-Benutzer
Set-ChFormats-Registry -Hive 'HKCU'
Set-ChFormats-Registry -Hive 'HKU\.DEFAULT'

# Diese Kopie uebernimmt aktuelle Benutzereinstellungen fuer Willkommen- und neue Benutzer
try {
    Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
} catch {
    Write-Warning "Copy-UserInternationalSettingsToSystem nicht verfuegbar: $($_.Exception.Message)"
}

Write-Host "Fertig: Verknuepfungen, Ping, Explorer-Ansichten, Tastaturliste de-CH, Region/Datum/Zeit Schweiz (System/HKCU/Default) gesetzt."
```
## Server und Client 
![Server-Client](/images/Server.png)