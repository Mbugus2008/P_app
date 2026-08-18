# check_received_cash.ps1 - list individual cash parcels in "Received" for a location/day
param([string]$Location = "GTWLL ATHI", [datetime]$Day = "2026-08-12")
$ErrorActionPreference = "Stop"
$h = @{ 'Content-Type' = 'application/json'; 'X-Client-Identifier' = 'REMBOCLASIC' }
$start = $Day.Date
$end = $Day.Date.AddHours(23).AddMinutes(59).AddSeconds(59)

$r = Invoke-WebRequest -Uri 'https://nav.trimline.co.ke:4013/api/Parcel/Parcels' -Method POST `
    -Body (@{ SyncLocation = $Location } | ConvertTo-Json -Compress) -Headers $h -SkipCertificateCheck -TimeoutSec 300
$all = @($r.Content | ConvertFrom-Json | Select-Object -ExpandProperty Contents)
$recv = @($all | Where-Object { $_.to -eq $Location })

$inToday = @($recv | ForEach-Object {
    $p = $_
    $d = $p.payment_Date
    if (-not $d) { $d = $p.date_sent }
    if (-not $d) { $d = $p.date_Created }
    $dt = $null
    if ($null -ne $d) {
        if ($d -is [string] -and $d.Trim().Length -gt 0) { try { $dt = [datetime]::Parse($d) } catch { $dt = $null } }
        elseif ($d -is [datetime]) { $dt = $d }
    }
    # Sent no earlier than the day start: parcels sent earlier and paid within
    # the period belong to the Paid Today row, not Received.
    $sd = $p.date_sent
    if (-not $sd) { $sd = $p.date_Created }
    $sdt = $null
    if ($null -ne $sd) {
        if ($sd -is [string] -and $sd.Trim().Length -gt 0) { try { $sdt = [datetime]::Parse($sd) } catch { $sdt = $null } }
        elseif ($sd -is [datetime]) { $sdt = $sd }
    }
    if ($null -eq $sdt -or $sdt.Year -le 1) { $sdt = $start }
    if ($null -ne $dt -and $dt.Year -gt 1 -and $dt -ge $start -and $dt -le $end -and $sdt -ge $start) { $p }
})

"LOCATION: $Location  DAY: $($start.ToString('yyyy-MM-dd'))"
"RECEIVED TOTAL: $($inToday.Count)"
$cash = @($inToday | Where-Object { $_.payment_Method -eq 'Cash' })
"CASH PARCELS (count): $($cash.Count)"
"CASH SUM: $(($cash | Measure-Object -Property amount_Paid -Sum).Sum)"
$cash | ForEach-Object {
    '{0} | docno={1} | amt={2} | paid={3} | pd={4} | who_to_pay={5} | sent={6}' -f $_.from, $_.Document_No, $_.amount_Paid, $_.paid, $_.payment_Date, $_.who_to_Pay, $_.date_sent
}
"--- CASH with Who_to_Pay = Receiver (page rule) ---"
$cashRecv = @($cash | Where-Object { $_.who_to_Pay -eq 'Receiver' })
"CASH RECEIVER COUNT: $($cashRecv.Count)  SUM: $(($cashRecv | Measure-Object -Property amount_Paid -Sum).Sum)"
"--- RECEIVER-PAID CASH DOCUMENT NOS ---"
$cashRecv | ForEach-Object {
    '{0} | amt={1} | pd={2}' -f $_.Document_No, $_.amount_Paid, $_.payment_Date
}
"--- CASH with Who_to_Pay = Sender ---"
$cashSend = @($cash | Where-Object { $_.who_to_Pay -eq 'Sender' })
"CASH SENDER COUNT: $($cashSend.Count)  SUM: $(($cashSend | Measure-Object -Property amount_Paid -Sum).Sum)"
"--- MPESA parcels ---"
$mp = @($inToday | Where-Object { $_.payment_Method -ne 'Cash' })
"MPESA COUNT: $($mp.Count)  SUM: $(($mp | Measure-Object -Property amount_Paid -Sum).Sum)"
