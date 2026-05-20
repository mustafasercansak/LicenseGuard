<#
    Example: Active Directory Integration
    This script shows how to fetch computers from AD and scan them in parallel.
#>

Import-Module "$PSScriptRoot\..\LicenseGuard" -Force

# 1. Fetch computers from a specific OU
$computers = Get-LGADComputers -SearchBase "OU=Workstations,DC=corp,DC=local"

# 2. Run remote scans on all found machines
# Note: Requires WinRM to be enabled on targets
$results = $computers | Invoke-LGRemoteScan

# 3. Export a consolidated report
# This logic can be customized to aggregate results before reporting
$results | ForEach-Object {
    Write-Host "Scanned $($_.ComputerName): $($_.Status)"
}
