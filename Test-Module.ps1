#Requires -Version 5.1
<#
    Smoke test — imports the module from the local source and calls key functions.
    Does not require the module to be installed; runs directly from repo.
    Usage: .\Test-Module.ps1
#>

$modulePath = Join-Path $PSScriptRoot 'LicenseGuard\LicenseGuard.psd1'

Write-Host "`n[1] Importing module from: $modulePath" -ForegroundColor Cyan
Import-Module $modulePath -Force -ErrorAction Stop
Write-Host "    OK" -ForegroundColor Green

Write-Host "`n[2] Test-ModuleManifest" -ForegroundColor Cyan
$manifest = Test-ModuleManifest -Path $modulePath
Write-Host "    $($manifest.Name) v$($manifest.Version)" -ForegroundColor Green

Write-Host "`n[3] Exported functions ($($manifest.ExportedFunctions.Count))" -ForegroundColor Cyan
$manifest.ExportedFunctions.Keys | Sort-Object | ForEach-Object { Write-Host "    $_" }

Write-Host "`n[4] Initialize-LicenseGuard" -ForegroundColor Cyan
Initialize-LicenseGuard -Language en
Write-Host "    OK" -ForegroundColor Green

Write-Host "`n[5] Get-LGWindowsActivation" -ForegroundColor Cyan
$win = Get-LGWindowsActivation
Write-Host "    Status: $($win.Status)  |  Detail: $($win.Detail)" -ForegroundColor Green

Write-Host "`n[6] Get-LGInstalledSoftware (first 5)" -ForegroundColor Cyan
$sw = Get-LGInstalledSoftware
$sw | Select-Object -First 5 | Format-Table Name, Version, Publisher, Status -AutoSize

Write-Host "`n[7] Invoke-LicenseGuard -TestPolicy" -ForegroundColor Cyan
$policyPath = Join-Path $PSScriptRoot 'lg-policy.json'
if (Test-Path $policyPath) {
    Invoke-LicenseGuard -TestPolicy -PolicyPath $policyPath
} else {
    Write-Warning "lg-policy.json not found — skipping policy test"
}

Write-Host "`nAll smoke tests passed.`n" -ForegroundColor Green
