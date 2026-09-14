# check_location_parcels.ps1 - count parcels From/To a given location
param([string]$Location = "MUHOROTO")
$ErrorActionPreference = "Stop"
$h = @{ 'Content-Type' = 'application/json'; 'X-Client-Identifier' = 'REMBOCLASIC' }
$r = Invoke-WebRequest -Uri 'https://nav.trimline.co.ke:4013/api/Parcel/Parcels' -Method POST `
    -Body '{"PageSize":0}' -Headers $h -SkipCertificateCheck -TimeoutSec 300
$all = @($r.Content | ConvertFrom-Json | Select-Object -ExpandProperty Contents)

"Total parcels: $($all.Count)"
$to = @($all | Where-Object { $_.to -eq $Location })
$from = @($all | Where-Object { $_.from -eq $Location })
"To $Location : $($to.Count)"
"From $Location : $($from.Count)"

"--- Distinct To values ---"
($all | ForEach-Object { $_.to } | Where-Object { $_ } | Sort-Object -Unique) -join ' | '
"--- Distinct From values ---"
($all | ForEach-Object { $_.from } | Where-Object { $_ } | Sort-Object -Unique) -join ' | '

if ($to.Count -gt 0) {
    "--- Sample To $Location ---"
    $to | Select-Object -First 5 | ForEach-Object {
        '{0} | sent={1} | status={2} | collected={3}' -f $_.document_No, $_.date_sent, $_.status, $_.date_Collected
    }
}
