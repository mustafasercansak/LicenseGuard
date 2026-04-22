<#
    Validate lg-policy.json without running any scan.
    Useful in CI to catch malformed policy files before deployment.
#>

Import-Module "$PSScriptRoot\..\LicenseGuard\LicenseGuard.psd1" -Force

Invoke-LicenseGuard -TestPolicy -PolicyPath ".\lg-policy.json"
