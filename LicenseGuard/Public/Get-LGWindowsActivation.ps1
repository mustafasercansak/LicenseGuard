function Get-LGWindowsActivation {
    <#
    .SYNOPSIS
        Checks Windows activation status on the local or a remote machine.
    .EXAMPLE
        Get-LGWindowsActivation
    .EXAMPLE
        Get-LGWindowsActivation -ComputerName SERVER01
    #>
    [CmdletBinding()]
    param(
        [string]$ComputerName = ''
    )

    $L = Get-LGEffectiveStrings
    Write-LGHeader ($L['hdrWinAct'] + $(if ($ComputerName) { " [$ComputerName]" } else { '' }))

    $cimParams = @{
        Query = "SELECT Name, LicenseStatus, Description, GracePeriodRemaining FROM SoftwareLicensingProduct WHERE PartialProductKey IS NOT NULL AND ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f'"
    }
    if ($ComputerName) { $cimParams.ComputerName = $ComputerName }

    $products = $null
    try {
        $products = Get-CimInstance @cimParams
    } catch {
        Write-LGStatus 'Windows License' 'Could not read' 'ERROR'
        return [PSCustomObject]@{
            Module       = 'WindowsActivation'
            Name         = if ($ComputerName) { "[$ComputerName] Windows Activation" } else { 'Windows Activation' }
            Status       = 'ERROR'
            Detail       = 'WMI query failed'
            ComputerName = if ($ComputerName) { $ComputerName } else { $env:COMPUTERNAME }
        }
    }

    if (-not $products) {
        return [PSCustomObject]@{
            Module = 'WindowsActivation'; Name = 'Windows Activation'
            Status = 'ERROR'; Detail = 'No licensing products found'
            ComputerName = if ($ComputerName) { $ComputerName } else { $env:COMPUTERNAME }
        }
    }

    $statusMap = @{
        0 = @('Unlicensed',       'EXPIRED')
        1 = @('Licensed',         'OK')
        2 = @('OOBGrace',         'WARN')
        3 = @('OOTGrace',         'WARN')
        4 = @('NonGenuineGrace',  'WARN')
        5 = @('Notification',     'WARN')
        6 = @('ExtendedGrace',    'WARN')
    }

    $row    = $products | Sort-Object LicenseStatus | Select-Object -First 1
    $ls     = [int]$row.LicenseStatus
    $mapped = if ($statusMap.ContainsKey($ls)) { $statusMap[$ls] } else { @('Unknown', 'WARN') }
    $detail = if ($row.GracePeriodRemaining -gt 0) {
        "$($mapped[0]) -- Remaining: $([math]::Round($row.GracePeriodRemaining / 1440, 1)) days"
    } else { $mapped[0] }

    Write-LGStatus 'Windows Activation' $detail $mapped[1]

    [PSCustomObject]@{
        Module       = 'WindowsActivation'
        Name         = if ($ComputerName) { "[$ComputerName] Windows Activation" } else { 'Windows Activation' }
        Status       = $mapped[1]
        Detail       = $detail
        ComputerName = if ($ComputerName) { $ComputerName } else { $env:COMPUTERNAME }
    }
}
