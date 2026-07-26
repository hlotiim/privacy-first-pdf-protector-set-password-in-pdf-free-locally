<#
    End-to-end test for the hosted build.

    The single-file build is exercised from file://, but the hosted build pulls
    assets/qpdf.wasm over the network on first use, so it can only be verified
    against a real origin. This builds it into a scratch directory, serves that
    over HTTP, and drives it with the same smoke test the single file uses.
#>
param(
    [int]$Port = 8099,
    [int]$DebugPort = 9223
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $env:TEMP "pdfprotect-hosted-$PID"

Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $stage | Out-Null

$server = $null
try {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $root 'build.ps1') `
        -Mode hosted -Output (Join-Path $stage 'index.html') -Append 'tests\smoke.js'
    if ($LASTEXITCODE -ne 0) { throw 'Hosted build failed.' }

    # Windows PowerShell joins an ArgumentList array with plain spaces and adds
    # no quoting, so the paths here are quoted by hand to survive the space in
    # the repository directory name.
    $serveArgs = '-ExecutionPolicy Bypass -File "{0}" -Root "{1}" -Port {2}' -f `
        (Join-Path $PSScriptRoot 'serve.ps1'), $stage, $Port
    $server = Start-Process -FilePath 'powershell' -PassThru -WindowStyle Hidden -ArgumentList $serveArgs

    # Give the listener a moment to bind before Chrome asks for the page.
    $up = $false
    foreach ($i in 1..20) {
        Start-Sleep -Milliseconds 250
        try {
            Invoke-WebRequest -Uri "http://127.0.0.1:$Port/index.html" -TimeoutSec 2 -UseBasicParsing | Out-Null
            $up = $true; break
        } catch { }
    }
    if (-not $up) { throw "Static server did not come up on port $Port." }

    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'run-tests.ps1') `
        -Page "http://127.0.0.1:$Port/index.html" -Port $DebugPort
    exit $LASTEXITCODE
}
finally {
    try { Invoke-WebRequest -Uri "http://127.0.0.1:$Port/__shutdown" -TimeoutSec 2 -UseBasicParsing | Out-Null } catch { }
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
    Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
}
