# analyze_all_locations.ps1
# Replicates LocationParcelsPage report for EVERY location using live API data.
# Usage: pwsh -File .\analyze_all_locations.ps1 -Day "2026-08-11"
param([datetime]$Day = "2026-08-12")
$ErrorActionPreference = "Stop"
$BaseUrl = "https://nav.trimline.co.ke:4013/api/Parcel/"
$Headers = @{ "Content-Type" = "application/json"; "X-Client-Identifier" = "REMBOCLASIC" }
$TodayStart = $Day.Date
$TodayEnd = $Day.Date.AddHours(23).AddMinutes(59).AddSeconds(59)

function Api-Post([string]$path, [string]$body) {
    return Invoke-WebRequest -Uri ($BaseUrl.TrimEnd('/') + $path) -Method POST -Body $body -Headers $Headers -SkipCertificateCheck -TimeoutSec 300
}

function Get-Dt([object]$p, [string]$field) {
    $raw = $p.$field
    if ($null -eq $raw) { return $null }
    if ($raw -is [datetime]) {
        if ($raw.Year -le 1) { return $null }
        return $raw
    }
    if ($raw -is [string]) {
        if ($raw.Trim().Length -eq 0) { return $null }
        try { $dt = [datetime]::Parse($raw); if ($dt.Year -le 1) { return $null }; return $dt } catch { return $null }
    }
    return $null
}
function InToday($d) { if ($null -eq $d) { return $false }; return ($d -ge $TodayStart) -and ($d -le $TodayEnd) }

$out = @()

# Locations
$locResp = Api-Post "/Locations" '{"PageSize":500}'
$locations = @($locResp.Content | ConvertFrom-Json | Select-Object -ExpandProperty Contents | ForEach-Object { $_.code.Trim() } | Where-Object { $_ })

$out += "Day: $($TodayStart.ToString('yyyy-MM-dd'))"
$out += "Locations: $($locations.Count)"
$out += ""

foreach ($loc in $locations) {
    try {
        $resp = Api-Post "/Parcels" (@{ SyncLocation = $loc } | ConvertTo-Json -Compress)
        $all = @($resp.Content | ConvertFrom-Json | Select-Object -ExpandProperty Contents)
    } catch {
        $out += "$loc | ERROR fetching: $_"
        continue
    }

    $fromLoc = @($all | Where-Object { $_.from -eq $loc })
    $toLoc   = @($all | Where-Object { $_.to -eq $loc })

    # Sent: dispatched on selected day (Date_sent), From == loc
    $fromFiltered = @($fromLoc | Where-Object {
        $sd = Get-Dt $_ "date_sent"; ($null -ne $sd) -and (InToday $sd) })
    # Received: effective date (Payment_Date ?? Date_sent ?? Date_Created) in range, To == loc,
    # AND sent no earlier than the day start (sent-earlier + paid-in-range -> Paid Today row)
    $toFiltered = @($toLoc | Where-Object {
        $d = Get-Dt $_ "payment_Date"; if ($null -eq $d) { $d = Get-Dt $_ "date_sent" }; if ($null -eq $d) { $d = Get-Dt $_ "date_Created" }; if ($null -eq $d) { $d = $TodayStart }
        $sd = Get-Dt $_ "date_sent"; if ($null -eq $sd) { $sd = Get-Dt $_ "date_Created" }; if ($null -eq $sd) { $sd = $TodayStart }
        (InToday $d) -and ($sd -ge $TodayStart) })

    # Sent
    $sentTotal = $fromFiltered.Count
    $sentPaid = @($fromFiltered | Where-Object { $_.paid -eq $true }).Count
    $sentCash = ($fromFiltered | Where-Object { $_.payment_Method -eq "Cash" -and $_.who_to_Pay -eq "Sender" } | Measure-Object -Property amount_Paid -Sum).Sum
    $sentMpesa = ($fromFiltered | Where-Object { $_.payment_Method -eq "MPesa" -and $_.who_to_Pay -eq "Sender" } | Measure-Object -Property amount_Paid -Sum).Sum

    # Received
    $recvTotal = $toFiltered.Count
    $recvPaid = @($toFiltered | Where-Object { $_.paid -eq $true }).Count
    $recvCash = ($toFiltered | Where-Object { $_.payment_Method -eq "Cash" -and $_.who_to_Pay -eq "Receiver" } | Measure-Object -Property amount_Paid -Sum).Sum
    $recvMpesa = ($toFiltered | Where-Object { $_.payment_Method -eq "MPesa" -and $_.who_to_Pay -eq "Receiver" } | Measure-Object -Property amount_Paid -Sum).Sum

    # Paid Today: To == loc AND Who_to_Pay == Receiver AND Payment_Date in selected day AND Date_sent before selected day
    $paidTodayAll = @($toLoc | Where-Object {
        $pd = Get-Dt $_ "payment_Date"; $sd = Get-Dt $_ "date_sent"
        ($null -ne $pd) -and (InToday $pd) -and ($null -ne $sd) -and ($sd -lt $TodayStart) -and ($_.who_to_Pay -eq "Receiver") })
    $paidTodayPaid = @($paidTodayAll | Where-Object { $_.paid -eq $true })
    $paidTodayCash = ($paidTodayPaid | Where-Object { $_.payment_Method -eq "Cash" } | Measure-Object -Property amount_Paid -Sum).Sum
    $paidTodayMpesa = ($paidTodayPaid | Where-Object { $_.payment_Method -eq "MPesa" } | Measure-Object -Property amount_Paid -Sum).Sum

    if ($sentTotal -eq 0 -and $recvTotal -eq 0 -and $paidTodayAll.Count -eq 0) { continue }

    $out += "LOCATION: $loc"
    $out += "  Sent      : total=$sentTotal paid=$sentPaid cash=$sentCash mpesa=$sentMpesa"
    $out += "  Received  : total=$recvTotal paid=$recvPaid cash=$recvCash mpesa=$recvMpesa"
    $out += "  PaidToday : total=$($paidTodayAll.Count) paid=$($paidTodayPaid.Count) cash=$paidTodayCash mpesa=$paidTodayMpesa"
}

$out | Set-Content "D:\Projects2\Parcel\ParcelApp\analyze_all_locations.txt" -Encoding UTF8
$out | ForEach-Object { Write-Host $_ }
