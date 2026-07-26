<#
    Minimal static file server used by the hosted-mode tests.

    The hosted build fetches assets/qpdf.wasm over the network, which a page
    opened from file:// cannot do, so the end-to-end test needs a real origin.

    Usage: powershell -ExecutionPolicy Bypass -File tests\serve.ps1 -Root docs -Port 8099
#>
param(
    [Parameter(Mandatory = $true)][string]$Root,
    [int]$Port = 8099
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path $Root).Path

$mime = @{
    '.html' = 'text/html; charset=utf-8'
    '.js'   = 'text/javascript; charset=utf-8'
    '.json' = 'application/json'
    '.wasm' = 'application/wasm'
    '.png'  = 'image/png'
    '.pdf'  = 'application/pdf'
    '.txt'  = 'text/plain; charset=utf-8'
    '.xml'  = 'application/xml'
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()
Write-Output "serving $Root on http://127.0.0.1:$Port/"

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $path = [System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')

        if ($path -eq '__shutdown') {
            $ctx.Response.StatusCode = 200
            $ctx.Response.Close()
            break
        }

        if ([string]::IsNullOrEmpty($path)) { $path = 'index.html' }
        $full = Join-Path $Root $path

        # Keep the server inside its root even if a request tries to climb out.
        if (-not $full.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path $full -PathType Leaf)) {
            $ctx.Response.StatusCode = 404
            $ctx.Response.Close()
            continue
        }

        $bytes = [System.IO.File]::ReadAllBytes($full)
        $ext = [System.IO.Path]::GetExtension($full).ToLower()
        $ctx.Response.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
        $ctx.Response.ContentLength64 = $bytes.Length
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $ctx.Response.Close()
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
