<#
    Basic full scan — HTML report saved to .\license-report.html
    Run from the folder that contains lg-config.json and lg-policy.json.
#>

Import-Module "$PSScriptRoot\..\LicenseGuard\LicenseGuard.psd1" -Force

Invoke-LicenseGuard
