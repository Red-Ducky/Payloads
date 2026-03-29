Add-Type @"
using System;
using System.Runtime.InteropServices;

public class DPIAware {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDpiAwarenessContext(IntPtr dpiFlag);

    public static IntPtr PER_MONITOR_AWARE_V2 = new IntPtr(-4);
}
"@

[DPIAware]::SetProcessDpiAwarenessContext([DPIAware]::PER_MONITOR_AWARE_V2) | Out-Null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Start-Sleep -Milliseconds 500

$ready = $false

$answer1 = [System.Windows.Forms.MessageBox]::Show(
    "Est-tu vraiment sur de continuer ?",
    "Alerte",
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Question
)

$answer2 = $null

if ($answer1 -eq [System.Windows.Forms.DialogResult]::Yes) {
    $answer2 = [System.Windows.Forms.MessageBox]::Show(
        "Vraiment ?",
        "?",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
}
if ($answer1 -ne [System.Windows.Forms.DialogResult]::Yes) {
    [System.Windows.Forms.MessageBox]::Show(
        "T'es serieux ou quoi ? Bon vu que tu m'as enerve on va dire que tu voulais bien ! Admire ce qu'il va se passer !",
        "Peureux !",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    $ready = $true
}

if ($ready -eq $false) {
    $count = 1

    while ($count -le 5 -and $ready -eq $false) {
        if ($answer2 -eq [System.Windows.Forms.DialogResult]::Yes) {
        
            $count++
            $message = -join (1..$count | ForEach-Object { "?" })
            
            $answer2 = [System.Windows.Forms.MessageBox]::Show(
                "Vraiment $message",
                "$message",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )

            if ($answer2 -ne [System.Windows.Forms.DialogResult]::Yes) {
                [System.Windows.Forms.MessageBox]::Show(
                    "T'es serieux ou quoi ? Bon vu que tu m'as enerve on va dire que tu voulais bien ! Admire ce qu'il va se passer !",
                    "Peureux !",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
                $ready = $true
            }
        }
    }
}

Start-Sleep -Milliseconds 300

$path = "$env:TEMP\screenshot.png"

$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds

$bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)

$graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)

$bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)

$graphics.Dispose()
$bitmap.Dispose()

$regPath = "HKCU:\Control Panel\Desktop"
Set-ItemProperty -Path $regPath -Name WallpaperStyle -Value "10"
Set-ItemProperty -Path $regPath -Name TileWallpaper -Value "0"

Add-Type @"
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

[Wallpaper]::SystemParametersInfo(20, 0, $path, 3)

$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $regPath -Name "HideIcons" -Value 1

Stop-Process -Name explorer -Force
Start-Process explorer

[System.Windows.Forms.MessageBox]::Show(
    "Félicitations ! Tu viens de détruire ton ordinateur... Amuses-toi bien !",
    "HAHA",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Warning
)

exit
