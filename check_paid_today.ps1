# check_paid_today.ps1 - list parcels in "Paid Today" for a location/day
param([string]$Location = "KITENGELA", [datetime]$Day = "2026-08-12")
$ErrorActionPreference = "Stop"
$h = @{ 'Content-Type' = 'application/json'; 'X-Client-Identifier' = 'REMBOCLASIC' }
$start = $Day.Date
$end = $Day.Date.AddHours(23).AddMinutes(59).AddSeconds(59)

$r = Invoke-WebRequest -Uri 'https://nav.trimline.co.ke:4013/api/Parcel/Parcels' -Method POST `
    -Body (@{ SyncLocation = $Location } | ConvertTo-Json -Compress) -Headers $h -SkipCertificateCheck -TimeoutSec 300
$all = @($r.Content | ConvertFrom-Json | Select-Object -ExpandProperty Contents)
$toLoc = @($all | Where-Object { $_.to -eq $Location })

function Parse-Dt($v) {
    if ($null -eq $v) { return $null }
    if ($v -is [datetime]) { return $v }
    if ($v -is [string] -and $v.Trim().Length -gt 0) {
        try { $dt = [datetime]::Parse($v); if ($dt.Year -le 1) { return $null }; return $dt } catch { return $null }
    }
    return $null
}

# Paid Today: To == loc AND Who_to_Pay == Receiver AND Payment_Date in range AND Date_sent strictly before range start
$paidToday = @($toLoc | ForEach-Object {
    $p = $_
    if ($p.who_to_Pay -ne 'Receiver') { return }
    $pd = Parse-Dt $p.payment_Date
    $sd = Parse-Dt $p.date_sent
    if ($null -ne $pd -and $pd -ge $start -and $pd -le $end -and $null -ne $sd -and $sd -lt $start) { $p }
})

"LOCATION: $Location  DAY: $($start.ToString('yyyy-MM-dd'))"
"PAID TODAY TOTAL: $($paidToday.Count)"
$cash = @($paidToday | Where-Object { $_.payment_Method -eq 'Cash' })
"CASH: $($cash.Count) parcels, SUM $(($cash | Measure-Object -Property amount_Paid -Sum).Sum)"
$cash | ForEach-Object {
    '{0} | amt={1} | pd={2} | sent={3}' -f $_.Document_No, $_.amount_Paid, $_.payment_Date, $_.date_sent
}
$mp = @($paidToday | Where-Object { $_.payment_Method -ne 'Cash' })
"MPESA: $($mp.Count) parcels, SUM $(($mp | Measure-Object -Property amount_Paid -Sum).Sum)"
$mp | ForEach-Object {
    '{0} | amt={1} | pd={2} | sent={3}' -f $_.Document_No, $_.amount_Paid, $_.payment_Date, $_.date_sent
}
