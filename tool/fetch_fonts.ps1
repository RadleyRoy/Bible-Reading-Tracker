# Downloads the reader font families bundled with the app.
#
# Fetches static Regular (400) and Bold (700) TTFs for each family from the
# Google Fonts css2 API (requesting without a browser user agent returns
# plain TTF URLs) plus each family's OFL license text, into
# assets/fonts/<Family>/. All families are SIL Open Font License.
#
# Usage:  powershell -ExecutionPolicy Bypass -File tool\fetch_fonts.ps1

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent

# family display name -> css2 family query name, OFL dir at github/google/fonts
$families = @(
    @{ name = 'Lora';        query = 'Lora';         ofl = 'lora' }
    @{ name = 'Merriweather'; query = 'Merriweather'; ofl = 'merriweather' }
    @{ name = 'EBGaramond';  query = 'EB Garamond';  ofl = 'ebgaramond' }
    @{ name = 'OpenSans';    query = 'Open Sans';    ofl = 'opensans' }
)

foreach ($f in $families) {
    $dir = Join-Path $repoRoot "assets\fonts\$($f.name)"
    New-Item -ItemType Directory -Force $dir | Out-Null

    $q = [uri]::EscapeDataString($f.query)
    $css = curl.exe -s "https://fonts.googleapis.com/css2?family=$q`:wght@400;700"
    $urls = [regex]::Matches($css, 'url\((https://[^)]+\.ttf)\)') |
        ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
    if ($urls.Count -lt 2) { throw "$($f.name): expected 2 TTF urls, got $($urls.Count)" }

    $weights = @('Regular', 'Bold')
    for ($i = 0; $i -lt 2; $i++) {
        $out = Join-Path $dir "$($f.name)-$($weights[$i]).ttf"
        curl.exe -sS -L -o $out $urls[$i]
        Write-Host "$($f.name)-$($weights[$i]).ttf  $([math]::Round((Get-Item $out).Length/1KB)) KB"
    }

    curl.exe -sS -L -o (Join-Path $dir 'OFL.txt') `
        "https://raw.githubusercontent.com/google/fonts/main/ofl/$($f.ofl)/OFL.txt"
}
Write-Host "Done."
