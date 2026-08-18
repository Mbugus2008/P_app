$ErrorActionPreference = "Stop"
$c = Get-Content "D:\Projects2\Parcel\ParcelApp\debug_gtwll_athi.json" -Raw | ConvertFrom-Json
$loc = "GTWLL ATHI"
$todayStart = Get-Date "2026-08-12"
$todayEnd = Get-Date "2026-08-12 23:59:59"

$out = @()

function InRange($d) { if ($d -eq $null) { return $false }; $dt = [datetime]$d; return ($dt -ge $todayStart) -and ($dt -le $todayEnd) }
function EffectiveDate($p) {
  if ($p.payment_Date) { return [datetime]$p.payment_Date }
  if ($p.date_sent) { return [datetime]$p.date_sent }
  if ($p.date_Created) { return [datetime]$p.date_Created }
  return $todayStart
}

$fromLoc = $c | Where-Object { $_.from -eq $loc }
$toLoc = $c | Where-Object { $_.to -eq $loc }

$fromFiltered = $fromLoc | Where-Object { InRange (EffectiveDate $_) }
function SentDate($p) {
  if ($p.date_sent) { return [datetime]$p.date_sent }
  if ($p.date_Created) { return [datetime]$p.date_Created }
  return $todayStart
}
$toFiltered = $toLoc | Where-Object { (InRange (EffectiveDate $_)) -and ((SentDate $_) -ge $todayStart) }

$out += "=== 1. SENT row (date filter: Payment_Date ?? Date_sent) ==="
$out += "sentTotal = $($fromFiltered.Count)"
$out += "sentPaid  = $(($fromFiltered | Where-Object { $_.paid -eq $true }).Count)"
$out += "sentCash  = $(($fromFiltered | Where-Object { $_.payment_Method -eq 'Cash' -and $_.who_to_Pay -eq 'Sender' } | Measure-Object -Property amount_Paid -Sum).Sum)"
$out += "sentMpesa = $(($fromFiltered | Where-Object { $_.payment_Method -eq 'MPesa' -and $_.who_to_Pay -eq 'Sender' } | Measure-Object -Property amount_Paid -Sum).Sum)"

$out += ""
$out += "=== 2. RECEIVED row (date filter: Payment_Date ?? Date_sent) ==="
$out += "recvTotal = $($toFiltered.Count)"
$out += "recvPaid  = $(($toFiltered | Where-Object { $_.paid -eq $true }).Count)"
$out += "recvCash  = $(($toFiltered | Where-Object { $_.payment_Method -eq 'Cash' -and $_.who_to_Pay -eq 'Receiver' } | Measure-Object -Property amount_Paid -Sum).Sum)"
$out += "recvMpesa = $(($toFiltered | Where-Object { $_.payment_Method -eq 'MPesa' -and $_.who_to_Pay -eq 'Receiver' } | Measure-Object -Property amount_Paid -Sum).Sum)"

$out += ""
$out += "=== 3. PAID TODAY row (Payment_Date == today, strict, Who_to_Pay == Receiver) ==="
$paidTodayAll = $toLoc | Where-Object { $_.to -eq $loc -and (InRange $_.payment_Date) -and $_.who_to_Pay -eq 'Receiver' }
$paidTodayPaid = $paidTodayAll | Where-Object { $_.paid -eq $true }
$out += "paidTodayTotal = $($paidTodayAll.Count)"
$out += "paidTodayPaid  = $($paidTodayPaid.Count)"
$out += "paidTodayCash  = $(($paidTodayPaid | Where-Object { $_.payment_Method -eq 'Cash' } | Measure-Object -Property amount_Paid -Sum).Sum)"
$out += "paidTodayMpesa = $(($paidTodayPaid | Where-Object { $_.payment_Method -eq 'MPesa' } | Measure-Object -Property amount_Paid -Sum).Sum)"

$out += ""
$out += "=== 4. What null Payment_Date hides ==="
$out += "To Paid-but-no-date:   $(($toLoc | Where-Object { $_.paid -eq $true -and $_.payment_Date -eq $null }).Count)"
$out += "From Paid-but-no-date: $(($fromLoc | Where-Object { $_.paid -eq $true -and $_.payment_Date -eq $null }).Count)"

$out | Set-Content -Path "D:\Projects2\Parcel\ParcelApp\analyze_report_output.txt" -Encoding UTF8
$out | ForEach-Object { Write-Host $_ }
