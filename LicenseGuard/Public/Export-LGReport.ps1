function Export-LGCsvReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCustomObject[]]$AllResults,
        [Parameter(Mandatory)][PSCustomObject[]]$PolicyFindings,
        [Parameter(Mandatory)][string]$CsvPath
    )
    try {
        $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($r in $AllResults) {
            $rows.Add([PSCustomObject]@{
                Type='LicenseStatus'; Module=$r.Module; Name=$r.Name
                Detail=if($r.Detail){$r.Detail}else{''}
                Status=$r.Status; PolicyStatus=''; Category=''; Severity=''
            })
        }
        foreach ($f in $PolicyFindings) {
            $rows.Add([PSCustomObject]@{
                Type='PolicyCheck'; Module='PolicyCheck'; Name=$f.Name
                Detail=if($f.Detail){$f.Detail}else{''}
                Status=$f.Status; PolicyStatus=$f.PolicyStatus
                Category=if($f.Category){$f.Category}else{''}
                Severity=if($f.Severity){$f.Severity}else{''}
            })
        }
        $rows | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
        Write-Host "  CSV report saved: $CsvPath" -ForegroundColor Cyan
    } catch { Write-Warning "CSV error: $($_.Exception.Message)" }
}

function Export-LGJsonReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCustomObject[]]$AllResults,
        [Parameter(Mandatory)][PSCustomObject[]]$PolicyFindings,
        [Parameter(Mandatory)][string]$JsonPath
    )
    try {
        [PSCustomObject]@{
            Timestamp      = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            Hostname       = $env:COMPUTERNAME
            Version        = $script:LGVersion
            LicenseStatus  = $AllResults
            PolicyFindings = $PolicyFindings
        } | ConvertTo-Json -Depth 5 | Out-File $JsonPath -Encoding UTF8
        Write-Host "  JSON report saved: $JsonPath" -ForegroundColor Cyan
    } catch { Write-Warning "JSON error: $($_.Exception.Message)" }
}

function Export-LGSarifReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCustomObject[]]$PolicyFindings,
        [Parameter(Mandatory)][string]$SarifPath
    )
    try {
        $rules = @(); $results = @(); $seen = @{}
        foreach ($f in ($PolicyFindings | Where-Object { $_.PolicyStatus -ne 'ALLOWED' })) {
            $rid = if ($f.RuleId -and $f.RuleId -ne 'N/A') { $f.RuleId } else { 'LG-POLICY' }
            if (-not $seen.ContainsKey($rid)) {
                $seen[$rid] = $true
                $rules += [PSCustomObject]@{
                    id               = $rid
                    name             = "LicensePolicy_$rid"
                    shortDescription = [PSCustomObject]@{ text = $f.Detail }
                    properties       = [PSCustomObject]@{ category = $f.Category; severity = $f.Severity }
                }
            }
            $level   = switch ($f.PolicyStatus) { 'PROHIBITED' { 'error' } 'REQUIRES_LICENSE' { 'warning' } default { 'note' } }
            $results += [PSCustomObject]@{
                ruleId    = $rid; level = $level
                message   = [PSCustomObject]@{ text = "$($f.Name): $($f.Detail)" }
                locations = @([PSCustomObject]@{ logicalLocations = @([PSCustomObject]@{ name=$env:COMPUTERNAME; kind='machine' }) })
            }
        }
        [PSCustomObject]@{
            '`$schema' = 'https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json'
            version    = '2.1.0'
            runs       = @([PSCustomObject]@{
                tool    = [PSCustomObject]@{ driver = [PSCustomObject]@{ name='LicenseGuard'; version=$script:LGVersion; rules=$rules } }
                results = $results
            })
        } | ConvertTo-Json -Depth 10 | Out-File $SarifPath -Encoding UTF8
        Write-Host "  SARIF report saved: $SarifPath" -ForegroundColor Cyan
    } catch { Write-Warning "SARIF error: $($_.Exception.Message)" }
}

function Export-LGHtmlReport {
    <#
    .SYNOPSIS
        Generates a full interactive HTML compliance report.
    .EXAMPLE
        Export-LGHtmlReport -AllResults $results -PolicyFindings $policy -OutputPath .\report.html
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][PSCustomObject[]]$AllResults,
        [Parameter(Mandatory)][PSCustomObject[]]$PolicyFindings,
        [string]$OutputPath   = '.\license-report.html',
        [object]$Delta        = $null,
        [string]$BrandColor   = '#3b82f6',
        [string]$BrandCompany = '',
        [ValidateSet('tr','en')]
        [string]$Language     = 'tr'
    )

    $L        = Get-LGDefaultStrings -Language $Language
    $cfg      = Get-LGEffectiveConfig
    $warnDays = $cfg.WarnDaysBeforeExpiry
    $ts       = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $hostname = $env:COMPUTERNAME
    $ver      = $script:LGVersion

    $total     = if ($AllResults.Count -gt 0) { $AllResults.Count } else { 1 }
    $okCount   = @($AllResults | Where-Object { $_.Status -eq 'OK'                  }).Count
    $warnCount = @($AllResults | Where-Object { $_.Status -eq 'WARN'                }).Count
    $expCount  = @($AllResults | Where-Object { $_.Status -in @('EXPIRED','ERROR')  }).Count
    $okPct     = [math]::Round($okCount   / $total * 100)
    $warnPct   = [math]::Round($warnCount / $total * 100)
    $expPct    = [math]::Round($expCount  / $total * 100)

    $tableRows = ($AllResults | ForEach-Object {
        $bc   = switch ($_.Status) { 'OK' { 'ok' } 'WARN' { 'warn' } default { 'expired' } }
        $trTx = switch ($_.Status) { 'OK' { 'UYUMLU' } 'WARN' { 'UYARI' } 'EXPIRED' { 'SURESI DOLDU' } default { 'HATA' } }
        $enTx = switch ($_.Status) { 'OK' { 'OK' } 'WARN' { 'WARNING' } 'EXPIRED' { 'EXPIRED' } default { 'ERROR' } }
        $det  = if ($_.Detail) { Protect-HtmlString $_.Detail } else { '&mdash;' }
        "<tr data-status='$($_.Status)'><td><span class='mod-pill' data-mod='$($_.Module)'>$($_.Module)</span></td><td>$(Protect-HtmlString $_.Name)</td><td>$det</td><td><span class='badge $bc' data-val-tr='$trTx' data-val-en='$enTx'>$trTx</span></td></tr>"
    }) -join "`n"

    $prohibCount=0; $licCount=0; $allowedCount=0; $prohibPct=0; $licPct=0; $allowedPct=0; $policyRows=''
    if ($PolicyFindings -and $PolicyFindings.Count -gt 0) {
        $pTotal       = $PolicyFindings.Count
        $prohibCount  = @($PolicyFindings | Where-Object { $_.PolicyStatus -eq 'PROHIBITED'       }).Count
        $licCount     = @($PolicyFindings | Where-Object { $_.PolicyStatus -eq 'REQUIRES_LICENSE' }).Count
        $allowedCount = @($PolicyFindings | Where-Object { $_.PolicyStatus -eq 'ALLOWED'          }).Count
        $prohibPct    = [math]::Round($prohibCount  / $pTotal * 100)
        $licPct       = [math]::Round($licCount     / $pTotal * 100)
        $allowedPct   = [math]::Round($allowedCount / $pTotal * 100)
        $policyRows   = ($PolicyFindings | ForEach-Object {
            $bc    = switch ($_.PolicyStatus) { 'PROHIBITED' { 'expired' } 'REQUIRES_LICENSE' { 'warn' } default { 'ok' } }
            $lblTr = switch ($_.PolicyStatus) { 'PROHIBITED' { 'YASAK' } 'REQUIRES_LICENSE' { 'LISANS GEREKLI' } default { 'UYUMLU' } }
            $lblEn = switch ($_.PolicyStatus) { 'PROHIBITED' { 'PROHIBITED' } 'REQUIRES_LICENSE' { 'REQUIRES LICENSE' } default { 'COMPLIANT' } }
            $sevCls= switch ($_.Severity) { 'CRITICAL' { 'critical' } 'HIGH' { 'high' } 'MEDIUM' { 'medium' } default { 'low' } }
            $sevPill = if ($_.PolicyStatus -ne 'ALLOWED' -and $_.Severity) { "<span class='sev-pill $sevCls'>$($_.Severity)</span>" } else { '' }
            $alt   = if ($_.Alternative) { "<br><small class='suggestion'>&#x1F4A1; $(Protect-HtmlString $_.Alternative)</small>" } else { '' }
            $ref   = if ($_.Reference)   { " <a href='$(Protect-HtmlString $_.Reference)' target='_blank' class='reflink'>&#x2197;</a>" } else { '' }
            "<tr data-policy='$($_.PolicyStatus)'><td>$(Protect-HtmlString $_.Category)$sevPill</td><td><span class='sw-name'>$(Protect-HtmlString $_.Name)</span><br><small class='sw-meta'>$(Protect-HtmlString $_.Version) &middot; $(Protect-HtmlString $_.Publisher)</small></td><td>$(Protect-HtmlString $_.Detail)$alt$ref</td><td><span class='badge $bc' data-val-tr='$lblTr' data-val-en='$lblEn'>$lblTr</span></td></tr>"
        }) -join "`n"
    }

    $calToday = Get-Date; $calParts = @()
    foreach ($r in $AllResults) {
        if ($r.Detail -and $r.Detail -match '(\d{4}-\d{2}-\d{2})') {
            $dateStr = $Matches[1]
            try {
                $expDate = [datetime]$dateStr
                $days    = [int]($expDate - $calToday).TotalDays
                $nm = ($r.Name    -replace '\\','\\' -replace '"','\"')
                $md = ($r.Module  -replace '"','\"')
                $st = ($r.Status  -replace '"','\"')
                $calParts += "{`"name`":`"$nm`",`"module`":`"$md`",`"date`":`"$dateStr`",`"days`":$days,`"status`":`"$st`"}"
            } catch {}
        }
    }
    $calJson = '[' + ($calParts -join ',') + ']'

    $deltaBoxHtml = ''
    if ($Delta) {
        $ni = if ($Delta.NewIssues)          { @($Delta.NewIssues).Count }          else { 0 }
        $ri = if ($Delta.ResolvedIssues)     { @($Delta.ResolvedIssues).Count }     else { 0 }
        $nv = if ($Delta.NewViolations)      { @($Delta.NewViolations).Count }      else { 0 }
        $rv = if ($Delta.ResolvedViolations) { @($Delta.ResolvedViolations).Count } else { 0 }
        if (($ni + $ri + $nv + $rv) -gt 0) {
            $dParts = @()
            if ($ni -gt 0) { $dParts += "<span class='delta-new'>&#x25B2; $ni $($L['deltaNew'])</span>" }
            if ($ri -gt 0) { $dParts += "<span class='delta-ok'>&#x25BC; $ri $($L['deltaResolved'])</span>" }
            if ($nv -gt 0) { $dParts += "<span class='delta-new'>&#x25B2; $nv policy $($L['deltaNew'])</span>" }
            if ($rv -gt 0) { $dParts += "<span class='delta-ok'>&#x25BC; $rv policy $($L['deltaResolved'])</span>" }
            $deltaBoxHtml = "<div class='delta-box'><span class='delta-lbl'>$($L['deltaTitle'])</span> &mdash; $($L['deltaSince']) <b>$($Delta.PreviousTimestamp)</b> &nbsp; $($dParts -join ' &middot; ')</div>"
        }
    }

    $initLang   = $Language
    $brandSpan  = if ($BrandCompany) { "<span style='font-size:.72rem;color:var(--tx3);margin-left:.4rem'>&mdash; $(Protect-HtmlString $BrandCompany)</span>" } else { '' }

    $html = @"
<!DOCTYPE html>
<html lang="$initLang" id="htmlRoot">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title data-i18n="pageTitle">LicenseGuard Raporu</title>
<style>
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{--bg:#080d18;--sf:#0f1623;--sf2:#161e2e;--sf3:#1c2740;--bd:#1e293b;--bd2:#263347;--tx:#e2e8f0;--tx2:#94a3b8;--tx3:#475569;--blue:$BrandColor;--green:#22c55e;--yellow:#f59e0b;--red:#ef4444;--r:10px;}
html{scroll-behavior:smooth}
body{font-family:'Segoe UI',system-ui,sans-serif;background:var(--bg);color:var(--tx);height:100vh;overflow:hidden;font-size:14px;line-height:1.5}
.hdr{position:sticky;top:0;z-index:200;background:rgba(8,13,24,.9);backdrop-filter:blur(12px);border-bottom:1px solid var(--bd);padding:0 1.5rem;display:flex;align-items:center;height:54px;gap:1rem}
.hdr-brand{display:flex;align-items:center;gap:.55rem;flex:1}
.hdr-brand h1{font-size:.95rem;font-weight:700;color:var(--tx);letter-spacing:-.01em}
.hdr-brand h1 span{color:var(--blue)}
.hdr-meta{font-size:.72rem;color:var(--tx3);white-space:nowrap}
.hdr-meta b{color:var(--tx2)}
.btn-lang{background:var(--sf2);border:1px solid var(--bd2);color:var(--tx2);padding:.28rem .7rem;border-radius:6px;cursor:pointer;font-size:.7rem;font-weight:700;letter-spacing:.06em;transition:all .15s}
.btn-lang:hover{background:var(--sf3);border-color:var(--blue);color:var(--blue)}
.layout{display:flex;height:calc(100vh - 54px);overflow:hidden}
.sidebar{width:210px;flex-shrink:0;background:var(--sf);border-right:1px solid var(--bd);padding:1.25rem 0;position:sticky;top:54px;height:calc(100vh - 54px);overflow-y:auto}
.main{flex:1;min-width:0;padding:1.75rem;height:calc(100vh - 54px);overflow:hidden;display:flex;flex-direction:column}
.nav-sec{padding:0 1rem .4rem;font-size:.62rem;font-weight:700;color:var(--tx3);text-transform:uppercase;letter-spacing:.1em;margin-top:.75rem}
.nav-item{display:flex;align-items:center;gap:.6rem;padding:.5rem .9rem;margin:.08rem .6rem;border-radius:8px;cursor:pointer;font-size:.8rem;color:var(--tx2);transition:all .15s;user-select:none;border:1px solid transparent}
.nav-item:hover{background:var(--sf2);color:var(--tx)}
.nav-item.active{background:rgba(59,130,246,.12);color:var(--blue);border-color:rgba(59,130,246,.2);font-weight:600}
.nav-icon{font-size:.95rem;width:18px;text-align:center;flex-shrink:0}
.nav-badge{margin-left:auto;font-size:.62rem;font-weight:700;padding:.08rem .42rem;border-radius:20px;background:var(--sf3);color:var(--tx3)}
.nav-badge.red{background:rgba(239,68,68,.15);color:var(--red)}
.nav-badge.yellow{background:rgba(245,158,11,.15);color:var(--yellow)}
.nav-divider{height:1px;background:var(--bd);margin:.9rem .6rem}
.health-box{margin:.25rem .6rem 1rem;background:var(--sf2);border:1px solid var(--bd2);border-radius:var(--r);padding:.9rem;text-align:center}
.health-lbl{font-size:.62rem;color:var(--tx3);text-transform:uppercase;letter-spacing:.07em;margin-bottom:.6rem}
.donut-wrap{position:relative;width:76px;height:76px;margin:0 auto .6rem}
.donut-wrap svg{width:76px;height:76px}
.donut-inner{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center}
.donut-pct{font-size:1.05rem;font-weight:700}
.donut-sub{font-size:.58rem;color:var(--tx3);text-transform:uppercase;letter-spacing:.05em}
.tab-pane{display:none}.tab-pane.active{display:flex;flex-direction:column;flex:1;min-height:0;overflow:hidden}
.sec-head{display:flex;align-items:center;gap:.65rem;margin-bottom:1.1rem;flex-shrink:0}
.sec-head h2{font-size:.95rem;font-weight:600;color:var(--tx)}
.stat-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(120px,1fr));gap:.65rem;margin-bottom:1.35rem;flex-shrink:0}
.sc{background:var(--sf);border:1px solid var(--bd);border-radius:var(--r);padding:.9rem 1rem;transition:transform .15s,box-shadow .15s;position:relative;overflow:hidden}
.sc::before{content:'';position:absolute;top:0;left:0;right:0;height:2px}
.sc.ok::before{background:var(--green)}.sc.warn::before{background:var(--yellow)}.sc.exp::before{background:var(--red)}
.sc:hover{transform:translateY(-2px);box-shadow:0 8px 24px rgba(0,0,0,.4)}
.sc-ico{font-size:1.1rem;margin-bottom:.4rem}
.sc-num{font-size:1.65rem;font-weight:700;line-height:1;margin-bottom:.15rem}
.sc.ok .sc-num{color:var(--green)}.sc.warn .sc-num{color:var(--yellow)}.sc.exp .sc-num{color:var(--red)}
.sc-lbl{font-size:.65rem;color:var(--tx3);text-transform:uppercase;letter-spacing:.07em}
.sc-bar{height:3px;background:var(--bd2);border-radius:2px;margin-top:.6rem;overflow:hidden}
.sc-bar-fill{height:100%;border-radius:2px;width:0;transition:width .7s ease}
.sc.ok .sc-bar-fill{background:var(--green)}.sc.warn .sc-bar-fill{background:var(--yellow)}.sc.exp .sc-bar-fill{background:var(--red)}
.sc-pct{font-size:.62rem;color:var(--tx3);margin-top:.15rem}
.toolbar{display:flex;gap:.6rem;align-items:center;margin-bottom:.7rem;flex-wrap:wrap;flex-shrink:0}
.search-wrap{position:relative;flex:1;min-width:180px;max-width:380px}
.search-ico{position:absolute;left:.6rem;top:50%;transform:translateY(-50%);width:13px;height:13px;fill:var(--tx3);pointer-events:none}
.search-input{width:100%;background:var(--sf);border:1px solid var(--bd2);color:var(--tx);padding:.42rem .7rem .42rem 1.9rem;border-radius:8px;font-size:.82rem;outline:none;transition:border-color .15s}
.search-input:focus{border-color:var(--blue);box-shadow:0 0 0 3px rgba(59,130,246,.12)}
.search-input::placeholder{color:var(--tx3)}
.filter-chip{display:flex;align-items:center;gap:.38rem;padding:.4rem .7rem;background:var(--sf);border:1px solid var(--bd2);border-radius:8px;font-size:.76rem;color:var(--tx2);cursor:pointer;user-select:none;transition:all .15s;white-space:nowrap}
.filter-chip:has(input:checked){background:rgba(59,130,246,.1);border-color:rgba(59,130,246,.3);color:var(--blue)}
.filter-chip input{accent-color:var(--blue);cursor:pointer}
.rc{font-size:.72rem;color:var(--tx3);margin-left:auto;white-space:nowrap}
.btn-exp{background:var(--sf);border:1px solid var(--bd2);color:var(--tx2);padding:.38rem .7rem;border-radius:8px;cursor:pointer;font-size:.73rem;transition:all .15s;white-space:nowrap}
.btn-exp:hover{background:var(--sf3);border-color:var(--blue);color:var(--blue)}
.delta-box{background:rgba(59,130,246,.07);border:1px solid rgba(59,130,246,.2);border-radius:8px;padding:.55rem 1rem;margin-bottom:.8rem;font-size:.78rem;color:var(--tx2);flex-shrink:0}
.delta-lbl{font-weight:700;color:var(--blue)}
.delta-new{color:var(--red);font-weight:600}
.delta-ok{color:var(--green);font-weight:600}
.table-wrap{border-radius:var(--r);border:1px solid var(--bd);overflow-y:auto;flex:1;min-height:0}
table{width:100%;border-collapse:collapse;background:var(--sf);font-size:.82rem}
thead tr{background:var(--sf2)}thead th{position:sticky;top:0;z-index:1}
th{padding:.6rem 1rem;text-align:left;font-size:.65rem;font-weight:700;text-transform:uppercase;letter-spacing:.07em;color:var(--tx3);white-space:nowrap;border-bottom:1px solid var(--bd)}
th.sortable{cursor:pointer;user-select:none}
th.sortable:hover{color:var(--tx2)}
th.sort-asc::after{content:' \2191';color:var(--blue)}
th.sort-desc::after{content:' \2193';color:var(--blue)}
td{padding:.65rem 1rem;border-top:1px solid var(--bd);vertical-align:middle}
tr:hover td{background:var(--sf2)}
tr.row-hidden{display:none}
.no-results-row td{padding:2.5rem 1rem;text-align:center;color:var(--tx3);font-size:.83rem}
tr[data-status="WARN"] td:first-child{border-left:3px solid var(--yellow);padding-left:calc(1rem - 3px)}
tr[data-status="EXPIRED"] td:first-child,tr[data-status="ERROR"] td:first-child{border-left:3px solid var(--red);padding-left:calc(1rem - 3px)}
tr[data-policy="PROHIBITED"] td:first-child{border-left:3px solid var(--red);padding-left:calc(1rem - 3px)}
tr[data-policy="REQUIRES_LICENSE"] td:first-child{border-left:3px solid var(--yellow);padding-left:calc(1rem - 3px)}
.badge{display:inline-flex;align-items:center;gap:.22rem;padding:.18rem .52rem;border-radius:20px;font-size:.65rem;font-weight:700;letter-spacing:.04em;white-space:nowrap}
.badge::before{content:'';width:5px;height:5px;border-radius:50%;flex-shrink:0}
.badge.ok{background:rgba(34,197,94,.12);color:var(--green);border:1px solid rgba(34,197,94,.25)}.badge.ok::before{background:var(--green)}
.badge.warn{background:rgba(245,158,11,.12);color:var(--yellow);border:1px solid rgba(245,158,11,.25)}.badge.warn::before{background:var(--yellow)}
.badge.expired{background:rgba(239,68,68,.12);color:var(--red);border:1px solid rgba(239,68,68,.25)}.badge.expired::before{background:var(--red)}
.mod-pill{display:inline-block;padding:.1rem .45rem;border-radius:4px;font-size:.63rem;font-weight:600;letter-spacing:.04em;background:var(--sf3);color:var(--tx3)}
.sw-name{font-weight:500;color:var(--tx)}
.sw-meta{font-size:.73rem;color:var(--tx3);margin-top:.08rem}
.suggestion{color:var(--blue);font-size:.73rem;display:flex;align-items:flex-start;gap:.3rem;margin-top:.35rem}
.reflink{color:var(--blue);text-decoration:none;font-size:.73rem}
.reflink:hover{text-decoration:underline}
.sev-pill{display:inline-block;padding:.05rem .35rem;border-radius:3px;font-size:.58rem;font-weight:700;letter-spacing:.04em;margin-left:.4rem;vertical-align:middle}
.sev-pill.critical{background:rgba(239,68,68,.25);color:#fca5a5}
.sev-pill.high{background:rgba(239,68,68,.15);color:var(--red)}
.sev-pill.medium{background:rgba(245,158,11,.15);color:var(--yellow)}
.sev-pill.low{background:rgba(34,197,94,.08);color:#4ade80}
.cal-days{display:inline-block;font-size:.78rem;font-weight:600}
.cal-days.urgent{color:var(--red)}.cal-days.warn{color:var(--yellow)}.cal-days.ok{color:var(--green)}
footer{padding:.6rem 0;text-align:center;color:var(--tx3);font-size:.7rem;border-top:1px solid var(--bd);flex-shrink:0}
@media(max-width:768px){.sidebar{display:none}.main{padding:1rem}.hdr{padding:0 1rem}.hdr-meta{display:none}.stat-grid{grid-template-columns:repeat(3,1fr)}}
@media print{body,layout{height:auto;overflow:visible}.tab-pane{display:block!important;height:auto!important;overflow:visible!important;margin-bottom:2rem}.tab-pane:not(.active){display:none!important}.table-wrap{overflow:visible;height:auto;border:none}.sidebar,.toolbar,.hdr .btn-lang{display:none!important}.hdr{position:static}}
</style>
</head>
<body>
<header class="hdr">
  <div class="hdr-brand">
    <span style="font-size:1.15rem">&#x1F510;</span>
    <h1>License<span>Guard</span></h1>$brandSpan
  </div>
  <span class="hdr-meta"><b>$hostname</b> &nbsp;&middot;&nbsp; $ts &nbsp;&middot;&nbsp; <span data-i18n="warnThreshold">Uyari esigi</span>: <b>${warnDays} <span data-i18n="days">gun</span></b></span>
  <button class="btn-lang" id="langBtn" onclick="toggleLang()">EN</button>
</header>
<div class="layout">
<nav class="sidebar">
  <div class="health-box">
    <div class="health-lbl" data-i18n="overallHealth">Genel Saglik</div>
    <div class="donut-wrap">
      <svg viewBox="0 0 76 76">
        <circle cx="38" cy="38" r="28" fill="none" stroke="#1e293b" stroke-width="7"/>
        <circle id="donut-ring" cx="38" cy="38" r="28" fill="none" stroke="#3b82f6" stroke-width="7" stroke-linecap="round" stroke-dasharray="0 175.9" transform="rotate(-90 38 38)" style="transition:stroke-dasharray .9s ease,stroke .4s ease"/>
      </svg>
      <div class="donut-inner"><span class="donut-pct" id="health-pct" style="color:#3b82f6">-</span><span class="donut-sub">skor</span></div>
    </div>
  </div>
  <div class="nav-sec" data-i18n="sections">Bolumler</div>
  <div class="nav-item active" onclick="switchTab('license',this)" id="nav-license"><span class="nav-icon">&#x1F4CA;</span><span data-i18n="navLicense">Lisans Durumu</span><span class="nav-badge" id="nb1"></span></div>
  <div class="nav-item" onclick="switchTab('policy',this)" id="nav-policy"><span class="nav-icon">&#x1F6E1;&#xFE0F;</span><span data-i18n="navPolicy">Uyumluluk</span><span class="nav-badge" id="nb2"></span></div>
  <div class="nav-item" onclick="switchTab('calendar',this)" id="nav-calendar"><span class="nav-icon">&#x1F4C5;</span><span data-i18n="navCalendar">Takvim</span><span class="nav-badge" id="nb-cal"></span></div>
  <div class="nav-divider"></div>
  <div class="nav-sec" data-i18n="modules">Moduller</div>
  <div class="nav-item" onclick="filterMod(null,this)"><span class="nav-icon">&#x25A6;</span><span data-i18n="allModules">Tumu</span></div>
  <div class="nav-item" onclick="filterMod('WindowsActivation',this)"><span class="nav-icon">&#x1F5A5;&#xFE0F;</span><span>Windows</span></div>
  <div class="nav-item" onclick="filterMod('OfficeLicense',this)"><span class="nav-icon">&#x1F4C4;</span><span data-i18n="navOffice">Office</span></div>
  <div class="nav-item" onclick="filterMod('Software',this)"><span class="nav-icon">&#x1F4E6;</span><span data-i18n="navSoftware">Yazilimlar</span></div>
  <div class="nav-item" onclick="filterMod('EOL',this)"><span class="nav-icon">&#x23F1;</span><span data-i18n="eolSection">EOL</span></div>
  <div class="nav-item" onclick="filterMod('FlexLM',this)"><span class="nav-icon">&#x1F511;</span><span>FlexLM</span></div>
  <div class="nav-item" onclick="filterMod('SaaS',this)"><span class="nav-icon">&#x2601;&#xFE0F;</span><span>SaaS / API</span></div>
  <div class="nav-item" onclick="filterMod('BrowserExt',this)"><span class="nav-icon">&#x1F9E9;</span><span data-i18n="navBrowserExt">Tarayici</span></div>
  <div class="nav-item" onclick="filterMod('VSCodeExt',this)"><span class="nav-icon">&#x1F4BB;</span><span data-i18n="navVsCode">VS Code</span></div>
  <div class="nav-item" onclick="filterMod('NPM',this)"><span class="nav-icon">&#x1F4E6;</span><span>NPM</span></div>
  <div class="nav-item" onclick="filterMod('NuGet',this)"><span class="nav-icon">&#x1F9F1;</span><span>NuGet</span></div>
  <div class="nav-item" onclick="filterMod('BinaryAudit',this)"><span class="nav-icon">&#x1F50D;</span><span>Binary</span></div>
  <div class="nav-item" onclick="filterMod('Startup',this)"><span class="nav-icon">&#x1F680;</span><span data-i18n="navStartup">Baslangic</span></div>
  <div class="nav-item" onclick="filterMod('Process',this)"><span class="nav-icon">&#x26A1;</span><span data-i18n="navProcess">Processler</span></div>
  <div class="nav-item" onclick="filterMod('Signature',this)"><span class="nav-icon">&#x1F4DC;</span><span data-i18n="navSignature">Imza</span></div>
</nav>
<main class="main">
  <div class="tab-pane active" id="tab-license">
    <div class="sec-head"><span class="sec-icon">&#x1F4CA;</span><h2 data-i18n="licenseSection">Lisans Durumu</h2></div>
    <div class="stat-grid">
      <div class="sc ok"><div class="sc-ico">&#x2705;</div><div class="sc-num" id="c1ok-n">-</div><div class="sc-lbl" data-i18n="valid">Gecerli</div><div class="sc-bar"><div class="sc-bar-fill" id="c1ok-b"></div></div><div class="sc-pct" id="c1ok-p"></div></div>
      <div class="sc warn"><div class="sc-ico">&#x26A0;&#xFE0F;</div><div class="sc-num" id="c1wn-n">-</div><div class="sc-lbl" data-i18n="warning">Uyari</div><div class="sc-bar"><div class="sc-bar-fill" id="c1wn-b"></div></div><div class="sc-pct" id="c1wn-p"></div></div>
      <div class="sc exp"><div class="sc-ico">&#x1F6A8;</div><div class="sc-num" id="c1er-n">-</div><div class="sc-lbl" data-i18n="errorExp">Hata/Dolmus</div><div class="sc-bar"><div class="sc-bar-fill" id="c1er-b"></div></div><div class="sc-pct" id="c1er-p"></div></div>
    </div>
$deltaBoxHtml
    <div class="toolbar">
      <div class="search-wrap"><svg class="search-ico" viewBox="0 0 16 16"><path d="M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398h-.001l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85a1.007 1.007 0 0 0-.115-.099zM12 6.5a5.5 5.5 0 1 1-11 0 5.5 5.5 0 0 1 11 0z"/></svg><input class="search-input" id="s1" data-table="t1" oninput="doFilter(this)" placeholder="Yazilim ara..."></div>
      <label class="filter-chip"><input type="checkbox" id="f1" data-table="t1" onchange="doFilterCb(this)"> <span data-i18n="issuesOnly">Sadece sorunlar</span></label>
      <button class="btn-exp" onclick="exportTableCsv('t1','lg-license.csv')" data-i18n="exportCsv">CSV Indir</button>
      <button class="btn-exp" onclick="exportTableJson('t1','lg-license.json')" data-i18n="exportJson">JSON Indir</button>
      <button class="btn-exp" onclick="window.print()" data-i18n="printPdf">PDF Yazdir</button>
      <span class="rc" id="rc1"></span>
    </div>
    <div class="table-wrap"><table id="t1"><thead><tr><th class="sortable" onclick="sortTable('t1',0)">Modul</th><th class="sortable" onclick="sortTable('t1',1)">Ad</th><th>Detay</th><th class="sortable" onclick="sortTable('t1',3)">Durum</th></tr></thead><tbody>
$tableRows
    </tbody></table></div>
  </div>
  <div class="tab-pane" id="tab-policy">
    <div class="sec-head"><span class="sec-icon">&#x1F6E1;&#xFE0F;</span><h2 data-i18n="policySection">Kurumsal Lisans Uyumluluk</h2></div>
    <div class="stat-grid">
      <div class="sc exp"><div class="sc-ico">&#x1F6AB;</div><div class="sc-num" id="c2bn-n">-</div><div class="sc-lbl" data-i18n="banned">Yasak</div><div class="sc-bar"><div class="sc-bar-fill" id="c2bn-b"></div></div><div class="sc-pct" id="c2bn-p"></div></div>
      <div class="sc warn"><div class="sc-ico">&#x1F4CB;</div><div class="sc-num" id="c2lc-n">-</div><div class="sc-lbl" data-i18n="needsLic">Lisans Gerekli</div><div class="sc-bar"><div class="sc-bar-fill" id="c2lc-b"></div></div><div class="sc-pct" id="c2lc-p"></div></div>
      <div class="sc ok"><div class="sc-ico">&#x2705;</div><div class="sc-num" id="c2ok-n">-</div><div class="sc-lbl" data-i18n="compliant">Uyumlu</div><div class="sc-bar"><div class="sc-bar-fill" id="c2ok-b"></div></div><div class="sc-pct" id="c2ok-p"></div></div>
    </div>
    <div class="toolbar">
      <div class="search-wrap"><svg class="search-ico" viewBox="0 0 16 16"><path d="M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398h-.001l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85a1.007 1.007 0 0 0-.115-.099zM12 6.5a5.5 5.5 0 1 1-11 0 5.5 5.5 0 0 1 11 0z"/></svg><input class="search-input" id="s2" data-table="t2" oninput="doFilter(this)" placeholder="Yazilim ara..."></div>
      <label class="filter-chip"><input type="checkbox" id="f2" data-table="t2" onchange="doFilterCb(this)"> <span data-i18n="issuesOnly">Sadece sorunlar</span></label>
      <button class="btn-exp" onclick="exportTableCsv('t2','lg-policy.csv')" data-i18n="exportCsv">CSV Indir</button>
      <button class="btn-exp" onclick="exportTableJson('t2','lg-policy.json')" data-i18n="exportJson">JSON Indir</button>
      <span class="rc" id="rc2"></span>
    </div>
    <div class="table-wrap"><table id="t2"><thead><tr><th class="sortable" onclick="sortTable('t2',0)">Kategori</th><th class="sortable" onclick="sortTable('t2',1)">Yazilim</th><th>Aciklama / Oneri</th><th class="sortable" onclick="sortTable('t2',3)">Durum</th></tr></thead><tbody>
$policyRows
    </tbody></table></div>
  </div>
  <div class="tab-pane" id="tab-calendar">
    <div class="sec-head"><span class="sec-icon">&#x1F4C5;</span><h2 data-i18n="calSection">Lisans Takvimi</h2></div>
    <div class="table-wrap"><table id="t-cal"><thead><tr><th>Ad</th><th>Modul</th><th>Tarih</th><th data-i18n="remaining">Kalan</th><th>Durum</th></tr></thead><tbody id="cal-tbody"><tr class="no-results-row"><td colspan="5">&#x2014;</td></tr></tbody></table></div>
  </div>
  <footer>LicenseGuard v$ver &middot; <a href="https://github.com/mustafasercansak/LicenseGuard" target="_blank" style="color:inherit;text-decoration:none">Mustafa Sercan Sak</a></footer>
</main>
</div>
<script>
var i18n={
  tr:{pageTitle:'LicenseGuard Raporu',licenseSection:'Lisans Durumu',policySection:'Kurumsal Lisans Uyumluluk',searchPh:'Yazilim ara...',issuesOnly:'Sadece sorunlar',valid:'Gecerli',warning:'Uyari',errorExp:'Hata / Dolmus',banned:'Yasak',needsLic:'Lisans Gerekli',compliant:'Uyumlu',warnThreshold:'Uyari esigi',days:'gun',navLicense:'Lisans Durumu',navPolicy:'Uyumluluk',navSoftware:'Yazilimlar',navCalendar:'Takvim',navBrowserExt:'Tarayici Eklentileri',navVsCode:'VS Code',navStartup:'Baslangic',navProcess:'Aktif Processler',navSignature:'Imza',navOffice:'Office',overallHealth:'Genel Saglik',sections:'Bolumler',modules:'Moduller',allModules:'Tumu',rcOf:'{v} / {t} kayit',calSection:'Lisans Takvimi',eolSection:'EOL / Destek Sonu',noExpiry:'Yaklasan bitis tarihi bulunamadi',exportCsv:'CSV Indir',exportJson:'JSON Indir',printPdf:'PDF Yazdir',remaining:'Kalan'},
  en:{pageTitle:'LicenseGuard Report',licenseSection:'License Status',policySection:'Corporate License Compliance',searchPh:'Search software...',issuesOnly:'Issues only',valid:'Valid',warning:'Warning',errorExp:'Error / Expired',banned:'Banned',needsLic:'Needs License',compliant:'Compliant',warnThreshold:'Warning threshold',days:'days',navLicense:'License Status',navPolicy:'Compliance',navSoftware:'Software',navCalendar:'Calendar',navBrowserExt:'Browser Extensions',navVsCode:'VS Code',navStartup:'Startup',navProcess:'Running Processes',navSignature:'Signature',navOffice:'Office',overallHealth:'Overall Health',sections:'Sections',modules:'Modules',allModules:'All',rcOf:'{v} / {t} records',calSection:'License Calendar',eolSection:'EOL / End of Support',noExpiry:'No upcoming expiry dates found',exportCsv:'Export CSV',exportJson:'Export JSON',printPdf:'Print PDF',remaining:'Remaining'}
};
var currentLang='$initLang',activeMod=null,calendarData=$calJson;
function applyLang(lang){currentLang=lang;document.getElementById('htmlRoot').lang=lang;document.getElementById('langBtn').textContent=lang==='tr'?'EN':'TR';document.querySelectorAll('[data-i18n]').forEach(function(el){var k=el.getAttribute('data-i18n');if(i18n[lang][k]!==undefined)el.innerHTML=i18n[lang][k];});document.querySelectorAll('[data-val-tr]').forEach(function(el){el.textContent=lang==='tr'?el.dataset.valTr:el.dataset.valEn;});document.title=i18n[lang].pageTitle;refreshRC();if(document.getElementById('tab-calendar').classList.contains('active')){buildCalendar();}try{localStorage.setItem('lg_lang',lang);}catch(e){}}
function toggleLang(){applyLang(currentLang==='tr'?'en':'tr');}
function switchTab(id,el){document.querySelectorAll('.tab-pane').forEach(function(p){p.classList.remove('active');});document.querySelectorAll('.nav-item').forEach(function(n){n.classList.remove('active');});document.getElementById('tab-'+id).classList.add('active');el.classList.add('active');if(id==='calendar'){buildCalendar();}}
function filterMod(mod,el){activeMod=mod;document.querySelectorAll('.nav-item').forEach(function(n){n.classList.remove('active');});el.classList.add('active');if(mod){document.querySelectorAll('.tab-pane').forEach(function(p){p.classList.remove('active');});document.getElementById('tab-license').classList.add('active');document.getElementById('nav-license').classList.add('active');}applyFilter('t1',document.getElementById('s1').value.toLowerCase(),document.getElementById('f1').checked);}
function doFilter(inp){var n=inp.dataset.table.replace('t','');applyFilter(inp.dataset.table,inp.value.toLowerCase(),document.getElementById('f'+n).checked);}
function doFilterCb(cb){var n=cb.dataset.table.replace('t','');applyFilter(cb.dataset.table,document.getElementById('s'+n).value.toLowerCase(),cb.checked);}
function applyFilter(tid,q,issOnly){var rows=document.querySelectorAll('#'+tid+' tbody tr:not(.no-results-row)');var vis=0;rows.forEach(function(r){var badge=r.querySelector('.badge');var isIssue=badge&&(badge.classList.contains('expired')||badge.classList.contains('warn'));var mp=r.querySelector('.mod-pill');var modOk=!activeMod||!mp||(mp.dataset.mod===activeMod);var show=(!q||r.textContent.toLowerCase().indexOf(q)!==-1)&&(!issOnly||isIssue)&&modOk;r.classList.toggle('row-hidden',!show);if(show)vis++;});var nr=document.querySelector('#'+tid+' .no-results-row');if(!nr){nr=document.createElement('tr');nr.className='no-results-row';nr.innerHTML='<td colspan="99">&#x2205; No results</td>';document.querySelector('#'+tid+' tbody').appendChild(nr);}nr.classList.toggle('row-hidden',vis>0);setRC(tid,vis,rows.length);}
function setRC(tid,vis,total){var n=tid.replace('t','');var el=document.getElementById('rc'+n);if(!el)return;var tmpl=(i18n[currentLang]||{}).rcOf||'{v} / {t}';el.textContent=tmpl.replace('{v}',vis).replace('{t}',total);}
function refreshRC(){['t1','t2'].forEach(function(tid){var r=document.querySelectorAll('#'+tid+' tbody tr:not(.no-results-row):not(.row-hidden)').length;var t=document.querySelectorAll('#'+tid+' tbody tr:not(.no-results-row)').length;setRC(tid,r,t);});}
var sortState={};
function sortTable(tid,ci){var key=tid+':'+ci;var asc=!sortState[key];sortState[key]=asc;var t=document.getElementById(tid);t.querySelectorAll('th.sortable').forEach(function(th){th.classList.remove('sort-asc','sort-desc');});t.querySelectorAll('th')[ci].classList.add(asc?'sort-asc':'sort-desc');var tb=t.querySelector('tbody');var rows=Array.prototype.slice.call(tb.querySelectorAll('tr:not(.no-results-row)'));rows.sort(function(a,b){var av=(a.cells[ci]?a.cells[ci].textContent:'').trim();var bv=(b.cells[ci]?b.cells[ci].textContent:'').trim();return asc?av.localeCompare(bv,undefined,{numeric:true,sensitivity:'base'}):bv.localeCompare(av,undefined,{numeric:true,sensitivity:'base'});});var nr=tb.querySelector('.no-results-row');rows.forEach(function(r){tb.insertBefore(r,nr||null);});}
function setCard(pfx,val,total){var pct=Math.round(val/total*100);var n=document.getElementById(pfx+'-n');var p=document.getElementById(pfx+'-p');var b=document.getElementById(pfx+'-b');if(n)n.textContent=val;if(p)p.textContent=pct+'%';if(b)setTimeout(function(){b.style.width=pct+'%';},120);}
function updateDonut(pct){var circ=2*Math.PI*28;var dash=circ*pct/100;var el=document.getElementById('donut-ring');var txt=document.getElementById('health-pct');if(!el||!txt)return;var color=pct>=90?'#22c55e':pct>=70?'#f59e0b':'#ef4444';el.style.stroke=color;el.setAttribute('stroke-dasharray',dash+' '+circ);txt.style.color=color;txt.textContent=pct+'%';}
function updateAll(){var t1=document.querySelectorAll('#t1 tbody tr:not(.no-results-row)');var ok1=0,wn1=0,er1=0;t1.forEach(function(r){var s=r.getAttribute('data-status');if(s==='OK')ok1++;else if(s==='WARN')wn1++;else er1++;});var lt=t1.length||1;setCard('c1ok',ok1,lt);setCard('c1wn',wn1,lt);setCard('c1er',er1,lt);var t2=document.querySelectorAll('#t2 tbody tr:not(.no-results-row)');var bn=0,lc=0,ok2=0;t2.forEach(function(r){var s=r.getAttribute('data-policy');if(s==='PROHIBITED')bn++;else if(s==='REQUIRES_LICENSE')lc++;else ok2++;});var pt=t2.length||1;setCard('c2bn',bn,pt);setCard('c2lc',lc,pt);setCard('c2ok',ok2,pt);var healthTotal=lt+pt;var healthBad=er1+bn;var healthWarn=wn1+lc;var healthOk=Math.max(0,healthTotal-healthBad-healthWarn);updateDonut(Math.round(healthOk/(healthTotal||1)*100));var i1=wn1+er1,i2=bn+lc;var nb1=document.getElementById('nb1'),nb2=document.getElementById('nb2');if(nb1){nb1.textContent=i1||'';nb1.className='nav-badge'+(er1>0?' red':wn1>0?' yellow':'');}if(nb2){nb2.textContent=i2||'';nb2.className='nav-badge'+(bn>0?' red':lc>0?' yellow':'');}if(calendarData&&calendarData.length){var urgent=calendarData.filter(function(d){return d.days<=30;}).length;var nbCal=document.getElementById('nb-cal');if(nbCal){nbCal.textContent=urgent||'';nbCal.className='nav-badge'+(urgent>0?' yellow':'');}}refreshRC();}
function buildCalendar(){var tbody=document.getElementById('cal-tbody');if(!calendarData||calendarData.length===0){tbody.innerHTML='<tr class="no-results-row"><td colspan="5">'+((i18n[currentLang]||{}).noExpiry||'No data')+'</td></tr>';return;}var sorted=calendarData.slice().sort(function(a,b){return a.date.localeCompare(b.date);});var html='';sorted.forEach(function(item){var d=item.days;var cls=d<0?'expired':d<=30?'warn':'ok';var dclsCal=d<0?'urgent':d<=30?'warn':'ok';var daysTr=d<0?(Math.abs(d)+' gun once'):(d+' gun kaldi');var daysEn=d<0?(Math.abs(d)+' days ago'):(d+' days left');var badgeTr=cls==='ok'?'UYUMLU':cls==='warn'?'UYARI':'SURESI DOLDU';var badgeEn=cls==='ok'?'OK':cls==='warn'?'WARNING':'EXPIRED';html+='<tr data-status="'+(d<0?'EXPIRED':d<=30?'WARN':'OK')+'"><td>'+item.name+'</td><td><span class="mod-pill">'+item.module+'</span></td><td>'+item.date+'</td><td><span class="cal-days '+dclsCal+'" data-val-tr="'+daysTr+'" data-val-en="'+daysEn+'">'+(currentLang==='tr'?daysTr:daysEn)+'</span></td><td><span class="badge '+cls+'" data-val-tr="'+badgeTr+'" data-val-en="'+badgeEn+'">'+(currentLang==='tr'?badgeTr:badgeEn)+'</span></td></tr>';});tbody.innerHTML=html||'<tr class="no-results-row"><td colspan="5">&#x2014;</td></tr>';}
function exportTableCsv(tid,filename){var t=document.getElementById(tid);var hdr=[];t.querySelectorAll('thead th').forEach(function(th){hdr.push('"'+th.textContent.trim().replace(/"/g,'""')+'"');});var rows=[hdr.join(',')];t.querySelectorAll('tbody tr:not(.no-results-row):not(.row-hidden)').forEach(function(tr){var cells=[];tr.querySelectorAll('td').forEach(function(td){cells.push('"'+td.textContent.trim().replace(/"/g,'""')+'"');});rows.push(cells.join(','));});var blob=new Blob(['\uFEFF'+rows.join('\n')],{type:'text/csv;charset=utf-8;'});var a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=filename;a.click();}
function exportTableJson(tid,filename){var t=document.getElementById(tid);var hdr=[];t.querySelectorAll('thead th').forEach(function(th){hdr.push(th.textContent.trim());});var rows=[];t.querySelectorAll('tbody tr:not(.no-results-row):not(.row-hidden)').forEach(function(tr){var obj={};tr.querySelectorAll('td').forEach(function(td,i){obj[hdr[i]||('col'+i)]=td.textContent.trim();});rows.push(obj);});var blob=new Blob([JSON.stringify(rows,null,2)],{type:'application/json'});var a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=filename;a.click();}
window.addEventListener('load',function(){updateAll();try{var saved=localStorage.getItem('lg_lang');if(saved&&saved!==currentLang)applyLang(saved);}catch(e){}});
</script>
</body>
</html>
"@

    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "`n  $($L['reportSaved']) $OutputPath" -ForegroundColor Cyan
}
