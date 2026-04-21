function Get-LGOfficeLicense {
    <#
    .SYNOPSIS
        Checks Microsoft Office license status via ospp.vbs or WMI fallback.
    .EXAMPLE
        Get-LGOfficeLicense
    .EXAMPLE
        Get-LGOfficeLicense -ComputerName SERVER01
    #>
    [CmdletBinding()]
    param(
        [string]$ComputerName = ''
    )

    $L = Get-LGEffectiveStrings
    Write-LGHeader ($L['hdrOffice'] + $(if ($ComputerName) { " [$ComputerName]" } else { '' }))

    $rows = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Method 1: ospp.vbs (local only — runs cscript)
    if (-not $ComputerName) {
        $osppCandidates = @(
            'C:\Program Files\Microsoft Office\Office16\ospp.vbs'
            'C:\Program Files (x86)\Microsoft Office\Office16\ospp.vbs'
            'C:\Program Files\Microsoft Office\Office15\ospp.vbs'
            'C:\Program Files (x86)\Microsoft Office\Office15\ospp.vbs'
            'C:\Program Files\Microsoft Office\Office14\ospp.vbs'
            'C:\Program Files (x86)\Microsoft Office\Office14\ospp.vbs'
        )
        $ospp = $osppCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

        if ($ospp) {
            try {
                $out    = & cscript.exe //Nologo $ospp /dstatus 2>&1
                $blocks = ($out -join "`n") -split '---Processing-'
                foreach ($block in $blocks) {
                    if ($block -notmatch 'LICENSE NAME') { continue }
                    $name       = if ($block -match 'LICENSE NAME:\s*(.+)')             { $Matches[1].Trim() } else { 'Microsoft Office' }
                    $statusLine = if ($block -match 'LICENSE STATUS:\s*-*([^-\r\n]+)')  { $Matches[1].Trim() } else { '' }
                    $graceMin   = if ($block -match 'GRACE PERIOD REMAINING:\s*(\d+)')  { [int]$Matches[1]   } else { 0 }

                    $st = if     ($statusLine -match '(?i)LICENSED')           { 'OK'      }
                          elseif ($statusLine -match '(?i)GRACE|NOTIFICATION') { 'WARN'    }
                          else                                                  { 'EXPIRED' }

                    $detail = $statusLine
                    if ($graceMin -gt 0) { $detail += " -- Remaining: $([math]::Round($graceMin / 1440, 1)) days" }

                    Write-LGStatus $name $detail $st
                    $rows.Add([PSCustomObject]@{
                        Module = 'OfficeLicense'; Name = $name; Status = $st; Detail = $detail
                        ComputerName = $env:COMPUTERNAME
                    })
                }
            } catch {
                Write-LGStatus 'Office (ospp.vbs)' $_.Exception.Message 'ERROR'
            }
        }
    }

    # Method 2: WMI fallback (works remote and when ospp not found)
    if ($rows.Count -eq 0) {
        $cimParams = @{
            Query = "SELECT Name, LicenseStatus, GracePeriodRemaining FROM SoftwareLicensingProduct WHERE PartialProductKey IS NOT NULL AND ApplicationID='0ff1ce15-a989-479d-af46-f275c6370663'"
        }
        if ($ComputerName) { $cimParams.ComputerName = $ComputerName }

        try {
            $products  = Get-CimInstance @cimParams
            $statusMap = @{
                0='EXPIRED'; 1='OK'; 2='WARN'; 3='WARN'; 4='WARN'; 5='WARN'; 6='WARN'
            }
            $labelMap  = @{
                0='Unlicensed'; 1='Licensed'; 2='OOBGrace'; 3='OOTGrace'
                4='NonGenuineGrace'; 5='Notification'; 6='ExtendedGrace'
            }
            $host_ = if ($ComputerName) { $ComputerName } else { $env:COMPUTERNAME }

            if ($products) {
                foreach ($p in @($products)) {
                    $ls     = [int]$p.LicenseStatus
                    $st     = if ($statusMap.ContainsKey($ls)) { $statusMap[$ls] } else { 'WARN' }
                    $label  = if ($labelMap.ContainsKey($ls))  { $labelMap[$ls]  } else { 'Unknown' }
                    $detail = if ($p.GracePeriodRemaining -gt 0) {
                        "$label -- Remaining: $([math]::Round($p.GracePeriodRemaining / 1440, 1)) days"
                    } else { $label }
                    $pName  = if ($p.Name) { $p.Name } else { 'Microsoft Office' }
                    Write-LGStatus $pName $detail $st
                    $rows.Add([PSCustomObject]@{
                        Module = 'OfficeLicense'; Name = $pName; Status = $st
                        Detail = $detail; ComputerName = $host_
                    })
                }
            } else {
                $msg = $L['officeNotFound']
                Write-LGStatus 'Microsoft Office' $msg 'OK'
                $rows.Add([PSCustomObject]@{
                    Module = 'OfficeLicense'; Name = 'Microsoft Office'
                    Status = 'OK'; Detail = $msg; ComputerName = $host_
                })
            }
        } catch {
            Write-LGStatus 'Office (WMI)' $_.Exception.Message 'ERROR'
            $rows.Add([PSCustomObject]@{
                Module = 'OfficeLicense'; Name = 'Microsoft Office'
                Status = 'ERROR'; Detail = $_.Exception.Message
                ComputerName = if ($ComputerName) { $ComputerName } else { $env:COMPUTERNAME }
            })
        }
    }

    $rows
}
