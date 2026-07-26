<#
    Runs tests\test.html in headless Chrome and reads the result back.

    The page publishes its result through document.title; Chrome's DevTools
    /json/list endpoint exposes that over plain HTTP, which avoids needing a
    WebSocket client just to read one string.
#>
param(
    [string]$Page = 'tests\test.html',
    [int]$Port = 9222,
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'

$chrome = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $chrome) { throw 'No Chrome or Edge installation found.' }

$pagePath = Join-Path $PSScriptRoot (Split-Path $Page -Leaf)
$uri = ([System.Uri]$pagePath).AbsoluteUri
$profileDir = Join-Path $env:TEMP "pdfprotect-test-profile-$PID"

$args = @(
    '--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
    "--remote-debugging-port=$Port", "--user-data-dir=$profileDir", $uri
)

Write-Output "Launching $(Split-Path $chrome -Leaf) on $uri"
$proc = Start-Process -FilePath $chrome -ArgumentList $args -PassThru -WindowStyle Hidden

try {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $result = $null
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500
        try {
            $targets = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json/list" -TimeoutSec 5
        } catch { continue }
        $hit = $targets | Where-Object { $_.title -like 'RESULT|*' } | Select-Object -First 1
        if ($hit) { $result = $hit.title; break }
    }

    if (-not $result) { throw "Timed out after $TimeoutSeconds s waiting for the page to report a result." }

    $body = $result.Substring('RESULT|'.Length)
    $lines = $body -split ' \|\| '
    $lines | ForEach-Object { Write-Output $_ }

    if ($lines -match '^FAIL' -or $lines -match '^EXCEPTION') { exit 1 }
    exit 0
}
finally {
    if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 300
    Remove-Item -Recurse -Force $profileDir -ErrorAction SilentlyContinue
}
