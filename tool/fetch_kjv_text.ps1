# Regenerates the bundled KJV text assets in assets/kjv/.
#
# Clones github.com/aruljohn/Bible-kjv (public-domain KJV as JSON, one file
# per book) and emits one minified asset per book, named by book index
# (0.json = Genesis ... 65.json = Revelation). Each asset is a JSON array of
# chapters, each chapter an array of verse strings (verse numbers implicit).
#
# Usage:  powershell -ExecutionPolicy Bypass -File tool\fetch_kjv_text.ps1
#         [-Source <existing-clone-path>]

param([string]$Source = '')

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$outDir = Join-Path $repoRoot 'assets\kjv'

$work = $Source
$cloned = $false
if (-not $work) {
    $work = Join-Path $env:TEMP "kjv-text-$([guid]::NewGuid().ToString('n'))"
    git clone --depth 1 https://github.com/aruljohn/Bible-kjv $work
    $cloned = $true
}

try {
    $books = Get-Content "$work\Books.json" -Raw | ConvertFrom-Json
    if ($books.Count -ne 66) { throw "Expected 66 books, got $($books.Count)" }

    New-Item -ItemType Directory -Force $outDir | Out-Null

    # Chapter counts per book, canonical order, to validate the source.
    $expected = @(50, 40, 27, 36, 34, 24, 21, 4, 31, 24, 22, 25, 29, 36, 10,
        13, 10, 42, 150, 31, 12, 8, 66, 52, 5, 48, 12, 14, 3, 9, 1, 4, 7, 3,
        3, 3, 2, 14, 4, 28, 16, 24, 21, 28, 16, 16, 13, 6, 6, 4, 4, 5, 3, 6,
        4, 3, 1, 13, 5, 5, 3, 5, 1, 1, 1, 22)

    $totalVerses = 0
    for ($i = 0; $i -lt 66; $i++) {
        $file = Join-Path $work (($books[$i] -replace ' ', '') + '.json')
        $data = Get-Content $file -Raw | ConvertFrom-Json
        if ($data.chapters.Count -ne $expected[$i]) {
            throw "$($books[$i]): expected $($expected[$i]) chapters, got $($data.chapters.Count)"
        }
        $chapters = @()
        foreach ($ch in $data.chapters) {
            $verses = @($ch.verses | ForEach-Object { $_.text })
            if ($verses.Count -lt 1) { throw "$($books[$i]) ch $($ch.chapter): no verses" }
            $totalVerses += $verses.Count
            $chapters += , $verses
        }
        $json = ConvertTo-Json $chapters -Depth 3 -Compress
        [System.IO.File]::WriteAllText((Join-Path $outDir "$i.json"), $json)
        Write-Host "$i.json  $($books[$i])  ($($data.chapters.Count) chapters)"
    }
    Write-Host "Wrote 66 assets to $outDir ($totalVerses verses)"
    if ($totalVerses -ne 31102) {
        Write-Warning "Expected 31,102 KJV verses, got $totalVerses"
    }
}
finally {
    if ($cloned) { Remove-Item $work -Recurse -Force }
}
