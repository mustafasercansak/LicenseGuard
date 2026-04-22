function Save-LGSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCustomObject[]]$AllResults,
        [Parameter(Mandatory)][PSCustomObject[]]$PolicyFindings,
        [string]$SnapshotPath = ''
    )
    $cfg  = Get-LGEffectiveConfig
    $L    = Get-LGEffectiveStrings
    $path = if ($SnapshotPath) { $SnapshotPath } else { $cfg.SnapshotPath }
    try {
        [PSCustomObject]@{
            Timestamp  = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            Hostname   = $env:COMPUTERNAME
            Issues     = @($AllResults     | Where-Object { $_.Status -ne 'OK' }             | ForEach-Object { $_.Name })
            Violations = @($PolicyFindings | Where-Object { $_.PolicyStatus -ne 'ALLOWED' }  | ForEach-Object { $_.Name })
        } | ConvertTo-Json -Compress | Out-File $path -Encoding UTF8 -Force
        Write-Host "  $($L['snapshotSaved']) $path" -ForegroundColor DarkGray
    } catch { Write-Warning "Snapshot save failed: $($_.Exception.Message)" }
}

function Get-LGDelta {
    [CmdletBinding()]
    param(
        [string]$SnapshotPath = '',
        [PSCustomObject[]]$CurrentResults = @(),
        [PSCustomObject[]]$CurrentPolicyFindings = @()
    )
    $cfg  = Get-LGEffectiveConfig
    $path = if ($SnapshotPath) { $SnapshotPath } else { $cfg.SnapshotPath }
    if (-not (Test-Path $path)) { return $null }
    try { $prev = Get-Content $path -Raw | ConvertFrom-Json } catch { return $null }
    if (-not $prev) { return $null }

    $prevIssues     = @(if ($prev.Issues)     { $prev.Issues     } else { @() })
    $prevViolations = @(if ($prev.Violations) { $prev.Violations } else { @() })
    $currIssues     = @($CurrentResults       | Where-Object { $_.Status -ne 'OK' }            | ForEach-Object { $_.Name })
    $currViolations = @($CurrentPolicyFindings | Where-Object { $_.PolicyStatus -ne 'ALLOWED' } | ForEach-Object { $_.Name })

    [PSCustomObject]@{
        PreviousTimestamp  = $prev.Timestamp
        NewIssues          = @($currIssues     | Where-Object { $prevIssues     -notcontains $_ })
        ResolvedIssues     = @($prevIssues     | Where-Object { $currIssues     -notcontains $_ })
        NewViolations      = @($currViolations | Where-Object { $prevViolations -notcontains $_ })
        ResolvedViolations = @($prevViolations | Where-Object { $currViolations -notcontains $_ })
    }
}
