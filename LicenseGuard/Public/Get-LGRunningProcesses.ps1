function Get-LGRunningProcesses {
    <#
    .SYNOPSIS
        Checks whether any PROHIBITED software from the policy is currently running.
    .EXAMPLE
        $policy = Invoke-LGPolicyCheck -PolicyPath .\lg-policy.json
        Get-LGRunningProcesses -PolicyFindings $policy
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$PolicyFindings
    )

    $L = Get-LGEffectiveStrings
    Write-LGHeader $L['hdrProcess']

    $prohibited = @($PolicyFindings | Where-Object { $_.PolicyStatus -eq 'PROHIBITED' })
    if (-not $prohibited) {
        Write-LGStatus 'Process scan' 'No prohibited software defined' 'OK'
        return @()
    }

    $procs = @(Get-Process | ForEach-Object { $_.ProcessName.ToLower() })
    $rows  = [System.Collections.Generic.List[PSCustomObject]]::new()
    $found = 0

    foreach ($p in $prohibited) {
        $words  = $p.Name.ToLower() -split '[\s\-_\(\)]+' | Where-Object { $_.Length -gt 3 }
        $active = $words | Where-Object { $procs -contains $_ }
        if ($active) {
            Write-LGStatus $p.Name "ACTIVE: $($active -join ', ')" 'EXPIRED'
            $rows.Add([PSCustomObject]@{
                Module  = 'Process'; Name = $p.Name; Status = 'EXPIRED'
                Detail  = "PROHIBITED SOFTWARE RUNNING: $($active -join ', ')"
                Process = ($active -join ', '); ComputerName = $env:COMPUTERNAME
            })
            $found++
        }
    }

    if ($found -eq 0) { Write-LGStatus 'Process scan' 'No prohibited processes running' 'OK' }
    $rows
}
