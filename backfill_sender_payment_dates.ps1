# backfill_sender_payment_dates.ps1
# Backfills Payment_Date for Sender-paid parcels where it is missing.
# Rule: Payment_Date = Date_Created ?? Date_sent  (paid at dispatch time)
#
# Usage:
#   Dry run (lists candidates, changes nothing):
#     powershell -ExecutionPolicy Bypass -File .\backfill_sender_payment_dates.ps1
#   Apply (updates BC):
#     powershell -ExecutionPolicy Bypass -File .\backfill_sender_payment_dates.ps1 -Apply
#   Limit to specific locations:
#     powershell -ExecutionPolicy Bypass -File .\backfill_sender_payment_dates.ps1 -Location "GTWLL ATHI","KITENGELA"

param(
    [string]$BaseUrl = "https://nav.trimline.co.ke:4013/api/Parcel/",
    [switch]$Apply,
    [string[]]$Location = @()
)

$ErrorActionPreference = "Stop"
$Headers = @{ "Content-Type" = "application/json"; "X-Client-Identifier" = "REMBOCLASIC" }
$LogFile = Join-Path $PSScriptRoot "backfill_sender_log.txt"
$updated = 0
$skipped = 0
$failed = 0

function Write-Log([string]$msg) {
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

function Get-JsonDate([object]$p, [string]$field) {
    $raw = $p.$field
    if ($null -eq $raw -or $raw -isnot [string] -or $raw.Trim().Length -eq 0) { return $null }
    try {
        $dt = [datetime]::Parse($raw)
        if ($dt.Year -le 1) { return $null }   # BC empty date is 0001-01-01
        return $dt
    } catch { return $null }
}

# Status / Who_to_Pay enum values from the BC page (Reference.cs)
$StatusMap = @{
    "Open" = 0; "In_Transist" = 1; "Waiting_Collection" = 2; "Collected" = 3
    "0" = 0; "1" = 1; "2" = 2; "3" = 3
}
$WhoPayMap = @{ "Sender" = 0; "Receiver" = 1; "0" = 0; "1" = 1 }

function Invoke-Api([string]$method, [string]$url, [string]$body) {
    if ($method -eq "POST") {
        return Invoke-WebRequest -Uri "$BaseUrl$url" -Method POST -Body $body -Headers $Headers -SkipCertificateCheck -TimeoutSec 180
    }
    return Invoke-WebRequest -Uri "$BaseUrl$url" -Method PUT -Body $body -Headers $Headers -SkipCertificateCheck -TimeoutSec 180
}

# ---------- 1. Get locations ----------
Write-Log "Fetching locations..."
$locResp = Invoke-Api "POST" "Locations" '{"PageSize":500}'
$locJson = $locResp.Content | ConvertFrom-Json
$locations = @($locJson.Contents | ForEach-Object { $_.code.Trim() } | Where-Object { $_ })

if ($Location.Count -gt 0) {
    $locations = @($locations | Where-Object { $Location -contains $_ })
    if ($locations.Count -eq 0) { Write-Log "No matching locations found. Exiting."; exit 1 }
}
Write-Log "Processing $($locations.Count) locations"

# ---------- 2. Scan each location ----------
$seen = @{}   # Document_No dedupe (a parcel appears in both From and To locations)

foreach ($loc in $locations) {
    Write-Log "Location: $loc"
    try {
        $resp = Invoke-Api "POST" "Parcels" (@{ SyncLocation = $loc } | ConvertTo-Json -Compress)
        $parcels = @($resp.Content | ConvertFrom-Json | Select-Object -ExpandProperty Contents)
    } catch {
        Write-Log "  ERROR fetching parcels for $loc : $_"
        continue
    }
    Write-Log "  $($parcels.Count) parcels returned"

    foreach ($p in $parcels) {
        $docNo = [string]$p.document_No
        if (-not $docNo) { continue }
        if ($seen.ContainsKey($docNo)) { continue }
        $seen[$docNo] = $true

        # Rule filter: paid + no payment date + sender pays
        if ($p.paid -ne $true) { continue }
        $pd = Get-JsonDate $p "payment_Date"
        if ($null -ne $pd) { continue }
        if ([string]$p.who_to_Pay -ne "Sender") { continue }

        # Backfill date: Date_Created, else Date_sent
        $created = Get-JsonDate $p "date_Created"
        $sent    = Get-JsonDate $p "date_sent"
        $newDate = if ($null -ne $created) { $created } else { $sent }
        if ($null -eq $newDate) {
            Write-Log "  SKIP $docNo — no creation/sent date available"
            $skipped++
            continue
        }

        # Build PascalCase update body (matches API ParseParcelFromJson)
        $statusInt = if ($StatusMap.ContainsKey([string]$p.status)) { $StatusMap[[string]$p.status] } else { 0 }
        $whoPayInt = if ($WhoPayMap.ContainsKey([string]$p.who_to_Pay)) { $WhoPayMap[[string]$p.who_to_Pay] } else { 0 }

        $body = @{
            Document_No       = $p.document_No
            Batch_No          = $p.batch_No
            Date_sent         = if ($sent) { $sent.ToString("yyyy-MM-ddTHH:mm:ss") } else { $null }
            Sender_Name       = $p.sender_Name
            Sender_ID         = $p.sender_ID
            Sender_Phone      = $p.sender_Phone
            From              = $p.from
            To                = $p.to
            Receiver_Name     = $p.receiver_Name
            Receiver_ID       = $p.receiver_ID
            Receiver_Phone    = $p.receiver_Phone
            Status            = $statusInt
            Driver            = $p.driver
            Vehicle           = $p.vehicle
            Who_to_Pay        = $whoPayInt
            Amount_Paid       = $p.amount_Paid
            Paid              = $p.paid
            Payment_Method    = $p.payment_Method
            Mpesa_Code        = $p.mpesa_Code
            Date_Collected    = if ($null -ne (Get-JsonDate $p "date_Collected")) { ([datetime](Get-JsonDate $p "date_Collected")).ToString("yyyy-MM-ddTHH:mm:ss") } else { $null }
            Date_Delivered    = if ($null -ne (Get-JsonDate $p "date_Delivered")) { ([datetime](Get-JsonDate $p "date_Delivered")).ToString("yyyy-MM-ddTHH:mm:ss") } else { $null }
            deviceId          = $p.deviceId
            Payment_Received_By = $p.payment_Received_By
            Created_By        = $p.created_By
            Received_By_ID    = $p.received_By_ID
            Received_By_Phone = $p.received_By_Phone
            Receiver_Code     = $p.receiver_Code
            App_Version       = $p.app_Version
            Parcel_Value      = $p.parcel_Value
            Payment_Date      = $newDate.ToString("yyyy-MM-ddTHH:mm:ss")
            Payment_Time      = $p.payment_Time
        }
        $jsonBody = $body | ConvertTo-Json -Depth 3

        if ($Apply) {
            try {
                $updResp = Invoke-Api "PUT" "nav/parcels/update" $jsonBody
                $updJson = $updResp.Content | ConvertFrom-Json
                if ($updJson.Code -eq 0) {
                    Write-Log "  UPDATED $docNo : Payment_Date -> $($newDate.ToString('yyyy-MM-dd'))"
                    $updated++
                } else {
                    Write-Log "  FAILED $docNo : $($updJson.Desc)"
                    $failed++
                }
            } catch {
                Write-Log "  FAILED $docNo : $_"
                $failed++
            }
        } else {
            Write-Log "  CANDIDATE $docNo : Payment_Date -> $($newDate.ToString('yyyy-MM-dd')) (From=$($p.from), Method=$($p.payment_Method))"
            $updated++
        }
    }
}

Write-Log ""
Write-Log "===== SUMMARY ====="
if ($Apply) {
    Write-Log "Updated: $updated | Skipped: $skipped | Failed: $failed"
} else {
    Write-Log "DRY RUN — candidates found: $updated | Skipped (no date): $skipped"
    Write-Log "Run with -Apply to write these changes to BC."
}
