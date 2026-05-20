function Register-LGScheduledTask {
    <#
    .SYNOPSIS
        Registers LicenseGuard as a Windows Scheduled Task for automated auditing.
    .DESCRIPTION
        Creates a scheduled task that runs Invoke-LicenseGuard daily. By default it runs as SYSTEM.
    .PARAMETER TaskName
        The name of the task in Task Scheduler. Defaults to 'LicenseGuard'.
    .PARAMETER RunAt
        The daily execution time (e.g., '07:00').
    .PARAMETER OutputPath
        The path where the HTML report will be saved.
    .PARAMETER Language
        Report language ('tr' or 'en').
    .PARAMETER Remove
        If switch is present, unregisters the existing task.
    .EXAMPLE
        Register-LGScheduledTask -RunAt '22:00' -Language en
    #>
    [CmdletBinding()]
    param(
        [string]$TaskName    = 'LicenseGuard',
        [string]$RunAt       = '07:00',
        [string]$OutputPath  = 'C:\LicenseGuard\report.html',
        [ValidateSet('tr','en')]
        [string]$Language    = 'tr',
        [switch]$Remove
    )

    if ($Remove) {
        if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-Host "  [OK] Task removed: $TaskName" -ForegroundColor Yellow
        } else {
            Write-Warning "Task '$TaskName' not found."
        }
        return
    }

    # Ensure output directory exists
    $outputDir = Split-Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $psExe = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
    if (-not $psExe) { $psExe = (Get-Command powershell.exe).Source }

    # The command should import the module and then invoke the scan.
    # If the module is installed in standard paths, Import-Module LicenseGuard is enough.
    $argList = "-NoProfile -NonInteractive -Command `"Import-Module LicenseGuard; Invoke-LicenseGuard -Language $Language -OutputPath '$OutputPath' -NoUpdateCheck`""

    $action  = New-ScheduledTaskAction -Execute $psExe -Argument $argList
    $trigger = New-ScheduledTaskTrigger -Daily -At $RunAt
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2)

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description "LicenseGuard v3.0 - Automated compliance scan" `
        -Force | Out-Null

    Write-Host "`n  [OK] Scheduled Task Created: $TaskName" -ForegroundColor Green
    Write-Host "  [OK] Schedule              : Daily at $RunAt"    -ForegroundColor Green
    Write-Host "  [OK] Action                : $psExe $argList`n" -ForegroundColor DarkGray
}
