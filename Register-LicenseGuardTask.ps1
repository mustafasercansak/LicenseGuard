# Register-LicenseGuardTask.ps1
# LicenseGuard'i Windows Gorev Zamanlayicisi'na kaydeder.
# Yonetici yetkisi ile calistirin: pwsh -NoProfile -File .\Register-LicenseGuardTask.ps1

param(
    [string]$TaskName   = "LicenseGuard",
    [string]$RunAt      = "07:00",
    [string]$Lang       = "tr",
    [string]$OutputPath = "C:\LicenseGuard\report.html",
    [switch]$Remove
)

$scriptPath = Join-Path $PSScriptRoot "LicenseGuard.ps1"

if ($Remove) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Gorev kaldirildi: $TaskName" -ForegroundColor Yellow
    exit 0
}

if (-not (Test-Path $scriptPath)) {
    Write-Host "[ERROR] LicenseGuard.ps1 bulunamadi: $scriptPath" -ForegroundColor Red
    exit 1
}

# Cikti klasorunu olustur
$outputDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$psExe   = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
if (-not $psExe) { $psExe = (Get-Command powershell.exe).Source }

$action  = New-ScheduledTaskAction `
    -Execute $psExe `
    -Argument "-NoProfile -NonInteractive -File `"$scriptPath`" -Lang $Lang -OutputPath `"$OutputPath`""

$trigger  = New-ScheduledTaskTrigger -Daily -At $RunAt

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

$settings  = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
    -RestartCount 1 `
    -RestartInterval (New-TimeSpan -Minutes 15)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "LicenseGuard v2.0 - Otomatik lisans uyumluluk taramasi" `
    -Force | Out-Null

Write-Host ""
Write-Host "  [OK] Gorev olusturuldu : $TaskName"         -ForegroundColor Green
Write-Host "  [OK] Calisma zamani    : Her gun saat $RunAt" -ForegroundColor Green
Write-Host "  [OK] Cikti dosyasi    : $OutputPath"        -ForegroundColor Green
Write-Host "  [OK] Kullanici         : SYSTEM"             -ForegroundColor Green
Write-Host ""
Write-Host "  Kaldirmak icin: .\Register-LicenseGuardTask.ps1 -Remove" -ForegroundColor DarkGray
Write-Host ""
