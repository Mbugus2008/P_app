param(
    [string]$RemoteHost = "nav.trimline.co.ke",
    [string]$RemoteUser = "Administrator",
    [string]$RemotePath = "D:/Parcel/wwwroot",
    [string]$ApkPath = "",
    [string]$ApkName = "app-release.apk",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $ApkPath = Join-Path $PSScriptRoot "build\app\outputs\flutter-apk\$ApkName"
}

if (-not $SkipBuild) {
    Write-Host "Building APK..." -ForegroundColor Cyan
    Push-Location $PSScriptRoot
    try {
        flutter build apk --release
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter build failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

if (-not (Test-Path $ApkPath)) {
    throw "APK not found at: $ApkPath"
}

$fileSize = (Get-Item $ApkPath).Length / 1MB
Write-Host "Uploading APK ($([math]::Round($fileSize, 1)) MB) to $RemoteHost ..." -ForegroundColor Cyan

$remote = "$RemoteUser@$RemoteHost"
$remoteFile = "$RemotePath/$ApkName"

scp $ApkPath "${remote}:$remoteFile"

if ($LASTEXITCODE -ne 0) {
    throw "SCP upload failed with exit code $LASTEXITCODE"
}

Write-Host "APK deployed to https://$RemoteHost/$ApkName" -ForegroundColor Green
