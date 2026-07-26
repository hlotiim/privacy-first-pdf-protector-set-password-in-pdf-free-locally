# Generates a minimal but structurally valid PDF (correct xref offsets) for testing.
$ErrorActionPreference = 'Stop'

$content = "BT /F1 24 Tf 20 100 Td (Hello PDF) Tj ET"
$streamObj = "<</Length $($content.Length)>>`nstream`n$content`nendstream"

$objects = New-Object System.Collections.ArrayList
[void]$objects.Add("<</Type/Catalog/Pages 2 0 R>>")
[void]$objects.Add("<</Type/Pages/Kids[3 0 R]/Count 1>>")
[void]$objects.Add("<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>")
[void]$objects.Add($streamObj)
[void]$objects.Add("<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>")

$sb = New-Object System.Text.StringBuilder
[void]$sb.Append("%PDF-1.4`n")

$offsets = New-Object System.Collections.ArrayList
for ($i = 0; $i -lt $objects.Count; $i++) {
    [void]$offsets.Add($sb.Length)
    [void]$sb.Append("$($i + 1) 0 obj`n$($objects[$i])`nendobj`n")
}

$size = $objects.Count + 1
$xrefPos = $sb.Length
[void]$sb.Append("xref`n0 $size`n")
[void]$sb.Append("0000000000 65535 f `n")
foreach ($o in $offsets) {
    [void]$sb.Append(("{0:D10} 00000 n `n" -f $o))
}
[void]$sb.Append("trailer`n<</Size $size/Root 1 0 R>>`nstartxref`n$xrefPos`n%%EOF`n")

$bytes = [System.Text.Encoding]::ASCII.GetBytes($sb.ToString())
$out = Join-Path $PSScriptRoot 'sample.pdf'
[System.IO.File]::WriteAllBytes($out, $bytes)
Write-Output "Wrote $out ($($bytes.Length) bytes, $($objects.Count) objects)"
