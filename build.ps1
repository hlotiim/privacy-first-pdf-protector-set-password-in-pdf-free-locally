<#
    Builds the application from src\template.html in one of two modes.

    single (default)
        Inlines jQuery, the qpdf-wasm glue script and the qpdf WebAssembly
        binary into one self-contained HTML file that runs offline from
        file://. Roughly 1.9 MB, downloadable, works with no network at all.

    hosted
        Emits a small HTML page next to external assets. The 1.3 MB wasm binary
        is then fetched only when the visitor encrypts their first file, which
        keeps the initial page load light enough to rank well.

    Usage:
        powershell -ExecutionPolicy Bypass -File build.ps1
        powershell -ExecutionPolicy Bypass -File build.ps1 -Mode hosted -Output docs\index.html
        powershell -ExecutionPolicy Bypass -File build.ps1 -Template tests\test-template.html -Output tests\test.html
#>
param(
    [string]$Template = 'src\template.html',
    [string]$Output   = 'pdf-protect.html',

    [ValidateSet('single', 'hosted')]
    [string]$Mode = 'single',

    # Optional script appended to the built page, used by the end-to-end tests
    # to drive the real application without shipping test code in the artifact.
    [string]$Append = ''
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

$RepoUrl = 'https://github.com/hlotiim/privacy-first-pdf-protector-set-password-in-pdf-free-locally'
$SiteUrl = 'https://hlotiim.github.io/privacy-first-pdf-protector-set-password-in-pdf-free-locally/'

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

if ($Mode -eq 'single') {
    # No network origin is permitted at all, so the browser itself enforces
    # that nothing can be uploaded. 'wasm-unsafe-eval' compiles the qpdf
    # module, data: delivers the wasm binary, blob: returns finished PDFs.
    $csp = @'
<meta http-equiv="Content-Security-Policy" content="
  default-src 'none';
  script-src 'unsafe-inline' 'wasm-unsafe-eval';
  style-src 'unsafe-inline';
  img-src data:;
  connect-src data: blob:;
  form-action 'none';
  base-uri 'none';">
'@

    $libs = "<script>/*__JQUERY__*/</script>`n<script>/*__QPDF_JS__*/</script>`n<script>/*__ENGINE__*/</script>"
    $wasmUrl = 'data:application/octet-stream;base64,__QPDF_WASM_B64__'
    $headExtra = ''
    $pageUrl = $RepoUrl
}
else {
    # 'self' replaces the data: wasm delivery; still no third-party origin.
    $csp = @'
<meta http-equiv="Content-Security-Policy" content="
  default-src 'none';
  script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval';
  style-src 'unsafe-inline';
  img-src 'self' data:;
  connect-src 'self' blob:;
  form-action 'none';
  base-uri 'none';">
'@

    $libs = @'
<script src="assets/jquery.min.js"></script>
<script src="assets/qpdf.js"></script>
<script src="assets/engine.js"></script>
'@

    $wasmUrl = 'assets/qpdf.wasm'
    $pageUrl = $SiteUrl

    $headExtra = @"
<link rel="canonical" href="$SiteUrl">
<meta property="og:url" content="$SiteUrl">
<meta property="og:image" content="${SiteUrl}screenshot.png">
<meta name="twitter:image" content="${SiteUrl}screenshot.png">
<!--
  Search Console verification: paste the meta tag Google gives you on the line
  below, or drop its googleXXXX.html file into docs\ instead.
-->
"@
}

# String.Replace is used rather than -replace: the payloads contain regex
# metacharacters ($, \) that PowerShell's regex replacement would mangle.
$tokens = [ordered]@{
    '<!--__CSP__-->'        = $csp
    '<!--__LIBS__-->'       = $libs
    '<!--__HEAD_EXTRA__-->' = $headExtra
    '__WASM_URL__'          = $wasmUrl
    '__SITE_URL__'          = $pageUrl
    '/*__JQUERY__*/'        = (Read-Text 'vendor\jquery.min.js')
    '/*__QPDF_JS__*/'       = (Read-Text 'vendor\qpdf.js')
    '/*__ENGINE__*/'        = (Read-Text 'src\engine.js')
    '__QPDF_WASM_B64__'     = (Read-Base64 'vendor\qpdf.wasm')
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

$outPath = if ([System.IO.Path]::IsPathRooted($Output)) { $Output } else { Join-Path $root $Output }
$outDir = Split-Path $outPath -Parent
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

[System.IO.File]::WriteAllText($outPath, $html, (New-Object System.Text.UTF8Encoding $false))
$kb = [math]::Round((Get-Item $outPath).Length / 1KB)
Write-Output "Built $outPath ($Mode, $kb KB)"

if ($Mode -eq 'hosted') {
    $assets = Join-Path $outDir 'assets'
    New-Item -ItemType Directory -Force -Path $assets | Out-Null
    Copy-Item (Join-Path $root 'vendor\jquery.min.js') $assets -Force
    Copy-Item (Join-Path $root 'vendor\qpdf.js')       $assets -Force
    Copy-Item (Join-Path $root 'vendor\qpdf.wasm')     $assets -Force
    Copy-Item (Join-Path $root 'src\engine.js')        $assets -Force
    Write-Output "Copied assets to $assets"
}
