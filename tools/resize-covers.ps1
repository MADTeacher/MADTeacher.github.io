# Нормализует обложки из assets/covers/src: сжимает по ширине до 480px в WebP q85
# (assets/covers/<имя>.webp) и печатает data-thumbhash для вставки в index.html.
# Запуск: powershell -NoProfile -ExecutionPolicy Bypass -File tools\resize-covers.ps1
. (Join-Path $PSScriptRoot 'webp-lib.ps1')

$src = Join-Path $PSScriptRoot "..\assets\covers\src"
$dst = Join-Path $PSScriptRoot "..\assets\covers"
$targetW = 480

$hashes = @()
foreach ($f in Get-ChildItem $src | Where-Object { $_.Extension -match '^\.(jpe?g|png)$' }) {
  $img = [System.Drawing.Image]::FromFile($f.FullName)
  $w = $img.Width; $h = $img.Height

  if ($w -gt $targetW) {
    $nw = $targetW
    $nh = [int]($h * $targetW / $w)
  } else {
    $nw = $w; $nh = $h
  }

  $bmp = New-Object System.Drawing.Bitmap($nw, $nh)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($img, 0, 0, $nw, $nh)
  $g.Dispose()

  $outPath = Join-Path $dst ($f.BaseName + '.webp')
  Save-AsWebP $bmp $outPath 85

  $thumb = ConvertTo-ThumbHashB64 $bmp
  $hashes += [pscustomobject]@{ Name = $f.BaseName; Hash = $thumb }

  $kb = [Math]::Round((Get-Item $outPath).Length / 1kb, 1)
  Write-Host "$($f.Name): ${w}x${h} -> ${nw}x${nh}  $(Split-Path -Leaf $outPath)  ${kb} КБ"

  $bmp.Dispose()
  $img.Dispose()
}

# убираем jpeg-предшественников, для которых уже есть свежий .webp
foreach ($old in Get-ChildItem $dst -Filter '*.jpg' -ErrorAction SilentlyContinue) {
  if (Test-Path (Join-Path $dst ($old.BaseName + '.webp'))) {
    Remove-Item $old.FullName
    Write-Host "удалён старый $($old.Name)"
  }
}

Write-Host ''
Write-Host 'data-thumbhash для index.html (атрибут в <img> обложки):'
foreach ($x in $hashes) {
  Write-Host ("  {0,-14} {1}" -f $x.Name, $x.Hash)
}
