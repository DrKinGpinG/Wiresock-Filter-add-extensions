# DisallowedApps-Block (deine exakte Liste)
$disallowedBlock = @"
# [Peer] WireSock extensions
#@ws:DisallowedApps = HERE ADD ALL THE APPS SEPARATED ONLY BY A COMA.EXE, TO ADD TO ALL CONFIGS.EXE,FOR EXAMPLE.EXE,YES ALSO SPACES IN FILENAME ARE ALLOWED.EXE
"@

# Alle .conf-Dateien im Ordner
$confFiles = Get-ChildItem -Path . -Filter "*.conf"

foreach ($file in $confFiles) {
    Write-Host "Verarbeite: $($file.Name)" -ForegroundColor Cyan
    
    # Inhalt als Array lesen
    $content = Get-Content $file.FullName
    
    # Prüfe ob Block schon existiert
    $hasBlock = $false
    foreach ($line in $content) {
        if ($line -match "#@ws:DisallowedApps") {
            $hasBlock = $true
            break
        }
    }
    
    if (-not $hasBlock) {
        # Block am Ende anhängen (nach letzter Zeile)
        $content += @(); $content += $disallowedBlock.Split("`n")
        Set-Content -Path $file.FullName -Value $content -Encoding UTF8
        Write-Host "✅ Erfolgreich hinzugefügt: $($file.Name)" -ForegroundColor Green
    } else {
        Write-Host "⏭️  Bereits vorhanden: $($file.Name)" -ForegroundColor Yellow
    }
}

Write-Host "`n✅ Fertig! Alle .conf-Dateien aktualisiert." -ForegroundColor Green
Write-Host "Importiere jetzt in WireSock: Preferences > Import Profiles" -ForegroundColor Cyan
