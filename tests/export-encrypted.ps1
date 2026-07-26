<#
    Builds a copy of the app that encrypts tests\sample.pdf and returns the
    result as base64, then writes it to tests\encrypted-sample.pdf so the file
    can be checked with tooling outside the browser.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

& powershell -ExecutionPolicy Bypass -File (Join-Path $root 'build.ps1') `
    -Output 'tests\export.html' -Append 'tests\export-encrypted.js' | Out-Null

$chrome = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

$uri = ([System.Uri](Join-Path $PSScriptRoot 'export.html')).AbsoluteUri
$profileDir = Join-Path $env:TEMP "pdfprotect-export-$PID"
$proc = Start-Process -FilePath $chrome -PassThru -WindowStyle Hidden -ArgumentList @(
    '--headless=new', '--disable-gpu', '--no-first-run',
    '--remote-debugging-port=9333', "--user-data-dir=$profileDir", $uri
)

try {
    $deadline = (Get-Date).AddSeconds(60)
    $payload = $null
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 400
        try { $targets = Invoke-RestMethod -Uri 'http://127.0.0.1:9333/json/list' -TimeoutSec 5 } catch { continue }
        $hit = $targets | Where-Object { $_.title -like 'RESULT|*' } | Select-Object -First 1
        if ($hit) { $payload = $hit.title.Substring(7); break }
    }

    if (-not $payload) { throw 'Timed out waiting for the encrypted result.' }
    if ($payload.StartsWith('ERROR')) { throw $payload }

    $out = Join-Path $PSScriptRoot 'encrypted-sample.pdf'
    [System.IO.File]::WriteAllBytes($out, [System.Convert]::FromBase64String($payload))
    Write-Output "Wrote $out ($((Get-Item $out).Length) bytes)"
}
finally {
    if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 300
    Remove-Item -Recurse -Force $profileDir -ErrorAction SilentlyContinue
    Remove-Item -Force (Join-Path $PSScriptRoot 'export.html') -ErrorAction SilentlyContinue
}
