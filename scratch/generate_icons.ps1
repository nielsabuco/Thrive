Add-Type -AssemblyName System.Drawing

$densities = @{
    "mipmap-mdpi" = 48
    "mipmap-hdpi" = 72
    "mipmap-xhdpi" = 96
    "mipmap-xxhdpi" = 144
    "mipmap-xxxhdpi" = 192
}

$baseDir = "c:\Users\LENOVO\OneDrive\Documents\Thrive\android\app\src\main\res"

foreach ($entry in $densities.GetEnumerator()) {
    $name = $entry.Key
    $size = $entry.Value

    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    # Background Thrive Green Circle
    $cGreen = [System.Drawing.ColorTranslator]::FromHtml("#40983D")
    $brushGreen = New-Object System.Drawing.SolidBrush($cGreen)
    $g.FillEllipse($brushGreen, 1, 1, $size - 2, $size - 2)

    # Stylised Thrive eco sprout in white & light green
    $brushWhite = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $cLight = [System.Drawing.ColorTranslator]::FromHtml("#E1F0DF")
    $brushLight = New-Object System.Drawing.SolidBrush($cLight)

    $scale = [float]($size / 100.0)

    # Main leaf (upper right)
    $path1 = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p1 = New-Object System.Drawing.PointF([float](75.0 * $scale), [float](22.0 * $scale))
    $p2 = New-Object System.Drawing.PointF([float](36.0 * $scale), [float](36.0 * $scale))
    $p3 = New-Object System.Drawing.PointF([float](36.0 * $scale), [float](65.0 * $scale))
    $p4 = New-Object System.Drawing.PointF([float](66.0 * $scale), [float](55.0 * $scale))
    $path1.AddBezier($p1, $p2, $p3, $p4)
    $p5 = New-Object System.Drawing.PointF([float](75.0 * $scale), [float](40.0 * $scale))
    $p6 = New-Object System.Drawing.PointF([float](78.0 * $scale), [float](30.0 * $scale))
    $path1.AddBezier($p4, $p5, $p6, $p1)
    $path1.CloseFigure()
    $g.FillPath($brushWhite, $path1)

    # Secondary leaf (lower left)
    $path2 = New-Object System.Drawing.Drawing2D.GraphicsPath
    $q1 = New-Object System.Drawing.PointF([float](32.0 * $scale), [float](74.0 * $scale))
    $q2 = New-Object System.Drawing.PointF([float](32.0 * $scale), [float](56.0 * $scale))
    $q3 = New-Object System.Drawing.PointF([float](50.0 * $scale), [float](50.0 * $scale))
    $q4 = New-Object System.Drawing.PointF([float](58.0 * $scale), [float](62.0 * $scale))
    $path2.AddBezier($q1, $q2, $q3, $q4)
    $q5 = New-Object System.Drawing.PointF([float](45.0 * $scale), [float](68.0 * $scale))
    $q6 = New-Object System.Drawing.PointF([float](38.0 * $scale), [float](74.0 * $scale))
    $path2.AddBezier($q4, $q5, $q6, $q1)
    $path2.CloseFigure()
    $g.FillPath($brushLight, $path2)

    # Central stem
    $pen = New-Object System.Drawing.Pen($cGreen, [Math]::Max(1.5, [float](2.5 * $scale)))
    $s1 = New-Object System.Drawing.PointF([float](35.0 * $scale), [float](72.0 * $scale))
    $s2 = New-Object System.Drawing.PointF([float](45.0 * $scale), [float](58.0 * $scale))
    $s3 = New-Object System.Drawing.PointF([float](55.0 * $scale), [float](45.0 * $scale))
    $s4 = New-Object System.Drawing.PointF([float](70.0 * $scale), [float](28.0 * $scale))
    $g.DrawBezier($pen, $s1, $s2, $s3, $s4)

    $targetFolder = Join-Path $baseDir $name
    $outPath = Join-Path $targetFolder "ic_launcher.png"
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $g.Dispose()
    $bmp.Dispose()
    $brushGreen.Dispose()
    $brushWhite.Dispose()
    $brushLight.Dispose()
    $pen.Dispose()
}

Write-Output "Successfully generated launcher icons for all densities."

