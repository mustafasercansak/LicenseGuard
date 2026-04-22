function Get-LGInstalledSoftware {
    <#
    .SYNOPSIS
        Returns installed software inventory from the registry.
    .EXAMPLE
        Get-LGInstalledSoftware
    .EXAMPLE
        Get-LGInstalledSoftware -WarnDays 60
    #>
    [CmdletBinding()]
    param(
        [int]$WarnDays = 0
    )

    $cfg      = Get-LGEffectiveConfig
    $L        = Get-LGEffectiveStrings
    $warnDays = if ($WarnDays -gt 0) { $WarnDays } else { $cfg.WarnDaysBeforeExpiry }

    Write-LGHeader $L['hdrSoftware']

    $rows = Get-LGSoftwareRegistryRows -WarnDays $warnDays -UnknownLabel $L['publisherUnknown']

    $expired = @($rows | Where-Object { $_.Status -eq 'EXPIRED' })
    $warning = @($rows | Where-Object { $_.Status -eq 'WARN' })

    Write-Host ("  {0} software found." -f @($rows).Count) -ForegroundColor DarkGray

    if ($expired) {
        Write-Host "`n  Expired:" -ForegroundColor Red
        $expired | ForEach-Object { Write-LGStatus $_.Name $_.ExpireInfo 'EXPIRED' }
    }
    if ($warning) {
        Write-Host "`n  Warning (expiring within $warnDays days):" -ForegroundColor Yellow
        $warning | ForEach-Object { Write-LGStatus $_.Name $_.ExpireInfo 'WARN' }
    }
    if (-not $expired -and -not $warning) {
        Write-LGStatus 'All software' 'No expiry records / no issues' 'OK'
    }

    $rows | ForEach-Object {
        [PSCustomObject]@{
            Module       = 'Software'
            Name         = $_.Name
            Version      = $_.Version
            Publisher    = $_.Publisher
            Status       = $_.Status
            Detail       = $_.ExpireInfo
            InstallDate  = $_.InstallDate
            ComputerName = $env:COMPUTERNAME
        }
    }
}
