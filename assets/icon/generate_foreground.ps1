Add-Type -AssemblyName System.Drawing

$size = 1024
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gfx.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# Transparent background (default for new Bitmap is ARGB(0,0,0,0))
$gfx.Clear([System.Drawing.Color]::Transparent)

$white  = [System.Drawing.Color]::White
$soft   = [System.Drawing.Color]::FromArgb(190, 255, 255, 255)

function New-StarPolygon {
    param([double]$cx, [double]$cy, [double]$outer, [double]$innerRatio = 0.28)
    $inner = $outer * $innerRatio
    $pts = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt 8; $i++) {
        $angleDeg = -90 + ($i * 45)
        $angleRad = [Math]::PI * $angleDeg / 180.0
        $r = if ($i % 2 -eq 0) { $outer } else { $inner }
        $x = $cx + $r * [Math]::Cos($angleRad)
        $y = $cy + $r * [Math]::Sin($angleRad)
        [void]$pts.Add((New-Object System.Drawing.PointF($x, $y)))
    }
    return ,$pts.ToArray([System.Drawing.PointF])
}

$whiteBrush = New-Object System.Drawing.SolidBrush($white)
$softBrush  = New-Object System.Drawing.SolidBrush($soft)

# Android adaptive icons: safe zone is the center ~66% of canvas.
# Center coords around (512,512) and keep within radius ~330 from center.
$mainStar  = New-StarPolygon -cx 470 -cy 500 -outer 220
$rightStar = New-StarPolygon -cx 680 -cy 400 -outer 95
$smallStar = New-StarPolygon -cx 650 -cy 660 -outer 65

$gfx.FillPolygon($whiteBrush, $mainStar)
$gfx.FillPolygon($whiteBrush, $rightStar)
$gfx.FillPolygon($softBrush,  $smallStar)

$outPath = Join-Path $PSScriptRoot 'app_icon_foreground.png'
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

$gfx.Dispose()
$bmp.Dispose()
"Generated: $outPath"