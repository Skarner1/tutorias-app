Add-Type -AssemblyName System.Drawing

$size = 1024
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gfx.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

$primary = [System.Drawing.Color]::FromArgb(255, 0, 86, 210)
$accent  = [System.Drawing.Color]::FromArgb(255, 0, 194, 255)
$white   = [System.Drawing.Color]::White

$rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
$gradBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    $primary,
    $accent,
    [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
)
$gfx.FillRectangle($gradBrush, $rect)

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
$softBrush  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 255, 255, 255))

$mainStar  = New-StarPolygon -cx 470 -cy 470 -outer 310
$rightStar = New-StarPolygon -cx 760 -cy 360 -outer 130
$smallStar = New-StarPolygon -cx 720 -cy 700 -outer 90

$gfx.FillPolygon($whiteBrush, $mainStar)
$gfx.FillPolygon($whiteBrush, $rightStar)
$gfx.FillPolygon($softBrush,  $smallStar)

$outPath = Join-Path $PSScriptRoot 'app_icon.png'
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

$gfx.Dispose()
$bmp.Dispose()
"Generated: $outPath"