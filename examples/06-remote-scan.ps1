<#
    Scan multiple remote machines in parallel via WinRM.
    Requires PSRemoting enabled on target machines.
    Run: Enable-PSRemoting -Force   (on each target, as admin)
#>

Import-Module "$PSScriptRoot\..\LicenseGuard\LicenseGuard.psd1" -Force

$computers = @('PC01', 'PC02', 'PC03')

$results = $computers | Invoke-LGRemoteScan -ThrottleLimit 5 -IncludeEol

$results | Where-Object { $_.Status -ne 'OK' } |
    Format-Table ComputerName, Module, Name, Status, Detail -AutoSize
