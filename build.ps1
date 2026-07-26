<#
    Inlines jQuery, the qpdf-wasm glue script and the qpdf WebAssembly binary
    into a single self-contained HTML file that runs offline from file://.

    Usage:
        powershell -ExecutionPolicy Bypass -File build.ps1
        powershell -ExecutionPolicy Bypass -File build.ps1 -Template tests\test-template.html -Output tests\test.html
#>
param(
    [string]$Template = 'src\template.html',
    [string]$Output   = 'pdf-protect.html',
    # Optional script appended to the built page, used by the end-to-end test to
    # drive the real application without shipping test code in the deliverable.
    [string]$Append   = ''
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

function Read-Text([string]$relative) {
    [System.IO.File]::ReadAllText((Join-Path $root $relative))
}

function Read-Base64([string]$relative) {
    [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes((Join-Path $root $relative)))
}

$html = Read-Text $Template

if ($Append) {
    $html += "`n<script>`n" + (Read-Text $Append) + "`n</script>`n"
}

# String.Replace is used rather than -replace: the payloads contain regex
# metacharacters ($, \) that PowerShell's regex replacement would mangle.
$tokens = [ordered]@{
    '/*__JQUERY__*/'    = (Read-Text 'vendor\jquery.min.js')
    '/*__QPDF_JS__*/'   = (Read-Text 'vendor\qpdf.js')
    '/*__ENGINE__*/'    = (Read-Text 'src\engine.js')
    '__QPDF_WASM_B64__' = (Read-Base64 'vendor\qpdf.wasm')
}

$samplePath = Join-Path $root 'tests\sample.pdf'
if (Test-Path $samplePath) {
    $tokens['__SAMPLE_PDF_B64__'] = (Read-Base64 'tests\sample.pdf')
}

foreach ($key in $tokens.Keys) {
    if ($html.Contains($key)) {
        $html = $html.Replace($key, $tokens[$key])
    }
}

foreach ($key in $tokens.Keys) {
    if ($html.Contains($key)) { throw "Token $key survived substitution." }
}

$outPath = Join-Path $root $Output
[System.IO.File]::WriteAllText($outPath, $html, (New-Object System.Text.UTF8Encoding $false))
$kb = [math]::Round((Get-Item $outPath).Length / 1KB)
Write-Output "Built $outPath ($kb KB)"
