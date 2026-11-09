# Генерирует avatar.jpg, og-image.png (1200x630 с фото), apple-touch-icon.png, favicon-32.png
# Вход: assets/photo_src.jpg (портрет 1706x2560, лицо ~x=940). Если его нет – og без фото.
# Запуск: powershell -NoProfile -ExecutionPolicy Bypass -File tools\make-og.ps1
Add-Type -AssemblyName System.Drawing

$root = Split-Path $PSScriptRoot -Parent
$outDir = Join-Path $root "assets"
$photo = Join-Path $outDir "photo_src.jpg"
$hasPhoto = Test-Path $photo

$bg = [System.Drawing.Color]::FromArgb(14, 17, 22)
$amber = [System.Drawing.Color]::FromArgb(242, 169, 59)
$white = [System.Drawing.Color]::FromArgb(230, 237, 243)
$muted = [System.Drawing.Color]::FromArgb(152, 162, 176)

$center = New-Object System.Drawing.StringFormat
$center.Alignment = [System.Drawing.StringAlignment]::Center
$center.LineAlignment = [System.Drawing.StringAlignment]::Center

$script:jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
function Save-Jpeg($bmp, $path, [long]$quality) {
  $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
  $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, $quality)
  $bmp.Save($path, $script:jpegCodec, $ep)
}

$src = $null
if ($hasPhoto) { $src = [System.Drawing.Image]::FromFile($photo) }

# ---------- avatar.jpg: квадрат 1500x1500 с центром лица (x=940), сверху без отступа ----------
if ($hasPhoto) {
  $side = 1500
  $cropX = 940 - [int]($side / 2)          # 190
  if ($cropX -lt 0) { $cropX = 0 }
  if (($cropX + $side) -gt $src.Width) { $cropX = $src.Width - $side }

  $bmp = New-Object System.Drawing.Bitmap(560, 560)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $dstRect = New-Object System.Drawing.Rectangle(0, 0, 560, 560)
  $srcRect = New-Object System.Drawing.Rectangle($cropX, 0, $side, $side)
  $g.DrawImage($src, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()
  Save-Jpeg $bmp (Join-Path $outDir 'avatar.jpg') 88
  $bmp.Dispose()
}

# ---------- portrait.jpg: полное фото без кропа, 520px по ширине ----------
if ($hasPhoto) {
  $pw = 520
  $ph = [int]($src.Height * $pw / $src.Width)
  $bmp = New-Object System.Drawing.Bitmap($pw, $ph)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($src, (New-Object System.Drawing.Rectangle(0, 0, $pw, $ph)))
  $g.Dispose()
  Save-Jpeg $bmp (Join-Path $outDir 'portrait.jpg') 86
  $bmp.Dispose()
}

# ---------- og-image.png 1200x630 ----------
$bmp = New-Object System.Drawing.Bitmap(1200, 630)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.FillRectangle((New-Object System.Drawing.SolidBrush($bg)), 0, 0, 1200, 630)

# портрет справа: исходник 1706x2560 почти точно совпадает по пропорциям с полосой 420x631
if ($hasPhoto) {
  $dstRect = New-Object System.Drawing.Rectangle(780, 0, 420, 631)
  $srcRect = New-Object System.Drawing.Rectangle(0, 0, $src.Width, $src.Height)
  $g.DrawImage($src, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
  # янтарная линия, отделяющая фото от текста
  $g.FillRectangle((New-Object System.Drawing.SolidBrush($amber)), 776, 0, 4, 630)
}

$g.FillRectangle((New-Object System.Drawing.SolidBrush($amber)), 80, 150, 8, 330)

$nameText = 'Станислав Чернышев'
$nameSize = 62
$nameFont = New-Object System.Drawing.Font('Segoe UI', $nameSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
# автоподбор: имя не должно наезжать на фото (доступно 640px до янтарной линии)
while (($g.MeasureString($nameText, $nameFont).Width -gt 640) -and ($nameSize -gt 30)) {
  $nameSize -= 2
  $nameFont.Dispose()
  $nameFont = New-Object System.Drawing.Font('Segoe UI', $nameSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
}
Write-Host "og name font: ${nameSize}px"
$subFont = New-Object System.Drawing.Font('Segoe UI', 29, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$monoFont = New-Object System.Drawing.Font('Consolas', 26, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)

$g.DrawString($nameText, $nameFont, (New-Object System.Drawing.SolidBrush($white)), 112, 168)
$g.DrawString('кандидат технических наук, доцент', $subFont, (New-Object System.Drawing.SolidBrush($muted)), 112, 286)
$g.DrawString('книги по Dart, Go, Flutter и AI-агентам', $subFont, (New-Object System.Drawing.SolidBrush($muted)), 112, 330)
$g.DrawString('MADTeacher', $monoFont, (New-Object System.Drawing.SolidBrush($amber)), 112, 400)
$g.Dispose()
$bmp.Save((Join-Path $outDir 'og-image.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# ---------- apple-touch-icon.png 180x180 ----------
$bmp = New-Object System.Drawing.Bitmap(180, 180)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.FillRectangle((New-Object System.Drawing.SolidBrush($bg)), 0, 0, 180, 180)
$braceFont = New-Object System.Drawing.Font('Consolas', 84, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString('{ }', $braceFont, (New-Object System.Drawing.SolidBrush($amber)), (New-Object System.Drawing.RectangleF(0, 0, 180, 180)), $center)
$g.Dispose()
$bmp.Save((Join-Path $outDir 'apple-touch-icon.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# ---------- favicon-32.png 32x32 ----------
$bmp = New-Object System.Drawing.Bitmap(32, 32)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
$g.FillRectangle((New-Object System.Drawing.SolidBrush($bg)), 0, 0, 32, 32)
$mFont = New-Object System.Drawing.Font('Consolas', 24, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString('M', $mFont, (New-Object System.Drawing.SolidBrush($amber)), (New-Object System.Drawing.RectangleF(0, 0, 32, 32)), $center)
$g.Dispose()
$bmp.Save((Join-Path $outDir 'favicon-32.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

if ($src) { $src.Dispose() }
Write-Host 'OK: avatar.jpg, og-image.png, apple-touch-icon.png, favicon-32.png'
