# Собирает контрольный лист из всех картинок каталога: подпись + миниатюра в ряд.
# Понимает jpg/png и webp – последний декодирует во временный PNG внешней утилитой.
# Запуск: powershell -NoProfile -ExecutionPolicy Bypass -File tools\montage.ps1 -SrcDir <dir> -Out <file.png>
param(
  [Parameter(Mandatory = $true)][string]$SrcDir,
  [Parameter(Mandatory = $true)][string]$Out
)
. (Join-Path $PSScriptRoot 'webp-lib.ps1')

$files = Get-ChildItem -Path $SrcDir | Where-Object { $_.Extension -match '^\.(jpe?g|png|webp)$' } | Sort-Object Name
$thumbH = 300
$gap = 12
$labelH = 24

$items = @()
$streams = @() # MemoryStream-ы webp-картинок должны жить, пока живы загруженные из них Bitmap-ы
foreach ($f in $files) {
  if ($f.Extension -eq '.webp') {
    $tmpPng = ConvertFrom-WebPFile $f.FullName
    $ms = New-Object System.IO.MemoryStream(, [System.IO.File]::ReadAllBytes($tmpPng))
    Remove-Item $tmpPng
    $img = [System.Drawing.Image]::FromStream($ms)
    $streams += $ms
  } else {
    $img = [System.Drawing.Image]::FromFile($f.FullName)
  }
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
foreach ($ms in $streams) { $ms.Dispose() }
Write-Host "OK: $Out ($($items.Count) items)"
