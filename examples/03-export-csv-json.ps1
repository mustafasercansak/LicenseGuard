<#
    Full scan with HTML, CSV, and JSON exports.
    CSV is useful for Excel/BI tools; JSON is useful for SIEM ingestion.
#>

Import-Module "$PSScriptRoot\..\LicenseGuard\LicenseGuard.psd1" -Force

Invoke-LicenseGuard `
    -OutputPath  ".\reports\license-report.html" `
    -ExportCsv   ".\reports\license-report.csv"  `
    -ExportJson  ".\reports\license-report.json" `
    -Language    en
