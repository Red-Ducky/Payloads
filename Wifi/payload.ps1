$webhookUrl = "https://discord.com/api/webhooks/1501460061439004732/fE-P3g0HI2ha_ZKMhWmn1woNkl8yzMz_sLLFffMnk4xa1JtNDy0PodilxIiB7BlEvS_m"

$machine     = $env:COMPUTERNAME
$utilisateur = $env:USERNAME
$date        = Get-Date -Format "yyyy-MM-dd HH:mm"

$body = "{`"content`": `"Machine: $machine | User: $utilisateur | Date: $date`"}"

Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $body -ContentType "application/json"
