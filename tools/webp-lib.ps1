# Общие помощники для картинок: WebP-кодирование через внешний кодировщик
# (cwebp из winget-пакета Google.Libwebp, ImageMagick или ffmpeg – что найдётся;
# System.Drawing сам WebP не кодирует) и расчёт ThumbHash-хэша плейсхолдера
# (порт rgba_to_thumb_hash из https://github.com/evanw/thumbhash, лицензия MIT).
# Подключать точкой из других скриптов tools:
#   . (Join-Path $PSScriptRoot 'webp-lib.ps1')
Add-Type -AssemblyName System.Drawing

# Округление как Math.round в JS: половина – вверх. Наши значения неотрицательные,
# поэтому AwayFromZero совпадает с JS на всех вызовах ниже.
function Round-JS([double]$X) { [Math]::Round($X, [MidpointRounding]::AwayFromZero) }

# ---------- поиск внешнего WebP-кодировщика ----------

function Find-WebpTool {
  param([string[]]$Names, [string]$WingetGlob)
  foreach ($n in $Names) {
    $cmd = Get-Command $n -ErrorAction SilentlyContinue
    if ($cmd) { return @{ Tool = $n; Exe = $cmd.Source } }
  }
  if ($WingetGlob) {
    # бинарники winget-пакета Google.Libwebp могли не попасть в PATH текущей сессии
    $hit = Get-ChildItem -Path $WingetGlob -ErrorAction SilentlyContinue |
      Sort-Object FullName -Descending | Select-Object -First 1
    if ($hit) { return @{ Tool = $Names[0]; Exe = $hit.FullName } }
  }
  return $null
}

function Find-WebpEncoder {
  if ($script:WebpEncoder) { return $script:WebpEncoder }
  $t = Find-WebpTool @('cwebp') "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Google.Libwebp_*\libwebp-*\bin\cwebp.exe"
  if (-not $t) { $t = Find-WebpTool @('magick') $null }
  if (-not $t) { $t = Find-WebpTool @('ffmpeg') $null }
  if (-not $t) { throw 'WebP-кодировщик не найден. Поставьте один из: winget install Google.Libwebp (cwebp), ImageMagick, ffmpeg.' }
  $script:WebpEncoder = $t
  return $t
}

function Find-WebpDecoder {
  if ($script:WebpDecoder) { return $script:WebpDecoder }
  $t = Find-WebpTool @('dwebp') "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Google.Libwebp_*\libwebp-*\bin\dwebp.exe"
  if (-not $t) { $t = Find-WebpTool @('magick') $null }
  if (-not $t) { $t = Find-WebpTool @('ffmpeg') $null }
  if (-not $t) { throw 'WebP-декодировщик не найден. Поставьте один из: winget install Google.Libwebp (dwebp), ImageMagick, ffmpeg.' }
  $script:WebpDecoder = $t
  return $t
}

# ---------- кодирование и декодирование WebP ----------

# Bitmap -> WebP: сохраняем во временный PNG и кодируем внешней утилитой.
function Save-AsWebP {
  param([Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bmp, [Parameter(Mandatory = $true)][string]$Path, [int]$Quality = 85)
  $enc = Find-WebpEncoder
  $exe = $enc.Exe
  $tmpPng = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + '.png')
  # утилиты пишут прогресс в stderr – при ErrorActionPreference=Stop это не должно падать
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $Bmp.Save($tmpPng, [System.Drawing.Imaging.ImageFormat]::Png)
    $log = ''
    switch ($enc.Tool) {
      'cwebp'  { $log = & $exe -quiet -q $Quality $tmpPng -o $Path 2>&1 }
      'magick' { $log = & $exe $tmpPng -quality $Quality $Path 2>&1 }
      'ffmpeg' { $log = & $exe -y -loglevel error -i $tmpPng -c:v libwebp -quality $Quality $Path 2>&1 }
    }
    if (-not (Test-Path $Path)) { throw "WebP-кодировщик ($($enc.Tool)) не создал файл: $log" }
  } finally {
    $ErrorActionPreference = $prevEap
    Remove-Item $tmpPng -ErrorAction SilentlyContinue
  }
}

# Декодирует .webp во временный PNG (System.Drawing WebP не читает).
# Возвращает путь; удаляет вызвавший скрипт.
function ConvertFrom-WebPFile {
  param([Parameter(Mandatory = $true)][string]$Path)
  $dec = Find-WebpDecoder
  $exe = $dec.Exe
  $outPng = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + '.png')
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $log = ''
  switch ($dec.Tool) {
    'dwebp'  { $log = & $exe $Path -o $outPng 2>&1 }
    'magick' { $log = & $exe $Path $outPng 2>&1 }
    'ffmpeg' { $log = & $exe -y -loglevel error -i $Path $outPng 2>&1 }
  }
  $ErrorActionPreference = $prevEap
  if (-not (Test-Path $outPng)) { throw "Не удалось декодировать $Path ($($dec.Tool)): $log" }
  return $outPng
}

# ---------- ThumbHash ----------

# Уменьшает копию до MaxSide по большей стороне и отдаёт пиксели RGBA.
function Get-SmallRgba {
  param([Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bmp, [int]$MaxSide = 100)
  $w = $Bmp.Width; $h = $Bmp.Height
  $scale = [Math]::Min(1.0, $MaxSide / [double][Math]::Max($w, $h))
  $nw = [Math]::Max(1, [int](Round-JS ($w * $scale)))
  $nh = [Math]::Max(1, [int](Round-JS ($h * $scale)))

  $small = New-Object System.Drawing.Bitmap($nw, $nh, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($small)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($Bmp, 0, 0, $nw, $nh)
  $g.Dispose()

  $rect = New-Object System.Drawing.Rectangle(0, 0, $nw, $nh)
  $data = $small.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $bgra = New-Object byte[] ($nw * $nh * 4)
  [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bgra, 0, $bgra.Length)
  $small.UnlockBits($data)
  $small.Dispose()

  # GDI+ отдаёт BGRA – переставляем в RGBA
  $rgba = New-Object byte[] ($nw * $nh * 4)
  for ($i = 0; $i -lt $rgba.Length; $i += 4) {
    $rgba[$i] = $bgra[$i + 2]; $rgba[$i + 1] = $bgra[$i + 1]; $rgba[$i + 2] = $bgra[$i]; $rgba[$i + 3] = $bgra[$i + 3]
  }
  return @{ W = $nw; H = $nh; Rgba = $rgba }
}

# Порт rgbaToThumbHash: пиксели RGBA (без предварительного умножения на альфу)
# в картинку не больше 100x100 -> массив байтов хэша.
function ConvertTo-ThumbHash {
  param([Parameter(Mandatory = $true)][int]$W, [Parameter(Mandatory = $true)][int]$H, [Parameter(Mandatory = $true)][byte[]]$Rgba)
  if ($W -gt 100 -or $H -gt 100) { throw "${W}x${H} не влезает в 100x100" }
  $PI = [Math]::PI
  $n = $W * $H

  # средний цвет
  $avgR = 0.0; $avgG = 0.0; $avgB = 0.0; $avgA = 0.0
  for ($i = 0; $i -lt $n; $i++) {
    $j = $i * 4
    $alpha = $Rgba[$j + 3] / 255.0
    $avgR += $alpha / 255.0 * $Rgba[$j]
    $avgG += $alpha / 255.0 * $Rgba[$j + 1]
    $avgB += $alpha / 255.0 * $Rgba[$j + 2]
    $avgA += $alpha
  }
  if ($avgA -gt 0) { $avgR /= $avgA; $avgG /= $avgA; $avgB /= $avgA }

  $hasAlpha = [int]($avgA -lt $n)
  $lLimit = 7; if ($hasAlpha) { $lLimit = 5 } # при альфе меньше бит на яркость
  $lx = [Math]::Max(1, [int](Round-JS ($lLimit * $W / [Math]::Max($W, $H))))
  $ly = [Math]::Max(1, [int](Round-JS ($lLimit * $H / [Math]::Max($W, $H))))

  # RGBA -> LPQA (яркость, жёлтый–синий, красный–зелёный, альфа) поверх среднего цвета
  $lArr = New-Object double[] $n; $pArr = New-Object double[] $n
  $qArr = New-Object double[] $n; $aArr = New-Object double[] $n
  for ($i = 0; $i -lt $n; $i++) {
    $j = $i * 4
    $alpha = $Rgba[$j + 3] / 255.0
    $r = $avgR * (1 - $alpha) + $alpha / 255.0 * $Rgba[$j]
    $g = $avgG * (1 - $alpha) + $alpha / 255.0 * $Rgba[$j + 1]
    $b = $avgB * (1 - $alpha) + $alpha / 255.0 * $Rgba[$j + 2]
    $lArr[$i] = ($r + $g + $b) / 3
    $pArr[$i] = ($r + $g) / 2 - $b
    $qArr[$i] = $r - $g
    $aArr[$i] = $alpha
  }

  # DCT: постоянная составляющая и нормированные переменные
  function Encode-DctChannel([double[]]$Channel, [int]$CW, [int]$CH, [int]$NX, [int]$NY) {
    $dc = 0.0; $scale = 0.0
    $ac = New-Object System.Collections.Generic.List[double]
    $fx = New-Object double[] $CW
    for ($cy = 0; $cy -lt $NY; $cy++) {
      for ($cx = 0; ($cx * $NY) -lt ($NX * ($NY - $cy)); $cx++) {
        $f = 0.0
        for ($x = 0; $x -lt $CW; $x++) { $fx[$x] = [Math]::Cos($PI / $CW * $cx * ($x + 0.5)) }
        for ($y = 0; $y -lt $CH; $y++) {
          $fy = [Math]::Cos($PI / $CH * $cy * ($y + 0.5))
          $row = $y * $CW
          for ($x = 0; $x -lt $CW; $x++) { $f += $Channel[$row + $x] * $fx[$x] * $fy }
        }
        $f = $f / ($CW * $CH)
        if ($cx -or $cy) {
          $ac.Add($f)
          if ([Math]::Abs($f) -gt $scale) { $scale = [Math]::Abs($f) }
        } else { $dc = $f }
      }
    }
    if ($scale -gt 0) {
      for ($k = 0; $k -lt $ac.Count; $k++) { $ac[$k] = 0.5 + 0.5 / $scale * $ac[$k] }
    }
    return @{ Dc = $dc; Ac = $ac; Scale = $scale }
  }

  $lE = Encode-DctChannel $lArr $W $H ([Math]::Max(3, $lx)) ([Math]::Max(3, $ly))
  $pE = Encode-DctChannel $pArr $W $H 3 3
  $qE = Encode-DctChannel $qArr $W $H 3 3
  $aE = $null
  if ($hasAlpha) { $aE = Encode-DctChannel $aArr $W $H 5 5 }

  # заголовок: упаковка констант
  $isLandscape = [int]($W -gt $H)
  $header24 = [int](Round-JS (63 * $lE.Dc)) -bor ([int](Round-JS (31.5 + 31.5 * $pE.Dc)) -shl 6) -bor
    ([int](Round-JS (31.5 + 31.5 * $qE.Dc)) -shl 12) -bor ([int](Round-JS (31 * $lE.Scale)) -shl 18) -bor
    ($hasAlpha -shl 23)
  $lxy = $lx; if ($isLandscape) { $lxy = $ly }
  $header16 = $lxy -bor ([int](Round-JS (63 * $pE.Scale)) -shl 3) -bor ([int](Round-JS (63 * $qE.Scale)) -shl 9) -bor
    ($isLandscape -shl 15)

  $acStart = 5; if ($hasAlpha) { $acStart = 6 }
  $acs = New-Object System.Collections.Generic.List[object]
  $acs.Add($lE.Ac); $acs.Add($pE.Ac); $acs.Add($qE.Ac)
  if ($hasAlpha) { $acs.Add($aE.Ac) }
  $nibbles = 0; foreach ($one in $acs) { $nibbles += $one.Count }

  $hash = New-Object byte[] ($acStart + [int][Math]::Ceiling($nibbles / 2.0))
  $hash[0] = [byte]($header24 -band 255)
  $hash[1] = [byte](($header24 -shr 8) -band 255)
  $hash[2] = [byte](($header24 -shr 16) -band 255)
  $hash[3] = [byte]($header16 -band 255)
  $hash[4] = [byte](($header16 -shr 8) -band 255)
  if ($hasAlpha) {
    $hash[5] = [byte](([int](Round-JS (15 * $aE.Dc)) -bor ([int](Round-JS (15 * $aE.Scale)) -shl 4)) -band 255)
  }

  # переменные составляющие – по 4 бита, две штуки в байте
  $idx = 0
  foreach ($ac in $acs) {
    foreach ($f in $ac) {
      $pos = $acStart + [int][Math]::Floor($idx / 2.0)
      $hash[$pos] = [byte]($hash[$pos] -bor (([int](Round-JS (15 * $f))) -shl (($idx % 2) * 4)))
      $idx++
    }
  }
  return $hash
}

# Удобная обёртка: Bitmap -> base64-строка ThumbHash для data-thumbhash в index.html.
function ConvertTo-ThumbHashB64 {
  param([Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bmp)
  $s = Get-SmallRgba $Bmp 100
  $hash = ConvertTo-ThumbHash -W $s.W -H $s.H -Rgba $s.Rgba
  return [Convert]::ToBase64String($hash)
}
