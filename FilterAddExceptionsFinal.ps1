$templatePath = Join-Path $PSScriptRoot 'template.conf'
$utf8NoBom    = [System.Text.UTF8Encoding]::new($false)

function Normalize-Lf {
    param([string]$Text)
    return (($Text -replace "`r`n", "`n") -replace "`r", "`n")
}

$templateRaw = [System.IO.File]::ReadAllText($templatePath, $utf8NoBom)
$template    = Normalize-Lf $templateRaw

# Interface-Block aus template.conf ist OPTIONAL
$ifaceMatch = [regex]::Match(
    $template,
    '(?ms)^# \[Interface\] WireSock extensions\n.*?^#@ws:Jd\s*=\s*\d+\s*$'
)

# Peer-Block aus template.conf bleibt PFLICHT
$peerMatch = [regex]::Match(
    $template,
    '(?ms)^# \[Peer\] WireSock extensions\n(?:.*(?:\n|$))*'
)

if (-not $peerMatch.Success) {
    throw "Peer-Extensions in template.conf nicht gefunden."
}

$ifaceExt = if ($ifaceMatch.Success) { $ifaceMatch.Value.TrimEnd() } else { $null }
$peerExt  = $peerMatch.Value.TrimEnd()

$extraBlock = @'
# [Interface] WireSock extensions
#@ws:BypassLanTraffic = true
#@ws:VirtualAdapterMode = true

# Amnezia WG extension

Jc = 3
Jmin = 50
Jmax = 1000
#Jd is a WireSock-specific extension.
#It defines the handshake delay in milliseconds (0-200). The default value is 0.
#@ws:Jd = 0
'@ | ForEach-Object { Normalize-Lf $_ }

Get-ChildItem -Path $PSScriptRoot -Filter '*.conf' |
Where-Object { $_.Name -ne 'template.conf' } |
ForEach-Object {

    $path = $_.FullName
    $cRaw = [System.IO.File]::ReadAllText($path, $utf8NoBom)
    $c    = Normalize-Lf $cRaw

    # Vorhandene Peer-Extensions entfernen
    $c = [regex]::Replace(
        $c,
        '(?ms)\n?# \[Peer\] WireSock extensions\n(?:.*(?:\n|$))*$',
        ''
    )

    # Optional: vorhandenen Interface-Block entfernen, aber nur wenn template.conf einen liefert
    if ($ifaceExt) {
        $c = [regex]::Replace(
            $c,
            '(?ms)\n?# \[Interface\] WireSock extensions\n.*?^#@ws:Jd\s*=\s*\d+\s*$',
            ''
        )
    }

    # Prüfen, ob Zusatzblock bereits vorhanden ist
    $hasBypassLanTraffic   = $c -match '(?m)^\#@ws:BypassLanTraffic\s*=\s*true\s*$'
    $hasVirtualAdapterMode = $c -match '(?m)^\#@ws:VirtualAdapterMode\s*=\s*true\s*$'
    $hasAmneziaJc          = $c -match '(?m)^Jc\s*=\s*3\s*$'
    $hasAmneziaJmin        = $c -match '(?m)^Jmin\s*=\s*50\s*$'
    $hasAmneziaJmax        = $c -match '(?m)^Jmax\s*=\s*1000\s*$'
    $hasWsJd               = $c -match '(?m)^\#@ws:Jd\s*=\s*0\s*$'

    $extraAlreadyExists = (
        $hasBypassLanTraffic -and
        $hasVirtualAdapterMode -and
        $hasAmneziaJc -and
        $hasAmneziaJmin -and
        $hasAmneziaJmax -and
        $hasWsJd
    )

    if ($c -match '(?m)^\[Peer\]\s*$') {

        $insertParts = @()

        if ($ifaceExt) {
            $insertParts += $ifaceExt.TrimEnd()
        }

        if (-not $extraAlreadyExists) {
            $insertParts += $extraBlock.TrimEnd()
        }

        if ($insertParts.Count -gt 0) {
            $insertText = ($insertParts -join "`n`n")
            $c = [regex]::Replace(
                $c,
                '(?m)^\[Peer\]\s*$',
                ($insertText + "`n`n[Peer]"),
                1
            )
        }
    }
    else {
        throw "[$($_.Name)] Kein [Peer]-Block gefunden."
    }

    # Peer-Extensions genau einmal ans Ende anhängen
    $c = $c.TrimEnd() + "`n`n" + $peerExt + "`n"

    # LF + UTF-8 ohne BOM
    [System.IO.File]::WriteAllText($path, $c, $utf8NoBom)

    Write-Host "✅ $($_.Name)" -ForegroundColor Green
}

Write-Host "`nFertig." -ForegroundColor Green