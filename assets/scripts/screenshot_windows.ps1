# Full-screen capture via .NET CopyFromScreen.
#
# Invoked by ScreenshotService._captureWindows:
#   powershell -NoProfile -File screenshot_windows.ps1 -Path <png-path>
param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

Add-Type -AssemblyName System.Windows.Forms,System.Drawing
$b = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($b.X, $b.Y, 0, 0, $bmp.Size)
$g.Dispose()
$bmp.Save("$Path", [System.Drawing.Imaging.ImageFormat]::Png)
