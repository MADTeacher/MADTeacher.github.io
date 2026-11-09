# Собирает контрольный лист из всех картинок каталога: подпись + миниатюра в ряд.
# Запуск: powershell -NoProfile -ExecutionPolicy Bypass -File tools\montage.ps1 -SrcDir <dir> -Out <file.png>
param(
  [Parameter(Mandatory = $true)][string]$SrcDir,
  [Parameter(Mandatory = $true)][string]$Out
)
Add-Type -AssemblyName System.Drawing

$files = Get-ChildItem -Path $SrcDir | Where-Object { $_.Extension -match '^\.(jpe?g|png)$' } | Sort-Object Name
$thumbH = 300
$gap = 12
$labelH = 24

$items = @()
foreach ($f in $files) {
  $img = [System.Drawing.Image]::FromFile($f.FullName)
  $w = [int]($img.Width * $thumbH / $img.Height)
  $items += @{ Img = $img; W = $w; Name = $f.BaseName }
}

$sumW = 0
foreach ($it in $items) { $sumW += $it.W + $gap }
$totalW = $sumW + $gap

$bmp = New-Object System.Drawing.Bitmap($totalW, ($thumbH + $labelH + $gap * 2))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)), 0, 0, $bmp.Width, $bmp.Height)

$labelFont = New-Object System.Drawing.Font('Consolas', 14, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$labelBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)

$x = $gap
foreach ($it in $items) {
  $g.DrawImage($it.Img, $x, ($gap + $labelH), $it.W, $thumbH)
  $g.DrawString($it.Name, $labelFont, $labelBrush, $x, $gap)
  $x += $it.W + $gap
}

$g.Dispose()
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "OK: $Out ($($items.Count) items)"
