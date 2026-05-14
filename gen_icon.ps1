$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-BotBitmap {
    param([int]$size)

    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    $r = [int]($size / 6)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0, 0, $r*2, $r*2, 180, 90)
    $path.AddArc($size-$r*2-1, 0, $r*2, $r*2, 270, 90)
    $path.AddArc($size-$r*2-1, $size-$r*2-1, $r*2, $r*2, 0, 90)
    $path.AddArc(0, $size-$r*2-1, $r*2, $r*2, 90, 90)
    $path.CloseAllFigures()

    $gradTop = [System.Drawing.Color]::FromArgb(255, 60, 120, 220)
    $gradBot = [System.Drawing.Color]::FromArgb(255, 20, 50, 130)
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Point(0, 0)),
        (New-Object System.Drawing.Point(0, $size)),
        $gradTop, $gradBot)
    $g.FillPath($bg, $path)

    $padX = [Math]::Max(2, [int]($size * 0.20))
    $headY = [int]($size * 0.32)
    $headW = $size - $padX*2
    $headH = [int]($headW * 0.78)
    $headBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 235, 245, 255))
    $headRad = [Math]::Max(1, [int]($size / 12))
    $headPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $headPath.AddArc($padX, $headY, $headRad*2, $headRad*2, 180, 90)
    $headPath.AddArc($padX+$headW-$headRad*2, $headY, $headRad*2, $headRad*2, 270, 90)
    $headPath.AddArc($padX+$headW-$headRad*2, $headY+$headH-$headRad*2, $headRad*2, $headRad*2, 0, 90)
    $headPath.AddArc($padX, $headY+$headH-$headRad*2, $headRad*2, $headRad*2, 90, 90)
    $headPath.CloseAllFigures()
    $g.FillPath($headBrush, $headPath)

    $antThick = [Math]::Max(1.0, $size / 16.0)
    $antPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(245, 235, 245, 255), $antThick)
    $cx = [int]($size / 2)
    $antTop = [Math]::Max(1, [int]($size * 0.08))
    $g.DrawLine($antPen, $cx, $headY, $cx, $antTop)
    $antR = [Math]::Max(2, [int]($size * 0.11))
    $g.FillEllipse([System.Drawing.Brushes]::Gold, $cx - $antR/2, $antTop - $antR, $antR, $antR)

    $eyeR = [Math]::Max(2, [int]($size * 0.12))
    $eyeY = $headY + [int]($headH * 0.28)
    $eyeBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 40, 200, 120))
    $g.FillEllipse($eyeBrush, $padX + [int]($headW * 0.22) - $eyeR/2, $eyeY, $eyeR, $eyeR)
    $g.FillEllipse($eyeBrush, $padX + [int]($headW * 0.78) - $eyeR/2, $eyeY, $eyeR, $eyeR)

    $mouthPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 30, 50, 110), [Math]::Max(1.0, $size/14.0))
    $mouthY = $headY + [int]($headH * 0.7)
    $g.DrawLine($mouthPen, $padX + [int]($headW * 0.32), $mouthY, $padX + [int]($headW * 0.68), $mouthY)

    $g.Dispose()
    return $bmp
}

$sizes = @(16, 32, 48)
$pngs  = @{}
foreach ($s in $sizes) {
    $bmp = New-BotBitmap -size $s
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngs[$s] = $ms.ToArray()
    $bmp.Dispose()
}

$out = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($out)

$bw.Write([uint16]0)
$bw.Write([uint16]1)
$bw.Write([uint16]$sizes.Count)

$offset = 6 + 16 * $sizes.Count
$ordered = $sizes | Sort-Object
foreach ($s in $ordered) {
    $len = $pngs[$s].Length
    $bw.Write([byte]$s)
    $bw.Write([byte]$s)
    $bw.Write([byte]0)
    $bw.Write([byte]0)
    $bw.Write([uint16]1)
    $bw.Write([uint16]32)
    $bw.Write([uint32]$len)
    $bw.Write([uint32]$offset)
    $offset += $len
}

foreach ($s in $ordered) {
    $bw.Write($pngs[$s])
}
$bw.Flush()

$dest = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'bot.ico'
[System.IO.File]::WriteAllBytes($dest, $out.ToArray())
Write-Output "Icon written: $dest ($([Math]::Round($out.Length/1KB,2)) KB, sizes: $($ordered -join ', '))"
