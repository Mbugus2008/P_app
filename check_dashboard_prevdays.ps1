# check_dashboard_prevdays.ps1 - verify dashboard previousDaysPaidToday against raw parcels
$ErrorActionPreference = "Stop"
$h = @{ 'Content-Type' = 'application/json'; 'X-Client-Identifier' = 'REMBOCLASIC' }
$today = [datetime]::Today
"Server-local 'today' used by script: $($today.ToString('yyyy-MM-dd'))"

# Get all parcels (no filter) like DashboardController does
$r = Invoke-WebRequest -Uri 'https://nav.trimline.co.ke:4013/api/Parcel/Parcels' -Method POST `
    -Body '{"PageSize":0}' -Headers $h -SkipCertificateCheck -TimeoutSec 300
$all = @($r.Content | ConvertFrom-Json | Select-Object -ExpandProperty Contents)
"Total parcels fetched: $($all.Count)"

function Dt([object]$v) {
    if ($null -eq $v) { return $null }
    if ($v -is [datetime]) { return $v }
    if ($v -is [string]) { if ($v.Trim().Length -eq 0) { return $null }; try { $d=[datetime]::Parse($v); if ($d.Year -le 1){return $null}; return $d } catch { return $null } }
    return $null
}

# Mirror of controller: Paid AND Date_sent < today AND Payment_Date set AND Payment_Date.Date == today
$m = @($all | Where-Object {
    $sd = Dt $_.date_sent; $pd = Dt $_.payment_Date
    ($_.paid -eq $true) -and ($null -ne $sd) -and ($sd.Date -lt $today) -and ($null -ne $pd) -and ($pd.Date -eq $today)
})
"Controller-mirror count: $($m.Count)  sum: $(($m | Measure-Object -Property amount_Paid -Sum).Sum)"

# Same but Receiver-only (app rule)
$mr = @($m | Where-Object { $_.who_to_Pay -eq 'Receiver' })
"Receiver-only count: $($mr.Count)  sum: $(($mr | Measure-Object -Property amount_Paid -Sum).Sum)"

# Paid today at all (any sent date)
$pt = @($all | Where-Object {
    $pd = Dt $_.payment_Date
    ($_.paid -eq $true) -and ($null -ne $pd) -and ($pd.Date -eq $today)
})
"Paid-today (any sent date) count: $($pt.Count)  sum: $(($pt | Measure-Object -Property amount_Paid -Sum).Sum)"

# Sample a few matching rows
$m | Select-Object -First 10 | ForEach-Object {
    '{0} | sent={1} | paid={2} | amt={3} | who={4}' -f $_.document_No, $_.date_sent, $_.payment_Date, $_.amount_Paid, $_.who_to_Pay
}
