<#
    Example: Getting Started with LicenseGuard
    This script shows how to import the module locally and run a basic scan.
#>

# 1. Import the module from the project folder
Import-Module "$PSScriptRoot\..\LicenseGuard" -Force

# 2. Path to default policy (provided in repo root)
$policyPath = "$PSScriptRoot\..\lg-policy.json"

# 3. Run a basic scan with console output only
Invoke-LicenseGuard -PolicyPath $policyPath -ConsoleOnly

# 4. Run a full scan and generate an HTML report
# Invoke-LicenseGuard -PolicyPath $policyPath -OutputPath ".\my-report.html"
