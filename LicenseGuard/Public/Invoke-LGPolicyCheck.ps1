function Invoke-LGPolicyCheck {
    <#
    .SYNOPSIS
        Checks installed software against the policy rules in lg-policy.json.
    .EXAMPLE
        Invoke-LGPolicyCheck -PolicyPath .\lg-policy.json
    .EXAMPLE
        $sw = Get-LGInstalledSoftware
        Invoke-LGPolicyCheck -PolicyPath .\lg-policy.json -SoftwareCache $sw
    #>
    [CmdletBinding()]
    param(
        [string]$PolicyPath   = '.\lg-policy.json',
        [PSCustomObject[]]$SoftwareCache = $null
    )

    $L   = Get-LGEffectiveStrings
    $cfg = Get-LGEffectiveConfig
    Write-LGHeader $L['policySection']

    if (-not (Test-Path $PolicyPath)) {
        Write-Warning "Policy file not found: $PolicyPath"
        return @()
    }
    try {
        $policy = Get-Content $PolicyPath -Raw | ConvertFrom-Json
    } catch {
        Write-Warning "Could not read policy: $($_.Exception.Message)"
        return @()
    }

    $swRows = if ($SoftwareCache) {
        $SoftwareCache
    } else {
        Get-LGSoftwareRegistryRows -WarnDays $cfg.WarnDaysBeforeExpiry |
            ForEach-Object { [PSCustomObject]@{ Name=$_.Name; Version=$_.Version; Publisher=$_.Publisher } }
    }

    $findings = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($sw in $swRows) {
        # Whitelist
        $whitelisted = $false
        if ($cfg.Whitelist -and $cfg.Whitelist.Count -gt 0) {
            foreach ($wl in $cfg.Whitelist) {
                if ($sw.Name -like "*$wl*") { $whitelisted = $true; break }
            }
        }
        if ($whitelisted) {
            $findings.Add([PSCustomObject]@{
                Module       = 'PolicyCheck'; RuleId = 'WL'; Category = 'Whitelist'
                Name         = $sw.Name; Version = $sw.Version; Publisher = $sw.Publisher
                PolicyStatus = 'ALLOWED'; Status = 'OK'; Detail = $L['whitelist']
                Alternative  = ''; Reference = ''; Severity = 'LOW'
            })
            continue
        }

        # Rule matching
        $matched = $false
        foreach ($rule in $policy.rules) {
            $matchFieldProp = $rule.PSObject.Properties['matchField']
            $matchField = if ($matchFieldProp -and $matchFieldProp.Value) { $matchFieldProp.Value } else { 'name' }
            
            $fieldValue = if ($matchField -eq 'license') { 
                $prop = $sw.PSObject.Properties['License']
                if ($prop) { $prop.Value } else { '' }
            } else { 
                $sw.Name 
            }

            if (-not $fieldValue) { continue }

            $match = switch ($rule.matchType) {
                'contains'   { $fieldValue -like "*$($rule.pattern)*" }
                'startsWith' { $fieldValue -like "$($rule.pattern)*"  }
                'exact'      { $fieldValue -eq $rule.pattern           }
                'regex'      { $fieldValue -match $rule.pattern        }
                default      { $false }
            }
            if ($match) {
                $statusMap = @{ 'PROHIBITED'='EXPIRED'; 'REQUIRES_LICENSE'='WARN'; 'ALLOWED'='OK' }
                $sevProp   = $rule.PSObject.Properties['severity']
                $severity  = if ($sevProp -and $sevProp.Value) { $sevProp.Value } else {
                    switch ($rule.status) { 'PROHIBITED' { 'HIGH' } 'REQUIRES_LICENSE' { 'MEDIUM' } default { 'LOW' } }
                }
                $altProp   = $rule.PSObject.Properties['alternative']
                $refProp   = $rule.PSObject.Properties['referenceUrl']
                $swDetailProp = $sw.PSObject.Properties['Detail']
                $swDetail = if ($swDetailProp) { $swDetailProp.Value } else { '' }
                $detailVal = if ($swDetail) { "$($rule.reason) | $swDetail" } else { $rule.reason }

                $findings.Add([PSCustomObject]@{
                    Module       = 'PolicyCheck'; RuleId = $rule.id; Category = $rule.category
                    Name         = $sw.Name; Version = $sw.Version; Publisher = $sw.Publisher
                    PolicyStatus = $rule.status; Status = $statusMap[$rule.status]; Detail = $detailVal
                    Alternative  = if ($altProp) { $altProp.Value } else { '' }
                    Reference    = if ($refProp) { $refProp.Value } else { '' }
                    Severity     = $severity
                })
                $matched = $true; break
            }
        }

        if (-not $matched) {
            $findings.Add([PSCustomObject]@{
                Module       = 'PolicyCheck'; RuleId = 'N/A'; Category = 'N/A'
                Name         = $sw.Name; Version = $sw.Version; Publisher = $sw.Publisher
                PolicyStatus = 'ALLOWED'; Status = 'OK'; Detail = $L['noRule']
                Alternative  = ''; Reference = ''; Severity = 'LOW'
            })
        }
    }

    $proh = @($findings | Where-Object { $_.PolicyStatus -eq 'PROHIBITED' })
    $lic  = @($findings | Where-Object { $_.PolicyStatus -eq 'REQUIRES_LICENSE' })
    $ok   = @($findings | Where-Object { $_.PolicyStatus -eq 'ALLOWED' })

    foreach ($f in $findings) {
        $suffix = if ($f.RuleId -notin @('N/A','WL')) { " [$($f.RuleId)]" } else { '' }
        Write-LGStatus ($f.Name + $suffix) $f.Detail $f.Status
        if ($f.Status -ne 'OK') {
            if ($f.Detail)      { Write-Host "    Reason:     $($f.Detail)"      -ForegroundColor DarkGray }
            if ($f.Alternative) { Write-Host "    Suggestion: $($f.Alternative)" -ForegroundColor DarkCyan }
        }
    }

    Write-Host ("`n  $($findings.Count) matched -- $($proh.Count) $($L['prohibited'])  $($lic.Count) $($L['requiresLicense'])  $($ok.Count) $($L['allowed'])") -ForegroundColor Cyan
    $findings
}
