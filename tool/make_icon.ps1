$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$out = 'D:\Work\Code\Date_write\dist\diary.ico'

function New-Icon([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.Clear([System.Drawing.Color]::Transparent)

    $s = $size / 64.0

    # 纸感底色：暖白圆角方块
    $pad = 4 * $s
    $radius = 14 * $s
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = 2 * $radius
    $path.AddArc($pad, $pad, $d, $d, 180, 90)
    $path.AddArc($size - $pad - $d, $pad, $d, $d, 270, 90)
    $path.AddArc($size - $pad - $d, $size - $pad - $d, $d, $d, 0, 90)
    $path.AddArc($pad, $size - $pad - $d, $d, $d, 90, 90)
    $path.CloseFigure()

    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF(0, 0)),
        (New-Object System.Drawing.PointF(0, $size)),
        [System.Drawing.Color]::FromArgb(255, 199, 123, 74),
        [System.Drawing.Color]::FromArgb(255, 168, 90, 44))
    $g.FillPath($brush, $path)

    # 书本：两页 + 中缝
    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 250, 248, 245))
    $g.FillRectangle($white, (14 * $s), (19 * $s), (17 * $s), (26 * $s))
    $g.FillRectangle($white, (33 * $s), (19 * $s), (17 * $s), (26 * $s))

    $line = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(150, 199, 123, 74), [Math]::Max(1.0, 1.6 * $s))
    # 页面上的横线
    for ($i = 0; $i -lt 3; $i++) {
        $y = (25 + $i * 6) * $s
        $g.DrawLine($line, (17 * $s), $y, (28 * $s), $y)
        $g.DrawLine($line, (36 * $s), $y, (47 * $s), $y)
    }
    # 中缝
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 199, 123, 74))), (30.8 * $s), (19 * $s), (2.4 * $s), (26 * $s))

    $g.Dispose()
    $brush.Dispose(); $white.Dispose(); $line.Dispose(); $path.Dispose()
    return $bmp
}

# 多尺寸 ICO：手写 PNG-in-ICO 容器（Vista+ 全部支持 PNG 压缩）
$dir = Split-Path -Parent $out
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

$sizes = @(256, 128, 64, 48, 32, 16)
$entries = @()
foreach ($sz in $sizes) {
    $bmp = New-Icon $sz
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $entries += , @($bmp.Width, $ms.ToArray())
    $ms.Dispose()
    $bmp.Dispose()
}

$ms2 = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms2)
$bw.Write([UInt16]0)
$bw.Write([UInt16]1)
$bw.Write([UInt16]$entries.Count)
$offset = 6 + 16 * $entries.Count
foreach ($e in $entries) {
    $dim = if ($e[0] -ge 256) { 0 } else { $e[0] }
    $bw.Write([byte]$dim)
    $bw.Write([byte]$dim)
    $bw.Write([byte]0)
    $bw.Write([byte]0)
    $bw.Write([UInt16]1)
    $bw.Write([UInt16]32)
    $bw.Write([UInt32]$e[1].Length)
    $bw.Write([UInt32]$offset)
    $offset += $e[1].Length
}
foreach ($e in $entries) { $bw.Write($e[1]) }
$bw.Flush()
[System.IO.File]::WriteAllBytes($out, $ms2.ToArray())
$bw.Dispose()
$ms2.Dispose()

Write-Output ("icon written: {0} ({1:N0} bytes)" -f $out, (Get-Item $out).Length)