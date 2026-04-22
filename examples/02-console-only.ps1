<#
    Quick scan — prints results to console only, no HTML file written.
    Useful for CI pipelines or terminals without a browser.
#>

Import-Module "$PSScriptRoot\..\LicenseGuard\LicenseGuard.psd1" -Force

Invoke-LicenseGuard -ConsoleOnly -Language en
