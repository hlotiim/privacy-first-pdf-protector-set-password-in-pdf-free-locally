<#
    Builds the app and runs both suites:
      1. engine tests  - qpdf argument building and encryption round trips
      2. end-to-end    - drives the real built page in headless Chrome

    Usage: powershell -ExecutionPolicy Bypass -File run-tests.ps1
#>
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$failed = $false

function Invoke-Step([string]$Title, [scriptblock]$Body) {
    Write-Output ''
    Write-Output "=== $Title ==="
    & $Body
    if ($LASTEXITCODE -ne 0) { $script:failed = $true }
}

& powershell -ExecutionPolicy Bypass -File (Join-Path $root 'tests\make-sample-pdf.ps1')
& powershell -ExecutionPolicy Bypass -File (Join-Path $root 'build.ps1')

Invoke-Step 'Engine tests' {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $root 'build.ps1') `
        -Template 'tests\test-template.html' -Output 'tests\test.html'
    & powershell -ExecutionPolicy Bypass -File (Join-Path $root 'tests\run-tests.ps1') -Page 'tests\test.html'
}

Invoke-Step 'End-to-end tests' {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $root 'build.ps1') `
        -Output 'tests\smoke.html' -Append 'tests\smoke.js'
    & powershell -ExecutionPolicy Bypass -File (Join-Path $root 'tests\run-tests.ps1') -Page 'tests\smoke.html' -Port 9223
}

Remove-Item -Force (Join-Path $root 'tests\test.html'), (Join-Path $root 'tests\smoke.html') -ErrorAction SilentlyContinue

Write-Output ''
if ($failed) { Write-Output 'SOME TESTS FAILED'; exit 1 }
Write-Output 'ALL TESTS PASSED'
exit 0
