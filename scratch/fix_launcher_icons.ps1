Add-Type -AssemblyName System.Drawing

$densities = @{
    "mipmap-mdpi" = 48
    "mipmap-hdpi" = 72
    "mipmap-xhdpi" = 96
    "mipmap-xxhdpi" = 144
    "mipmap-xxxhdpi" = 192
}

$baseDir = "c:\Users\LENOVO\OneDrive\Documents\Thrive\android\app\src\main\res"

function Draw-ThriveLeaf($g, $size, $isRound) {
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    $cGreen = [System.Drawing.ColorTranslator]::FromHtml("#40983D")
    $cLightGreen = [System.Drawing.ColorTranslator]::FromHtml("#70B644")
    $cWhite = [System.Drawing.Color]::White
    $cSoftGreen = [System.Drawing.ColorTranslator]::FromHtml("#E1F0DF")

    # 1. Background
    $rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
    $brushBg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $cLightGreen, $cGreen, 45.0)

    if ($isRound) {
        $g.FillEllipse($brushBg, 1, 1, $size - 2, $size - 2)
    } else {
        # Squircle / rounded rect (Android 8+ style)
        $radius = [float]($size * 0.22)
        $d = $radius * 2
        $pathBg = New-Object System.Drawing.Drawing2D.GraphicsPath
        $pathBg.AddArc(1, 1, $d, $d, 180, 90)
        $pathBg.AddArc($size - 1 - $d, 1, $d, $d, 270, 90)
        $pathBg.AddArc($size - 1 - $d, $size - 1 - $d, $d, $d, 0, 90)
        $pathBg.AddArc(1, $size - 1 - $d, $d, $d, 90, 90)
        $pathBg.CloseFigure()
        $g.FillPath($brushBg, $pathBg)
        $pathBg.Dispose()
    }
    $brushBg.Dispose()

    # 2. Centered Leaf Geometry
    # Leaf spans roughly from center-left/bottom to center-right/top
    $scale = [float]($size / 100.0)
    $cx = [float]($size * 0.5)
    $cy = [float]($size * 0.5)

    # Coords relative to 100x100 box, centered around (50, 50)
    $brushLeaf = New-Object System.Drawing.SolidBrush($cWhite)
    $pathLeaf = New-Object System.Drawing.Drawing2D.GraphicsPath

    # Tip at (73, 27), Base at (27, 73)
    $tip = New-Object System.Drawing.PointF([float](73.0 * $scale), [float](27.0 * $scale))
    $base = New-Object System.Drawing.PointF([float](29.0 * $scale), [float](71.0 * $scale))

    # Top/Left curve: Base -> ctrl1(29, 41) -> ctrl2(49, 27) -> Tip
    $cTop1 = New-Object System.Drawing.PointF([float](29.0 * $scale), [float](41.0 * $scale))
    $cTop2 = New-Object System.Drawing.PointF([float](49.0 * $scale), [float](27.0 * $scale))
    $pathLeaf.AddBezier($base, $cTop1, $cTop2, $tip)

    # Bottom/Right curve: Tip -> ctrl1(71, 57) -> ctrl2(51, 71) -> Base
    $cBot1 = New-Object System.Drawing.PointF([float](71.0 * $scale), [float](57.0 * $scale))
    $cBot2 = New-Object System.Drawing.PointF([float](51.0 * $scale), [float](71.0 * $scale))
    $pathLeaf.AddBezier($tip, $cBot1, $cBot2, $base)

    $pathLeaf.CloseFigure()
    $g.FillPath($brushLeaf, $pathLeaf)
    $brushLeaf.Dispose()
    $pathLeaf.Dispose()

    # 3. Delicate Leaf Vein (Translucent Green)
    $penVein = New-Object System.Drawing.Pen($cGreen, [Math]::Max([float]1.8, [float](2.8 * $scale)))
    $penVein.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $penVein.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

    # Center vein arc from base (29,71) curving gently to near tip (68,32)
    $v1 = New-Object System.Drawing.PointF([float](29.0 * $scale), [float](71.0 * $scale))
    $v2 = New-Object System.Drawing.PointF([float](42.0 * $scale), [float](56.0 * $scale))
    $v3 = New-Object System.Drawing.PointF([float](54.0 * $scale), [float](44.0 * $scale))
    $v4 = New-Object System.Drawing.PointF([float](67.0 * $scale), [float](33.0 * $scale))
    $g.DrawBezier($penVein, $v1, $v2, $v3, $v4)
    $penVein.Dispose()

    # 4. Small Sprout / Seed Leaf accent at the stem base
    $brushSprout = New-Object System.Drawing.SolidBrush($cSoftGreen)
    $pathSprout = New-Object System.Drawing.Drawing2D.GraphicsPath
    $sp1 = New-Object System.Drawing.PointF([float](26.0 * $scale), [float](74.0 * $scale))
    $sp2 = New-Object System.Drawing.PointF([float](23.0 * $scale), [float](63.0 * $scale))
    $sp3 = New-Object System.Drawing.PointF([float](35.0 * $scale), [float](62.0 * $scale))
    $sp4 = New-Object System.Drawing.PointF([float](32.0 * $scale), [float](72.0 * $scale))
    $pathSprout.AddBezier($sp1, $sp2, $sp3, $sp4)
    $pathSprout.CloseFigure()
    $g.FillPath($brushSprout, $pathSprout)
    $brushSprout.Dispose()
    $pathSprout.Dispose()
}

foreach ($entry in $densities.GetEnumerator()) {
    $folderName = $entry.Key
    $size = $entry.Value
    $folderPath = Join-Path $baseDir $folderName

    # 1. Standard square/squircle icon
    $bmp1 = New-Object System.Drawing.Bitmap($size, $size)
    $g1 = [System.Drawing.Graphics]::FromImage($bmp1)
    Draw-ThriveLeaf $g1 $size $false
    $outPath1 = Join-Path $folderPath "ic_launcher.png"
    $bmp1.Save($outPath1, [System.Drawing.Imaging.ImageFormat]::Png)
    $g1.Dispose()
    $bmp1.Dispose()

    # 2. Round icon (for launchers that require roundIcon)
    $bmp2 = New-Object System.Drawing.Bitmap($size, $size)
    $g2 = [System.Drawing.Graphics]::FromImage($bmp2)
    Draw-ThriveLeaf $g2 $size $true
    $outPath2 = Join-Path $folderPath "ic_launcher_round.png"
    $bmp2.Save($outPath2, [System.Drawing.Imaging.ImageFormat]::Png)
    $g2.Dispose()
    $bmp2.Dispose()
}

Write-Output "Successfully generated perfect Thrive launcher and round icons!"

