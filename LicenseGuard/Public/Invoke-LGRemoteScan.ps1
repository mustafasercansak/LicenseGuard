function Invoke-LGRemoteScan {
    <#
    .SYNOPSIS
        Scans multiple remote machines in parallel using Invoke-Command (WinRM).

    .DESCRIPTION
        Accepts computer names from the pipeline or directly. Launches parallel
        background jobs (up to ThrottleLimit concurrent) and collects Windows
        Activation, installed software, and optional EOL results from each machine.

    .PARAMETER ComputerName
        One or more machine names to scan. Accepts pipeline input.

    .PARAMETER ThrottleLimit
        Maximum number of concurrent WinRM jobs. Default: 10.

    .PARAMETER TimeoutSeconds
        Seconds to wait for each job before marking it timed-out. Default: 120.

    .PARAMETER Credential
        PSCredential to use for all remote connections.

    .PARAMETER WarnDays
        Days before expiry to classify as WARN. Defaults to module config.

    .PARAMETER IncludeEol
        Also run EOL database checks on each remote machine.

    .EXAMPLE
        Invoke-LGRemoteScan -ComputerName PC01,PC02,PC03

    .EXAMPLE
        Get-LGADComputers -OU 'OU=Workstations,DC=corp,DC=local' |
            Invoke-LGRemoteScan -ThrottleLimit 20 -IncludeEol

    .EXAMPLE
        'PC01','PC02' | Invoke-LGRemoteScan -Credential (Get-Credential)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]$ComputerName,

        [int]$ThrottleLimit   = 10,
        [int]$TimeoutSeconds  = 120,
        [pscredential]$Credential,
        [int]$WarnDays        = 0,
        [switch]$IncludeEol
    )

    begin {
        $allComputers = [System.Collections.Generic.List[string]]::new()

        # Serialisable snapshot of EOL DB to pass into remote scriptblocks
        $eolDbSerial = $script:LGEolDatabase | ForEach-Object {
            @{ Pattern = $_.Pattern; MatchType = $_.MatchType; EolDate = $_.EolDate }
        }

        $cfg      = Get-LGEffectiveConfig
        $warnD    = if ($WarnDays -gt 0) { $WarnDays } else { $cfg.WarnDaysBeforeExpiry }
        $inclEol  = $IncludeEol.IsPresent

        # The scriptblock that runs on each remote machine
        $remoteBlock = {
            param([int]$WarnDays, [bool]$IncludeEol, [array]$EolDb)

            # --- Windows Activation ---
            $winStatus = 'ERROR'; $winDetail = 'WMI query failed'
            try {
                $prod = Get-CimInstance -Query "SELECT LicenseStatus,GracePeriodRemaining FROM SoftwareLicensingProduct WHERE PartialProductKey IS NOT NULL AND ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f'"
                if ($prod) {
                    $row = $prod | Sort-Object LicenseStatus | Select-Object -First 1
                    $ls  = [int]$row.LicenseStatus
                    $sm  = @{0=@('Unlicensed','EXPIRED');1=@('Licensed','OK');2=@('OOBGrace','WARN');
                              3=@('OOTGrace','WARN');4=@('NonGenuineGrace','WARN');
                              5=@('Notification','WARN');6=@('ExtendedGrace','WARN')}
                    $mp  = if ($sm.ContainsKey($ls)) { $sm[$ls] } else { @('Unknown','WARN') }
                    $winDetail = if ($row.GracePeriodRemaining -gt 0) {
                        "$($mp[0]) -- Remaining: $([math]::Round($row.GracePeriodRemaining/1440,1)) days"
                    } else { $mp[0] }
                    $winStatus = $mp[1]
                }
            } catch {}

            # --- Installed Software ---
            $regPaths = @(
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
                'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
                'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
            )
            $today  = Get-Date
            $swRows = [System.Collections.Generic.List[PSCustomObject]]::new()
            foreach ($path in $regPaths) {
                Get-ItemProperty $path 2>$null |
                    Where-Object { $_.DisplayName -and -not $_.SystemComponent } |
                    ForEach-Object {
                        $status = 'OK'; $expInfo = ''
                        $expireDate = $null
                        foreach ($field in @('ExpirationDate','TrialExpireDate','ExpireDate','LicenseExpiry')) {
                            $val = $_.$field
                            if ($val) {
                                try { $expireDate = [datetime]$val; break } catch {}
                                if ($val -match '^\d{8}$') {
                                    try { $expireDate = [datetime]::ParseExact($val,'yyyyMMdd',$null); break } catch {}
                                }
                            }
                        }
                        if ($expireDate) {
                            $dl = ($expireDate - $today).Days
                            if ($dl -lt 0)         { $status='EXPIRED'; $expInfo="EXPIRED ($([math]::Abs($dl)) days ago)" }
                            elseif ($dl -le $WarnDays) { $status='WARN';    $expInfo="Expires: $($expireDate.ToString('yyyy-MM-dd')) ($dl days)" }
                            else                   { $expInfo="Valid: $($expireDate.ToString('yyyy-MM-dd'))" }
                        }
                        $swRows.Add([PSCustomObject]@{
                            Name       = $_.DisplayName
                            Version    = if ($_.DisplayVersion) { $_.DisplayVersion } else { '-' }
                            Publisher  = if ($_.Publisher)      { $_.Publisher }      else { 'Unknown' }
                            Status     = $status
                            ExpireInfo = $expInfo
                        })
                    }
            }
            $swRows = @($swRows | Sort-Object Name -Unique)

            # --- EOL (optional) ---
            $eolRows = [System.Collections.Generic.List[PSCustomObject]]::new()
            if ($IncludeEol -and $EolDb) {
                $today2 = Get-Date
                foreach ($sw in $swRows) {
                    foreach ($entry in $EolDb) {
                        $match = switch ($entry.MatchType) {
                            'contains'   { $sw.Name -like "*$($entry.Pattern)*" }
                            'startsWith' { $sw.Name -like "$($entry.Pattern)*"  }
                            'exact'      { $sw.Name -eq $entry.Pattern           }
                            'regex'      { $sw.Name -match $entry.Pattern        }
                            default      { $false }
                        }
                        if ($match) {
                            try {
                                $eolDate  = [datetime]::ParseExact($entry.EolDate,'yyyy-MM-dd',$null)
                                $daysLeft = ($eolDate - $today2).Days
                                $st       = if ($daysLeft -lt 0) { 'EXPIRED' } else { 'WARN' }
                                $det      = if ($daysLeft -lt 0) {
                                    "EOL: $($entry.EolDate) ($([math]::Abs($daysLeft)) days ago)"
                                } else { "EOL approaching: $($entry.EolDate) ($daysLeft days left)" }
                                $eolRows.Add([PSCustomObject]@{ Name=$sw.Name; Status=$st; Detail=$det })
                            } catch {}
                            break
                        }
                    }
                }
            }

            [PSCustomObject]@{
                ComputerName = $env:COMPUTERNAME
                WinStatus    = $winStatus
                WinDetail    = $winDetail
                Software     = $swRows
                EolFindings  = @($eolRows)
            }
        }
    }

    process {
        foreach ($c in $ComputerName) { $allComputers.Add($c.Trim()) }
    }

    end {
        if ($allComputers.Count -eq 0) { return }

        Write-Host "  Scanning $($allComputers.Count) machine(s) in parallel (throttle: $ThrottleLimit)..." -ForegroundColor Cyan

        $jobs    = [ordered]@{}   # pc -> job
        $queue   = [System.Collections.Generic.Queue[string]]::new()
        $allComputers | ForEach-Object { $queue.Enqueue($_) }
        $results = [System.Collections.Generic.List[PSCustomObject]]::new()

        while ($queue.Count -gt 0 -or $jobs.Count -gt 0) {

            # Launch up to ThrottleLimit jobs
            while ($queue.Count -gt 0 -and $jobs.Count -lt $ThrottleLimit) {
                $pc        = $queue.Dequeue()
                $jobParams = @{
                    ComputerName = $pc
                    ScriptBlock  = $remoteBlock
                    ArgumentList = $warnD, $inclEol, $eolDbSerial
                    AsJob        = $true
                    ErrorAction  = 'SilentlyContinue'
                }
                if ($Credential) { $jobParams.Credential = $Credential }
                try {
                    $jobs[$pc] = Invoke-Command @jobParams
                    Write-Verbose "Job launched: $pc"
                } catch {
                    $results.Add([PSCustomObject]@{
                        ComputerName = $pc; Module = 'Connection'
                        Name         = "$pc scan"; Status = 'ERROR'
                        Detail       = $_.Exception.Message; Version = ''; Publisher = ''
                    })
                }
            }

            # Collect finished jobs
            $done = @($jobs.Keys | Where-Object { $jobs[$_].State -in @('Completed','Failed') })
            foreach ($pc in $done) {
                $job = $jobs[$pc]
                try {
                    $data = Receive-Job $job -ErrorAction Stop
                    if ($data) {
                        $results.Add([PSCustomObject]@{
                            ComputerName = $pc; Module = 'WindowsActivation'
                            Name         = 'Windows Activation'
                            Status       = $data.WinStatus; Detail = $data.WinDetail
                            Version = ''; Publisher = ''
                        })
                        foreach ($sw in $data.Software) {
                            $results.Add([PSCustomObject]@{
                                ComputerName = $pc; Module = 'Software'
                                Name         = $sw.Name; Version = $sw.Version
                                Publisher    = $sw.Publisher; Status = $sw.Status
                                Detail       = $sw.ExpireInfo
                            })
                        }
                        foreach ($eol in $data.EolFindings) {
                            $results.Add([PSCustomObject]@{
                                ComputerName = $pc; Module = 'EOL'
                                Name         = $eol.Name; Status = $eol.Status
                                Detail       = $eol.Detail; Version = ''; Publisher = ''
                            })
                        }
                        Write-Host "  [$pc] done — $(@($data.Software).Count) apps" -ForegroundColor DarkGray
                    } elseif ($job.State -eq 'Failed') {
                        $results.Add([PSCustomObject]@{
                            ComputerName = $pc; Module = 'Connection'
                            Name         = "$pc scan"; Status = 'ERROR'
                            Detail       = 'Job failed'; Version = ''; Publisher = ''
                        })
                        Write-Host "  [$pc] ERROR — job failed" -ForegroundColor Red
                    }
                } catch {
                    $results.Add([PSCustomObject]@{
                        ComputerName = $pc; Module = 'Connection'
                        Name         = "$pc scan"; Status = 'ERROR'
                        Detail       = $_.Exception.Message; Version = ''; Publisher = ''
                    })
                    Write-Host "  [$pc] ERROR — $($_.Exception.Message)" -ForegroundColor Red
                }
                Remove-Job $job -Force -ErrorAction SilentlyContinue
                $jobs.Remove($pc)
            }

            if ($queue.Count -gt 0 -or $jobs.Count -gt 0) { Start-Sleep -Milliseconds 500 }
        }

        $results
    }
}
