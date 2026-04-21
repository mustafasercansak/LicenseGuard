function Get-LGEolStatus {
    <#
    .SYNOPSIS
        Checks installed software against the built-in EOL database.
    .EXAMPLE
        Get-LGEolStatus
    .EXAMPLE
        $sw = Get-LGInstalledSoftware; Get-LGEolStatus -SoftwareCache $sw
    #>
    [CmdletBinding()]
    param(
        [PSCustomObject[]]$SoftwareCache = $null
    )

    $L     = Get-LGEffectiveStrings
    $cfg   = Get-LGEffectiveConfig
    $today = Get-Date
    Write-LGHeader $L['hdrEol']

    $rows = if ($SoftwareCache) {
        $SoftwareCache
    } else {
        Get-LGSoftwareRegistryRows -WarnDays $cfg.WarnDaysBeforeExpiry
    }

    $found  = [System.Collections.Generic.List[PSCustomObject]]::new()
    $eolHit = 0

    foreach ($sw in $rows) {
        foreach ($entry in $script:LGEolDatabase) {
            $match = switch ($entry.MatchType) {
                'contains'   { $sw.Name -like "*$($entry.Pattern)*" }
                'startsWith' { $sw.Name -like "$($entry.Pattern)*"  }
                'exact'      { $sw.Name -eq $entry.Pattern           }
                'regex'      { $sw.Name -match $entry.Pattern        }
                default      { $false }
            }
            if ($match) {
                try {
                    $eolDate  = [datetime]::ParseExact($entry.EolDate, 'yyyy-MM-dd', $null)
                    $daysLeft = ($eolDate - $today).Days
                    $status   = if ($daysLeft -lt 0) { 'EXPIRED' } else { 'WARN' }
                    $detail   = if ($daysLeft -lt 0) {
                        "EOL: $($entry.EolDate) ($([math]::Abs($daysLeft)) days ago)"
                    } else {
                        "EOL approaching: $($entry.EolDate) ($daysLeft days left)"
                    }
                    Write-LGStatus $sw.Name $detail $status
                    $found.Add([PSCustomObject]@{
                        Module       = 'EOL'
                        Name         = $sw.Name
                        Status       = $status
                        Detail       = $detail
                        EolDate      = $entry.EolDate
                        ComputerName = $env:COMPUTERNAME
                    })
                    $eolHit++
                } catch {}
                break
            }
        }
    }

    if ($eolHit -eq 0) { Write-LGStatus 'EOL scan' 'No end-of-life software detected' 'OK' }
    $found
}
