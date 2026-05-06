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

$results | Format-Table -AutoSize
