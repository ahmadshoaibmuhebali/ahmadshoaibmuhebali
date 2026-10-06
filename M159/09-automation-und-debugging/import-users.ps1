Import-Module ActiveDirectory

$csvPath = "C:\Temp\mitarbeiter.csv"
$users = Import-Csv $csvPath -Delimiter ","

# Passwort mit Sonderzeichen fuer AD-Richtlinien
$SecurePassword = ConvertTo-SecureString "Schule123!" -AsPlainText -Force

foreach ($row in $users) {
    $vorname   =$row.Vorname
    $nachname  =$row.Nachname
    $abteilung =$row.Abteilung

    # sAMAccountName generieren (Erster Buchstabe Vorname + Nachname in Kleinbuchstaben)
    $sAMAccountName = ($vorname.Substring(0,1) +$nachname).ToLower()
    
    # Pfade und UPN f\Uffffffff.cloud-ah.local[cite: 2]
    $userPrincipalName = "$sAMAccountName@dc1.cloud-ah.local"
    $targetOU = "OU=$abteilung,OU=User,DC=dc1,DC=cloud-ah,DC=local"
    $displayName = "$vorname$nachname"

    Write-Host "Erstelle User: $sAMAccountName in OU:$targetOU"

    # User erstellen
    New-ADUser -Name $displayName `
               -GivenName $vorname `
               -Surname $nachname `
               -SamAccountName $sAMAccountName `
               -UserPrincipalName $userPrincipalName `
               -Path $targetOU `
               -AccountPassword $SecurePassword

    # User aktivieren
    Enable-ADAccount -Identity $sAMAccountName
}