<#
    Two-pass example: first scan creates a snapshot, second scan shows the delta.
    Run this script twice to see new/resolved issues between scans.
#>

Import-Module "$PSScriptRoot\..\LicenseGuard\LicenseGuard.psd1" -Force

$snapshotPath = ".\lg-snapshot.json"

Write-Host "`n--- First scan (creates snapshot) ---" -ForegroundColor Cyan
Invoke-LicenseGuard -ConsoleOnly -Language en

Write-Host "`n--- Second scan (shows delta against snapshot) ---" -ForegroundColor Cyan
Invoke-LicenseGuard -ConsoleOnly -Language en

Write-Host "`n--- Delta summary ---" -ForegroundColor Cyan
Initialize-LicenseGuard -Language en
$delta = Get-LGDelta -SnapshotPath $snapshotPath
if ($delta) {
    "Previous scan : $($delta.PreviousTimestamp)"
    "New issues     : $($delta.NewIssues      -join ', ')"
    "Resolved issues: $($delta.ResolvedIssues -join ', ')"
    "New violations : $($delta.NewViolations  -join ', ')"
} else {
    "No previous snapshot found at: $snapshotPath"
}
