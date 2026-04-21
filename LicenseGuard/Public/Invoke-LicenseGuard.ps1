function Invoke-LicenseGuard {
    <#
    .SYNOPSIS
        Main entry point — runs a full compliance scan and generates all outputs.
    .EXAMPLE
        Invoke-LicenseGuard
    .EXAMPLE
        Invoke-LicenseGuard -ConfigPath .\lg-config.json -Language en -ExportCsv .\out.csv
    .EXAMPLE
        # Scan AD workstations
        Get-LGADComputers -SearchBase 'OU=Workstations,DC=corp,DC=local' |
            Invoke-LGRemoteScan | ForEach-Object { ... }
    #>
    [CmdletBinding()]
    param(
        [string]$ConfigPath       = '.\lg-config.json',
        [string]$OutputPath       = '.\license-report.html',
        [string]$PolicyPath       = '.\lg-policy.json',
        [ValidateSet('tr','en')]
        [string]$Language         = 'tr',
        [string]$ExportCsv        = '',
        [string]$ExportJson       = '',
        [string]$SarifPath        = '',
        [switch]$ConsoleOnly,
        [switch]$SendMail,
        [switch]$NoDelta,
        [switch]$TestPolicy,
        [switch]$CheckSignatures,
        [switch]$NoUpdateCheck,
        [switch]$CreateJiraIssues
    )

    Initialize-LicenseGuard -ConfigPath $ConfigPath -Language $Language

    $cfg   = Get-LGEffectiveConfig
    $L     = Get-LGEffectiveStrings

    # Version check
    if (-not $NoUpdateCheck) {
        try {
            $rel    = Invoke-RestMethod -Uri 'https://api.github.com/repos/mustafasercansak/LicenseGuard/releases/latest' -TimeoutSec 5 -UseBasicParsing
            $latest = $rel.tag_name.TrimStart('v')
            if ($latest -and $latest -ne $script:LGVersion) {
                Write-Host "  [UPDATE] $($L['updateAvail']): v$latest (current: v$($script:LGVersion))" -ForegroundColor Yellow
            } else {
                Write-Host "  $($L['updateCurrent']): v$($script:LGVersion)" -ForegroundColor DarkGray
            }
        } catch {}
    }

    # Policy test mode
    if ($TestPolicy) {
        if (-not (Test-Path $PolicyPath)) { Write-Error "Policy file not found: $PolicyPath"; exit 1 }
        $pol = Get-Content $PolicyPath -Raw | ConvertFrom-Json
        Write-Host "`n  Policy: $PolicyPath  |  Rules: $($pol.rules.Count)`n" -ForegroundColor Cyan
        $pol.rules | ForEach-Object {
            $icon  = switch ($_.status) { 'PROHIBITED' { '[XX]' } 'REQUIRES_LICENSE' { '[!!]' } default { '[OK]' } }
            $color = switch ($_.status) { 'PROHIBITED' { 'Red' }  'REQUIRES_LICENSE' { 'Yellow' }          default { 'Green' } }
            Write-Host ("  $icon [$($_.id)] $($_.category.PadRight(25)) $($_.pattern) ($($_.matchType))") -ForegroundColor $color
        }
        return
    }

    Write-Host "`n  $($L['starting'])`n" -ForegroundColor White

    $brandColor   = if ($cfg.Branding?.PrimaryColor) { $cfg.Branding.PrimaryColor } else { '#3b82f6' }
    $brandCompany = if ($cfg.Branding?.CompanyName)  { $cfg.Branding.CompanyName  } else { '' }

    $allResults     = [System.Collections.Generic.List[PSCustomObject]]::new()
    $policyFindings = @()

    # Local scans
    $r = Get-LGWindowsActivation; if ($r) { $allResults.Add($r) }
    $r = Get-LGOfficeLicense;     if ($r) { $r | ForEach-Object { $allResults.Add($_) } }

    $swCache = Get-LGSoftwareRegistryRows -WarnDays $cfg.WarnDaysBeforeExpiry -UnknownLabel $L['publisherUnknown']
    $r = Get-LGInstalledSoftware; if ($r) { $r | ForEach-Object { $allResults.Add($_) } }

    if ($cfg.EolCheck -ne $false) {
        $r = Get-LGEolStatus -SoftwareCache $swCache; if ($r) { $r | ForEach-Object { $allResults.Add($_) } }
    }
    if ($cfg.ScanBrowserExtensions -ne $false) {
        $r = Get-LGBrowserExtensions; if ($r) { $r | ForEach-Object { $allResults.Add($_) } }
    }
    if ($cfg.ScanVsCodeExtensions -ne $false) {
        $r = Get-LGVsCodeExtensions; if ($r) { $r | ForEach-Object { $allResults.Add($_) } }
    }
    if ($cfg.ScanStartup -ne $false) {
        $r = Get-LGStartupAudit; if ($r) { $r | ForEach-Object { $allResults.Add($_) } }
    }

    $r = Get-LGFlexLMStatus; if ($r) { $r | ForEach-Object { $allResults.Add($_) } }
    $r = Get-LGSaaSStatus;   if ($r) { $r | ForEach-Object { $allResults.Add($_) } }

    # Policy check
    $policyFindings = @(Invoke-LGPolicyCheck -PolicyPath $PolicyPath -SoftwareCache $swCache)

    # Post-policy scans
    $r = Get-LGRunningProcesses -PolicyFindings $policyFindings; if ($r) { $r | ForEach-Object { $allResults.Add($_) } }
    if ($CheckSignatures) {
        $r = Get-LGSignatureAudit -PolicyFindings $policyFindings; if ($r) { $r | ForEach-Object { $allResults.Add($_) } }
    }

    # Delta
    $delta = $null
    if (-not $NoDelta) {
        $delta = Get-LGDelta -CurrentResults $allResults -CurrentPolicyFindings $policyFindings
        Save-LGSnapshot -AllResults $allResults -PolicyFindings $policyFindings
    }

    # Reports
    if (-not $ConsoleOnly) {
        Export-LGHtmlReport -AllResults $allResults -PolicyFindings $policyFindings `
            -OutputPath $OutputPath -Delta $delta -BrandColor $brandColor `
            -BrandCompany $brandCompany -Language $Language
    }
    if ($ExportCsv)  { Export-LGCsvReport  -AllResults $allResults -PolicyFindings $policyFindings -CsvPath  $ExportCsv  }
    if ($ExportJson) { Export-LGJsonReport -AllResults $allResults -PolicyFindings $policyFindings -JsonPath $ExportJson }
    if ($SarifPath)  { Export-LGSarifReport -PolicyFindings $policyFindings -SarifPath $SarifPath }

    if ($CreateJiraIssues) { New-LGJiraIssues -PolicyFindings $policyFindings }

    # Summary
    $criticalLicense = @($allResults     | Where-Object { $_.Status     -in @('EXPIRED','ERROR') })
    $prohibited      = @($policyFindings | Where-Object { $_.PolicyStatus -eq 'PROHIBITED'       })
    $needsLic        = @($policyFindings | Where-Object { $_.PolicyStatus -eq 'REQUIRES_LICENSE' })

    $evtType = if ($criticalLicense -or $prohibited) { 'Error' } elseif ($needsLic) { 'Warning' } else { 'Information' }
    $evtId   = if ($criticalLicense -or $prohibited) { 1002 } elseif ($needsLic) { 1001 } else { 1000 }
    Write-LGEventLog -Message "LicenseGuard v$($script:LGVersion). Critical:$($criticalLicense.Count) Prohibited:$($prohibited.Count) NeedsLic:$($needsLic.Count)" `
        -EntryType $evtType -EventId $evtId

    Write-Host ''
    if ($criticalLicense) { Write-Host "  [!!] $($criticalLicense.Count) $($L['criticalCount'])"   -ForegroundColor Red    }
    if ($prohibited)      { Write-Host "  [XX] $($prohibited.Count) $($L['prohibitedFound'])"       -ForegroundColor Red    }
    if ($needsLic)        { Write-Host "  [!]  $($needsLic.Count) $($L['needsLicCount'])"           -ForegroundColor Yellow }
    if (-not $criticalLicense -and -not $prohibited -and -not $needsLic) {
        Write-Host "  [OK] $($L['allClear'])" -ForegroundColor Green
    }

    # Webhook
    if ($cfg.Webhook) {
        $wbColor   = if ($prohibited) { 'FF0000' } elseif ($criticalLicense -or $needsLic) { 'FFA500' } else { '00CC44' }
        $wbTitle   = if ($prohibited) { 'Prohibited Software Detected!' } elseif ($criticalLicense) { 'Critical License Issue' } else { 'Scan Complete' }
        $wbSummary = "$env:COMPUTERNAME | Prohibited:$($prohibited.Count) Critical:$($criticalLicense.Count) NeedsLic:$($needsLic.Count)"
        Send-LGWebhookNotification -Title $wbTitle -Summary $wbSummary -Color $wbColor
    }

    # Email
    if ($SendMail) {
        $summary = "LicenseGuard v$($script:LGVersion) -- $env:COMPUTERNAME`nCritical: $($criticalLicense.Count) | Prohibited: $($prohibited.Count) | Needs License: $($needsLic.Count)"
        Send-LGMailReport -ReportPath $OutputPath -Summary $summary
    }

    Write-Host ''
    if ($criticalLicense -or $prohibited) { exit 1 }
}
