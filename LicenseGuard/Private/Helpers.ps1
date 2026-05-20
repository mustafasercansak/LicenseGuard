function Write-LGHeader {
    param([string]$Text)
    Write-Host "`n+------------------------------------------+" -ForegroundColor Cyan
    Write-Host   "|  $($Text.PadRight(40))|" -ForegroundColor Cyan
    Write-Host   "+------------------------------------------+" -ForegroundColor Cyan
}

function Write-LGStatus {
    param([string]$Label, [string]$Value, [string]$Status)
    $color = switch ($Status) {
        'OK'      { 'Green'  }
        'WARN'    { 'Yellow' }
        'EXPIRED' { 'Red'    }
        'ERROR'   { 'Red'    }
        default   { 'Gray'   }
    }
    $icon = switch ($Status) {
        'OK'      { '[OK]' }
        'WARN'    { '[!!]' }
        'EXPIRED' { '[XX]' }
        'ERROR'   { '[XX]' }
        default   { '[--]' }
    }
    Write-Host ("  {0} {1,-38} {2}" -f $icon, $Label, $Value) -ForegroundColor $color
}

function Protect-HtmlString {
    param([string]$s)
    $s -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;'
}

function Get-LGLicenseAuditStatus {
    param(
        [string]$License,
        [bool]$HasMissingAttribution = $false
    )

    $lic = if ([string]::IsNullOrWhiteSpace($License)) { 'Unknown' } else { $License }

    if ($lic -match '(?i)(^|[^A-Za-z])(AGPL|GPL)([^A-Za-z]|$)' -or
        $lic -match '(?i)SSPL|BUSL|Commons Clause|PolyForm|Elastic License|Server Side Public License|Business Source License') {
        return 'EXPIRED'
    }

    if ($lic -match '(?i)(^|[^A-Za-z])(LGPL|MPL|EPL|CDDL)([^A-Za-z]|$)' -or
        $lic -match '(?i)^Unknown$|NOASSERTION|UNLICENSED|SEE LICENSE') {
        return 'WARN'
    }

    if ($HasMissingAttribution) {
        return 'WARN'
    }

    'OK'
}

function Write-LGEventLog {
    param([string]$Message, [string]$EntryType = 'Information', [int]$EventId = 1000)
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists('LicenseGuard')) {
            [System.Diagnostics.EventLog]::CreateEventSource('LicenseGuard', 'Application')
        }
        Write-EventLog -LogName 'Application' -Source 'LicenseGuard' `
            -EventId $EventId -EntryType $EntryType -Message $Message
    } catch {}
}

function Get-LGSoftwareRegistryRows {
    param([int]$WarnDays = 30, [string]$UnknownLabel = 'Unknown')
    $regPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $today = Get-Date
    $rows  = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($path in $regPaths) {
        Get-ItemProperty $path 2>$null |
            Where-Object { $_.DisplayName -and -not $_.SystemComponent } |
            ForEach-Object {
                $installDate = $null
                if ($_.InstallDate -match '^\d{8}$') {
                    try { $installDate = [datetime]::ParseExact($_.InstallDate, 'yyyyMMdd', $null) } catch {}
                }
                $expireDate = $null
                foreach ($field in @('ExpirationDate','TrialExpireDate','ExpireDate','LicenseExpiry')) {
                    $val = $_.$field
                    if ($val) {
                        try { $expireDate = [datetime]$val; break } catch {}
                        if ($val -match '^\d{8}$') {
                            try { $expireDate = [datetime]::ParseExact($val, 'yyyyMMdd', $null); break } catch {}
                        }
                    }
                }
                $status  = 'OK'
                $expInfo = ''
                if ($expireDate) {
                    $dl = ($expireDate - $today).Days
                    if ($dl -lt 0) {
                        $status  = 'EXPIRED'
                        $expInfo = "EXPIRED ($([math]::Abs($dl)) days ago)"
                    } elseif ($dl -le $WarnDays) {
                        $status  = 'WARN'
                        $expInfo = "Expires: $($expireDate.ToString('yyyy-MM-dd')) ($dl days)"
                    } else {
                        $expInfo = "Valid: $($expireDate.ToString('yyyy-MM-dd'))"
                    }
                }
                $rows.Add([PSCustomObject]@{
                    Name        = $_.DisplayName
                    Version     = if ($_.DisplayVersion) { $_.DisplayVersion } else { '-' }
                    Publisher   = if ($_.Publisher) { $_.Publisher } else { $UnknownLabel }
                    InstallDate = if ($installDate) { $installDate.ToString('yyyy-MM-dd') } else { '-' }
                    ExpireInfo  = $expInfo
                    Status      = $status
                })
            }
    }
    $rows | Sort-Object Name -Unique
}
