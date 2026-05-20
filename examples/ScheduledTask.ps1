<#
    Example: Scheduling a Daily Scan
    This script shows how to use the built-in scheduling function.
#>

# Import the module
Import-Module "$PSScriptRoot\..\LicenseGuard" -Force

# Register a new daily task at 8:00 AM
Register-LGScheduledTask -TaskName "Daily-License-Audit" -RunAt "08:00" -Language en -OutputPath "C:\Reports\Audit.html"

Write-Host "Task registered. You can check it in Task Scheduler under 'Daily-License-Audit'."

# To remove the task later:
# Register-LGScheduledTask -TaskName "Daily-License-Audit" -Remove
