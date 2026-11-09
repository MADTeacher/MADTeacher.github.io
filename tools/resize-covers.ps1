# Нормализует обложки из assets/covers/src: сжимает по ширине до 480px, JPEG q85
# в assets/covers/<имя>.jpg. Запуск: powershell -NoProfile -ExecutionPolicy Bypass -File tools\resize-covers.ps1
Add-Type -AssemblyName System.Drawing

$src = Join-Path $PSScriptRoot "..\assets\covers\src"
$dst = Join-Path $PSScriptRoot "..\assets\covers"
$targetW = 480

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }

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

  $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
  $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]85)
  $outPath = Join-Path $dst ($f.BaseName + '.jpg')
  $bmp.Save($outPath, $jpegCodec, $ep)

  $bmp.Dispose()
  $img.Dispose()
  Write-Host "$($f.Name): ${w}x${h} -> ${nw}x${nh}  $( Split-Path -Leaf $outPath )"
}
