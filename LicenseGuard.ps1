param(
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$ConfigPath = '.\lg-config.json',
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$OutputPath = '.\license-report.html',
    [Parameter(Mandatory=$false)][switch]$ConsoleOnly,
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$PolicyPath = '.\lg-policy.json',
    [Parameter(Mandatory=$false)][ValidateSet("tr","en")][string]$Lang = "tr"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

# ─────────────────────────────────────────────
#  DİL DESTEĞİ  (emoji yok — PS 5.1 encoding güvenliği)
# ─────────────────────────────────────────────
$L = @{
    tr = @{
        reportTitle     = "LicenseGuard"
        valid           = "Gecerli"
        warn            = "Uyari"
        expired         = "Hata / Dolmus"
        module          = "Modul"
        name            = "Ad"
        detail          = "Detay"
        status          = "Durum"
        noRule          = "Kural Yok/Uyumlu"
        allowed         = "UYUMLU"
        prohibited      = "YASAK"
        requiresLicense = "LISANS GEREKLI"
        policySection   = "Kurumsal Lisans Uyumluluk"
        licenseSection  = "Lisans Durumu"
        noMatch         = "Kural Yok/Uyumlu"
        reportSaved     = "HTML rapor kaydedildi:"
        criticalCount   = "kritik lisans sorunu."
        prohibitedFound = "YASAK yazilim tespit edildi -- acil aksiyon gerekli!"
        needsLicCount   = "yazilim lisans dogrulamasi bekliyor."
        allClear        = "Tum kontroller tamamlandi, uyumluluk sorunu yok."
        starting        = "LicenseGuard baslatiliyor..."
    }
    en = @{
        reportTitle     = "LicenseGuard"
        valid           = "Valid"
        warn            = "Warning"
        expired         = "Error / Expired"
        module          = "Module"
        name            = "Name"
        detail          = "Detail"
        status          = "Status"
        noRule          = "No Policy/Compliant"
        allowed         = "COMPLIANT"
        prohibited      = "PROHIBITED"
        requiresLicense = "REQUIRES LICENSE"
        policySection   = "Corporate License Compliance"
        licenseSection  = "License Status"
        noMatch         = "No Policy/Compliant"
        reportSaved     = "HTML report saved:"
        criticalCount   = "critical license issues."
        prohibitedFound = "PROHIBITED software detected -- immediate action required!"
        needsLicCount   = "software awaiting license verification."
        allClear        = "All checks passed, no compliance issues."
        starting        = "LicenseGuard starting..."
    }
}[$Lang]

# ─────────────────────────────────────────────
#  KONFIGURASYON
# ─────────────────────────────────────────────
$defaultConfig = @{
    FlexLM = @(
        # @{ Name="MATLAB"; Server="27000@license-server01" }
    )
    SaaS = @(
        # @{ Name="GitHub"; Endpoint="https://api.github.com/rate_limit"; Header="Authorization"; Key="Bearer ghp_XXXX"; ExpectStatus=200 }
    )
    WarnDaysBeforeExpiry = 30
}

$config = $defaultConfig
if (Test-Path $ConfigPath) {
    try {
        $loaded = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        if ($loaded.FlexLM)               { $config.FlexLM               = $loaded.FlexLM               }
        if ($loaded.SaaS)                 { $config.SaaS                 = $loaded.SaaS                 }
        if ($loaded.WarnDaysBeforeExpiry) { $config.WarnDaysBeforeExpiry = $loaded.WarnDaysBeforeExpiry }
        Write-Host "  Konfigurasyon yuklendi: $ConfigPath" -ForegroundColor DarkGray
    } catch {
        Write-Host "  [WARN] Konfigurasyon okunamadi, varsayilanlar kullaniliyor. Hata: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

$warnDays = $config.WarnDaysBeforeExpiry

# ─────────────────────────────────────────────
#  YARDIMCI FONKSIYONLAR
# ─────────────────────────────────────────────
function Get-InstalledSoftwareCache {
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $today = Get-Date
    $rows  = @()
    foreach ($path in $regPaths) {
        Get-ItemProperty $path 2>$null | Where-Object { $_.DisplayName } | ForEach-Object {
            $name    = $_.DisplayName
            $version = if ($_.DisplayVersion) { $_.DisplayVersion } else { "-" }
            $pub     = if ($_.Publisher)      { $_.Publisher }      else { "Bilinmiyor" }
            $installDateRaw = $_.InstallDate
            $installDate    = $null
            if ($installDateRaw -match '^\d{8}$') {
                try { $installDate = [datetime]::ParseExact($installDateRaw, "yyyyMMdd", $null) } catch {}
            }
            $expireDate = $null
            foreach ($field in @("ExpirationDate","TrialExpireDate","ExpireDate","LicenseExpiry")) {
                $val = $_.$field
                if ($val) {
                    try { $expireDate = [datetime]$val; break } catch {}
                    if ($val -match '^\d{8}$') {
                        try { $expireDate = [datetime]::ParseExact($val, "yyyyMMdd", $null); break } catch {}
                    }
                }
            }
            $status  = "OK"
            $expInfo = if ($expireDate) {
                $daysLeft = ($expireDate - $today).Days
                if    ($daysLeft -lt 0)          { $status = "EXPIRED"; "SURESI DOLDU ($([math]::Abs($daysLeft)) gun once)" }
                elseif ($daysLeft -le $warnDays) { $status = "WARN";   "Bitiyor: $($expireDate.ToString('yyyy-MM-dd')) ($daysLeft gun)" }
                else                             { "Gecerli: $($expireDate.ToString('yyyy-MM-dd'))" }
            } else { "" }
            $rows += [PSCustomObject]@{
                Name        = $name
                Version     = $version
                Publisher   = $pub
                InstallDate = if ($installDate) { $installDate.ToString("yyyy-MM-dd") } else { "-" }
                ExpireInfo  = $expInfo
                Status      = $status
            }
        }
    }
    return $rows | Sort-Object Name -Unique
}

function Write-Header {
    param([string]$Text)
    Write-Host "`n+------------------------------------------+" -ForegroundColor Cyan
    Write-Host   "|  $($Text.PadRight(40))|" -ForegroundColor Cyan
    Write-Host   "+------------------------------------------+" -ForegroundColor Cyan
}

function Write-Status {
    param([string]$Label, [string]$Value, [string]$Status)
    $color = switch ($Status) {
        "OK"      { "Green"  }
        "WARN"    { "Yellow" }
        "EXPIRED" { "Red"    }
        "ERROR"   { "Red"    }
        default   { "Gray"   }
    }
    $icon = switch ($Status) {
        "OK"      { "[OK]" }
        "WARN"    { "[!!]" }
        "EXPIRED" { "[XX]" }
        "ERROR"   { "[XX]" }
        default   { "[--]" }
    }
    Write-Host ("  {0} {1,-38} {2}" -f $icon, $Label, $Value) -ForegroundColor $color
}

# ─────────────────────────────────────────────
#  MODUL 1: WINDOWS AKTIVASYON
# ─────────────────────────────────────────────
function Get-WindowsActivation {
    Write-Header "Windows Aktivasyon"
    $products = $null
    try {
        $products = Get-WmiObject -Query "SELECT Name, LicenseStatus, Description, GracePeriodRemaining FROM SoftwareLicensingProduct WHERE PartialProductKey IS NOT NULL AND ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f'"
    } catch {
        Write-Status "Windows Lisans" "Okunamadi" "ERROR"
        return @{ Module="WindowsActivation"; Name="Windows Lisans"; Status="ERROR"; Detail="WMI sorgusu basarisiz" }
    }
    if (-not $products) {
        Write-Status "Windows Lisans" "Okunamadi" "ERROR"
        return @{ Module="WindowsActivation"; Name="Windows Lisans"; Status="ERROR"; Detail="WMI sorgusu basarisiz" }
    }
    $row = $products | Sort-Object LicenseStatus | Select-Object -First 1
    $statusMap = @{
        0 = @("Unlicensed",        "EXPIRED")
        1 = @("Licensed",          "OK")
        2 = @("OOBGrace",          "WARN")
        3 = @("OOTGrace",          "WARN")
        4 = @("NonGenuineGrace",   "WARN")
        5 = @("Notification",      "WARN")
        6 = @("ExtendedGrace",     "WARN")
    }
    $ls     = [int]$row.LicenseStatus
    $mapped = if ($statusMap.ContainsKey($ls)) { $statusMap[$ls] } else { @("Bilinmiyor", "WARN") }
    $label  = $mapped[0]
    $status = $mapped[1]
    $detail = if ($row.GracePeriodRemaining -gt 0) {
        "$label -- Kalan sure: $([math]::Round($row.GracePeriodRemaining/1440,1)) gun"
    } else { $label }
    Write-Status "Windows Aktivasyon" $detail $status
    return @{ Module="WindowsActivation"; Name="Windows Aktivasyon"; Status=$status; Detail=$detail }
}

# ─────────────────────────────────────────────
#  MODUL 2: KURULU YAZILIM ENVANTERI
# ─────────────────────────────────────────────
function Get-InstalledSoftwareAudit {
    Write-Header "Kurulu Yazilim Envanteri"
    $rows = Get-InstalledSoftwareCache
    Write-Host ("  {0} yazilim bulundu." -f $rows.Count) -ForegroundColor DarkGray
    $expired = $rows | Where-Object { $_.Status -eq "EXPIRED" }
    $warning = $rows | Where-Object { $_.Status -eq "WARN"    }
    if ($expired) {
        Write-Host "`n  Suresi Dolmus:" -ForegroundColor Red
        $expired | ForEach-Object { Write-Status $_.Name $_.ExpireInfo "EXPIRED" }
    }
    if ($warning) {
        Write-Host "`n  Uyari (${warnDays} gun icinde bitiyor):" -ForegroundColor Yellow
        $warning | ForEach-Object { Write-Status $_.Name $_.ExpireInfo "WARN" }
    }
    if (-not $expired -and -not $warning) {
        Write-Status "Tum yazilimlar" "Expire kaydi yok / sorun yok" "OK"
    }
    return $rows | ForEach-Object {
        @{ Module="Software"; Name=$_.Name; Version=$_.Version; Publisher=$_.Publisher;
           Status=$_.Status; Detail=$_.ExpireInfo; InstallDate=$_.InstallDate }
    }
}

# ─────────────────────────────────────────────
#  MODUL 3: FLEXLM LISANS SUNUCUSU
# ─────────────────────────────────────────────
function Get-FlexLMStatus {
    Write-Header "FlexLM Lisans Sunucusu"
    if ($config.FlexLM.Count -eq 0) {
        Write-Host "  Konfigurasyonda FlexLM girisi yok. lg-config.json dosyasina ekleyin." -ForegroundColor DarkGray
        return @()
    }
    $lmutil = Get-Command "lmutil.exe" -ErrorAction SilentlyContinue
    if (-not $lmutil) {
        $candidates = @(
            "C:\Program Files\FLEXlm\lmutil.exe",
            "C:\Program Files\Flexera Software\FlexNet Publisher\lmutil.exe",
            "C:\Program Files (x86)\Common Files\Macrovision Shared\FLEXnet Publisher\FNPLicensingService.exe"
        )
        foreach ($c in $candidates) { if (Test-Path $c) { $lmutil = $c; break } }
    }
    $rows = @()
    foreach ($entry in $config.FlexLM) {
        $name   = $entry.Name
        $server = $entry.Server
        if (-not $lmutil) {
            Write-Status $name "lmutil.exe bulunamadi" "ERROR"
            $rows += @{ Module="FlexLM"; Name=$name; Server=$server; Status="ERROR"; Detail="lmutil.exe bulunamadi" }
            continue
        }
        try {
            $output = & $lmutil lmstat -a -c $server 2>&1 | Out-String
            if ($output -match "license server UP") {
                $used = ([regex]::Matches($output, "in use")).Count
                Write-Status $name "Sunucu ACIK - $used feature(s) aktif" "OK"
                $rows += @{ Module="FlexLM"; Name=$name; Server=$server; Status="OK"; Detail="Sunucu UP - $used feature aktif" }
            } elseif ($output -match "Cannot connect|Connection refused|not respond") {
                Write-Status $name "Sunucuya ulasilamiyor: $server" "ERROR"
                $rows += @{ Module="FlexLM"; Name=$name; Server=$server; Status="ERROR"; Detail="Baglanti hatasi" }
            } else {
                Write-Status $name "Bilinmeyen durum" "WARN"
                $rows += @{ Module="FlexLM"; Name=$name; Server=$server; Status="WARN"; Detail="Beklenmedik cikti" }
            }
        } catch {
            Write-Status $name "lmutil calistirma hatasi" "ERROR"
            $rows += @{ Module="FlexLM"; Name=$name; Server=$server; Status="ERROR"; Detail=$_.Exception.Message }
        }
    }
    return $rows
}

# ─────────────────────────────────────────────
#  MODUL 4: SaaS / API KEY PING
# ─────────────────────────────────────────────
function Get-SaaSStatus {
    Write-Header "SaaS / API Key Durumu"
    if ($config.SaaS.Count -eq 0) {
        Write-Host "  Konfigurasyonda SaaS girisi yok. lg-config.json dosyasina ekleyin." -ForegroundColor DarkGray
        return @()
    }
    $rows = @()
    foreach ($svc in $config.SaaS) {
        $name     = $svc.Name
        $endpoint = $svc.Endpoint
        $header   = $svc.Header
        $key      = $svc.Key
        $expect   = if ($svc.ExpectStatus) { [int]$svc.ExpectStatus } else { 200 }
        try {
            $headers = @{ $header = $key }
            $resp = Invoke-WebRequest -Uri $endpoint -Headers $headers -Method GET -TimeoutSec 10 -UseBasicParsing
            if ($resp.StatusCode -eq $expect) {
                Write-Status $name "HTTP $($resp.StatusCode) -- Aktif" "OK"
                $rows += @{ Module="SaaS"; Name=$name; Endpoint=$endpoint; Status="OK"; Detail="HTTP $($resp.StatusCode)" }
            } else {
                Write-Status $name "HTTP $($resp.StatusCode) -- Beklenmedik" "WARN"
                $rows += @{ Module="SaaS"; Name=$name; Endpoint=$endpoint; Status="WARN"; Detail="HTTP $($resp.StatusCode)" }
            }
        } catch {
            $httpCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
            $detail = switch ($httpCode) {
                401     { "401 Unauthorized -- API key gecersiz/suresi dolmus" }
                403     { "403 Forbidden -- Yetki yetersiz" }
                0       { "Baglanti hatasi: $($_.Exception.Message)" }
                default { "HTTP $httpCode" }
            }
            $status = if ($httpCode -in @(401,403)) { "EXPIRED" } else { "ERROR" }
            Write-Status $name $detail $status
            $rows += @{ Module="SaaS"; Name=$name; Endpoint=$endpoint; Status=$status; Detail=$detail }
        }
    }
    return $rows
}

# ─────────────────────────────────────────────
#  MODUL 5: LISANS UYUMLULUK (POLICY CHECK)
# ─────────────────────────────────────────────
function Invoke-PolicyCheck {
    param([string]$PolicyPath = ".\lg-policy.json")
    Write-Header $L["policySection"]
    if (-not (Test-Path $PolicyPath)) {
        Write-Host "  [WARN] Policy dosyasi bulunamadi: $PolicyPath" -ForegroundColor Yellow
        return @()
    }
    try {
        $policy = Get-Content $PolicyPath -Raw | ConvertFrom-Json
    } catch {
        Write-Host "  [WARN] Policy dosyasi okunamadi. Hata: $($_.Exception.Message)" -ForegroundColor Yellow
        return @()
    }
    $swRows = Get-InstalledSoftwareCache | ForEach-Object {
        [PSCustomObject]@{ Name=$_.Name; Version=$_.Version; Publisher=$_.Publisher }
    }
    $findings = @()
    foreach ($sw in $swRows) {
        $matched = $false
        foreach ($rule in $policy.rules) {
            $match = $false
            switch ($rule.matchType) {
                "contains"   { if ($sw.Name -like "*$($rule.pattern)*") { $match = $true } }
                "startsWith" { if ($sw.Name -like "$($rule.pattern)*")  { $match = $true } }
                "exact"      { if ($sw.Name -eq $rule.pattern)          { $match = $true } }
                "regex"      { if ($sw.Name -match $rule.pattern)       { $match = $true } }
            }
            if ($match) {
                $statusMap     = @{ "PROHIBITED"="EXPIRED"; "REQUIRES_LICENSE"="WARN"; "ALLOWED"="OK" }
                $consoleStatus = $statusMap[$rule.status]
                $alt           = if ($null -ne $rule.alternative)  { $rule.alternative  } else { "" }
                $ref           = if ($null -ne $rule.referenceUrl) { $rule.referenceUrl } else { "" }
                $findings += @{
                    Module="PolicyCheck"; RuleId=$rule.id; Category=$rule.category
                    Name=$sw.Name; Version=$sw.Version; Publisher=$sw.Publisher
                    PolicyStatus=$rule.status; Status=$consoleStatus; Detail=$rule.reason
                    Alternative=$alt; Reference=$ref
                }
                $matched = $true
                break
            }
        }
        if (-not $matched) {
            $findings += @{
                Module="PolicyCheck"; RuleId="N/A"; Category="N/A"
                Name=$sw.Name; Version=$sw.Version; Publisher=$sw.Publisher
                PolicyStatus="ALLOWED"; Status="OK"; Detail=$L["noRule"]
                Alternative=""; Reference=""
            }
        }
    }
    $proh = @($findings | Where-Object { $_.PolicyStatus -eq "PROHIBITED"       })
    $lic  = @($findings | Where-Object { $_.PolicyStatus -eq "REQUIRES_LICENSE" })
    $ok   = @($findings | Where-Object { $_.PolicyStatus -eq "ALLOWED"          })
    foreach ($f in $findings) {
        $suffix = if ($f.RuleId -ne "N/A") { " [$($f.RuleId)]" } else { "" }
        Write-Status ($f.Name + $suffix) $f.Detail $f.Status
        if ($f.Status -ne "OK") {
            if ($f.Detail)      { Write-Host "    Neden: $($f.Detail)"      -ForegroundColor DarkGray }
            if ($f.Alternative) { Write-Host "    Oneri: $($f.Alternative)" -ForegroundColor DarkCyan }
        }
    }
    Write-Host ("`n  $($findings.Count) eslesme -- $($proh.Count) $($L["prohibited"])  $($lic.Count) $($L["requiresLicense"])  $($ok.Count) $($L["allowed"])") -ForegroundColor Cyan
    return $findings
}

# ─────────────────────────────────────────────
#  HTML RAPOR URETICISI
# ─────────────────────────────────────────────
function Export-HtmlReportFull {
    param([array]$AllResults, [array]$PolicyFindings)

    function Encode-Html ([string]$s) {
        $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;'
    }

    $ts       = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $hostname = $env:COMPUTERNAME

    $total     = if ($AllResults.Count -gt 0) { $AllResults.Count } else { 1 }
    $okCount   = @($AllResults | Where-Object { $_.Status -eq "OK"                 }).Count
    $warnCount = @($AllResults | Where-Object { $_.Status -eq "WARN"               }).Count
    $expCount  = @($AllResults | Where-Object { $_.Status -in @("EXPIRED","ERROR") }).Count
    $okPct     = [math]::Round($okCount   / $total * 100)
    $warnPct   = [math]::Round($warnCount / $total * 100)
    $expPct    = [math]::Round($expCount  / $total * 100)

    $tableRows = ($AllResults | ForEach-Object {
        $bc   = switch ($_.Status) { "OK" { "ok" } "WARN" { "warn" } default { "expired" } }
        $trTx = switch ($_.Status) { "OK" { "UYUMLU" } "WARN" { "UYARI" } "EXPIRED" { "SURESI DOLDU" } default { "HATA" } }
        $enTx = switch ($_.Status) { "OK" { "OK" } "WARN" { "WARNING" } "EXPIRED" { "EXPIRED" } default { "ERROR" } }
        $det  = if ($_.Detail) { Encode-Html $_.Detail } else { "&mdash;" }
        "<tr data-status='$($_.Status)'><td>$($_.Module)</td><td>$($_.Name)</td><td>$det</td><td><span class='badge $bc' data-val-tr='$trTx' data-val-en='$enTx'>$trTx</span></td></tr>"
    }) -join "`n"

    $prohibCount  = 0
    $licCount     = 0
    $allowedCount = 0
    $prohibPct    = 0
    $licPct       = 0
    $allowedPct   = 0
    $policyRows   = ""
    if ($PolicyFindings -and $PolicyFindings.Count -gt 0) {
        $pTotal       = $PolicyFindings.Count
        $prohibCount  = @($PolicyFindings | Where-Object { $_.PolicyStatus -eq "PROHIBITED"       }).Count
        $licCount     = @($PolicyFindings | Where-Object { $_.PolicyStatus -eq "REQUIRES_LICENSE" }).Count
        $allowedCount = @($PolicyFindings | Where-Object { $_.PolicyStatus -eq "ALLOWED"          }).Count
        $prohibPct    = [math]::Round($prohibCount  / $pTotal * 100)
        $licPct       = [math]::Round($licCount     / $pTotal * 100)
        $allowedPct   = [math]::Round($allowedCount / $pTotal * 100)
        $policyRows   = ($PolicyFindings | ForEach-Object {
            $bc    = switch ($_.PolicyStatus) { "PROHIBITED" { "expired" } "REQUIRES_LICENSE" { "warn" } default { "ok" } }
            $lblTr = switch ($_.PolicyStatus) { "PROHIBITED" { "YASAK" } "REQUIRES_LICENSE" { "LISANS GEREKLI" } default { "UYUMLU" } }
            $lblEn = switch ($_.PolicyStatus) { "PROHIBITED" { "PROHIBITED" } "REQUIRES_LICENSE" { "REQUIRES LICENSE" } default { "COMPLIANT" } }
            $alt   = if ($_.Alternative) { "<br><small class='suggestion'>&#x1F4A1; $(Encode-Html $_.Alternative)</small>" } else { "" }
            $ref   = if ($_.Reference)   { " <a href='$(Encode-Html $_.Reference)' target='_blank' class='reflink'>&#x2197;</a>" } else { "" }
            "<tr data-policy='$($_.PolicyStatus)'><td>$($_.Category)</td><td><span class='sw-name'>$(Encode-Html $_.Name)</span><br><small class='sw-meta'>$(Encode-Html $_.Version) &middot; $(Encode-Html $_.Publisher)</small></td><td>$(Encode-Html $_.Detail)$alt$ref</td><td><span class='badge $bc' data-val-tr='$lblTr' data-val-en='$lblEn'>$lblTr</span></td></tr>"
        }) -join "`n"
    }

    $initLang = $Lang

    $html = @"
<!DOCTYPE html>
<html lang="$initLang" id="htmlRoot">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title data-i18n="pageTitle">LicenseGuard Raporu</title>
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: 'Segoe UI', system-ui, sans-serif; background: #0d1117; color: #c9d1d9; min-height: 100vh; }

.top-bar {
  position: sticky; top: 0; z-index: 100;
  background: #161b22; border-bottom: 1px solid #30363d;
  padding: .75rem 2rem; display: flex; align-items: center; gap: 1rem;
}
.top-bar h1 { color: #58a6ff; font-size: 1.25rem; flex: 1; }
.top-bar .meta { color: #8b949e; font-size: .8rem; white-space: nowrap; }
.lang-btn {
  background: #21262d; border: 1px solid #30363d; color: #c9d1d9;
  padding: .3rem .85rem; border-radius: 6px; cursor: pointer;
  font-size: .8rem; font-weight: 700; letter-spacing: .06em;
  transition: background .15s, border-color .15s, color .15s;
}
.lang-btn:hover { background: #30363d; border-color: #58a6ff; color: #58a6ff; }

.content { padding: 2rem; max-width: 1400px; margin: 0 auto; }

h2 {
  color: #8b949e; font-size: .75rem; text-transform: uppercase;
  letter-spacing: .1em; margin: 2.5rem 0 1rem;
  display: flex; align-items: center; gap: .6rem;
}
h2::after { content: ''; flex: 1; height: 1px; background: #21262d; }

.cards { display: flex; gap: .75rem; margin-bottom: 1.25rem; flex-wrap: wrap; }
.card {
  background: #161b22; border: 1px solid #30363d; border-radius: 10px;
  padding: .9rem 1.4rem; flex: 1; min-width: 110px; text-align: center;
  transition: transform .15s, box-shadow .15s;
}
.card:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(0,0,0,.3); }
.card .num { font-size: 1.9rem; font-weight: 700; line-height: 1.1; }
.card .pct { font-size: .72rem; color: #484f58; margin-top: .1rem; }
.card .lbl { font-size: .7rem; color: #8b949e; margin-top: .3rem; text-transform: uppercase; letter-spacing: .06em; }
.card.ok   { border-color: #1a3a1a; } .card.ok   .num { color: #3fb950; }
.card.warn { border-color: #3a2800; } .card.warn .num { color: #d29922; }
.card.exp  { border-color: #3a0d0d; } .card.exp  .num { color: #f85149; }

.toolbar { display: flex; gap: .65rem; align-items: center; margin-bottom: .65rem; flex-wrap: wrap; }
.search-wrap { position: relative; flex: 1; min-width: 180px; max-width: 380px; }
.search-wrap .ico {
  position: absolute; left: .6rem; top: 50%; transform: translateY(-50%);
  width: 13px; height: 13px; fill: #484f58; pointer-events: none;
}
.search-input {
  width: 100%; background: #161b22; border: 1px solid #30363d; color: #c9d1d9;
  padding: .42rem .7rem .42rem 1.9rem; border-radius: 6px; font-size: .85rem; outline: none;
  transition: border-color .15s;
}
.search-input:focus { border-color: #58a6ff; }
.search-input::placeholder { color: #484f58; }
.filter-check { display: flex; align-items: center; gap: .4rem; font-size: .78rem; color: #8b949e; cursor: pointer; user-select: none; white-space: nowrap; }
.filter-check input { accent-color: #58a6ff; cursor: pointer; }

.table-wrap { overflow-x: auto; border-radius: 10px; border: 1px solid #30363d; }
table { width: 100%; border-collapse: collapse; background: #161b22; font-size: .875rem; }
th { background: #21262d; padding: .6rem 1rem; text-align: left; font-size: .68rem; text-transform: uppercase; letter-spacing: .07em; color: #8b949e; white-space: nowrap; }
th.sortable { cursor: pointer; user-select: none; }
th.sortable:hover { color: #c9d1d9; }
th.sort-asc::after  { content: ' \2191'; color: #58a6ff; }
th.sort-desc::after { content: ' \2193'; color: #58a6ff; }
td { padding: .62rem 1rem; border-top: 1px solid #21262d; vertical-align: top; line-height: 1.5; }
tr:hover td { background: #1c2128; }
tr.row-hidden { display: none; }

.badge { display: inline-block; padding: .18rem .6rem; border-radius: 20px; font-size: .68rem; font-weight: 700; letter-spacing: .05em; white-space: nowrap; }
.badge.ok      { background: #0d3a1a; color: #3fb950; border: 1px solid #1a5c28; }
.badge.warn    { background: #2e1f00; color: #d29922; border: 1px solid #5a3c00; }
.badge.expired { background: #2e0d0d; color: #f85149; border: 1px solid #5a1a1a; }

.sw-name { font-weight: 500; }
.sw-meta { color: #484f58; font-size: .78rem; }
.suggestion { color: #58a6ff; display: block; margin-top: .2rem; }
.reflink { color: #58a6ff; font-size: .78rem; text-decoration: none; }
.reflink:hover { text-decoration: underline; }
.no-results { text-align: center; color: #484f58; padding: 2rem !important; }
footer { margin-top: 3rem; padding: 1.5rem 2rem; text-align: center; color: #484f58; font-size: .75rem; border-top: 1px solid #21262d; }

@media (max-width: 680px) {
  .top-bar { padding: .55rem 1rem; flex-wrap: wrap; }
  .top-bar .meta { font-size: .72rem; }
  .content { padding: 1rem; }
  .card .num { font-size: 1.5rem; }
}
</style>
</head>
<body>

<div class="top-bar">
  <h1>&#x1F510; <span data-i18n="reportTitle">LicenseGuard</span></h1>
  <span class="meta">$hostname &nbsp;&middot;&nbsp; $ts &nbsp;&middot;&nbsp; <span data-i18n="warnThreshold">Uyari esigi</span>: ${warnDays} <span data-i18n="days">gun</span></span>
  <button class="lang-btn" id="langBtn" onclick="toggleLang()">EN</button>
</div>

<div class="content">

<h2 data-i18n="licenseSection">&#x1F4CA; Lisans Durumu</h2>
<div class="cards">
  <div class="card ok">
    <div class="num" id="c1ok-n">-</div><div class="pct" id="c1ok-p"></div>
    <div class="lbl" data-i18n="valid">Gecerli</div>
  </div>
  <div class="card warn">
    <div class="num" id="c1wn-n"></div><div class="pct" id="c1wn-p"></div>
    <div class="lbl" data-i18n="warning">Uyari</div>
  </div>
  <div class="card exp">
    <div class="num" id="c1er-n"></div><div class="pct" id="c1er-p"></div>
    <div class="lbl" data-i18n="errorExp">Hata / Dolmus</div>
  </div>
</div>
<div class="toolbar">
  <div class="search-wrap">
    <svg class="ico" viewBox="0 0 16 16"><path d="M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398h-.001l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85a1.007 1.007 0 0 0-.115-.099 6.5 6.5 0 0 0-1.397-1.398h-.001l.001-.001zm-5.242 1.656a5.5 5.5 0 1 1 0-11 5.5 5.5 0 0 1 0 11z"/></svg>
    <input class="search-input" id="s1" data-table="t1" oninput="filterTable(this)" data-i18n-ph="searchPh" placeholder="Yazilim ara...">
  </div>
  <label class="filter-check"><input type="checkbox" id="f1" data-table="t1" onchange="toggleFilter(this)"> <span data-i18n="issuesOnly">Sadece sorunlar</span></label>
</div>
<div class="table-wrap">
  <table id="t1">
    <thead><tr>
      <th class="sortable" onclick="sortTable('t1',0)" data-i18n="moduleCol">Modul</th>
      <th class="sortable" onclick="sortTable('t1',1)" data-i18n="nameCol">Ad</th>
      <th data-i18n="detailCol">Detay</th>
      <th class="sortable" onclick="sortTable('t1',3)" data-i18n="statusCol">Durum</th>
    </tr></thead>
    <tbody>
$tableRows
    </tbody>
  </table>
</div>

<h2 data-i18n="policySection">&#x1F6E1;&#xFE0F; Kurumsal Lisans Uyumluluk</h2>
<div class="cards">
  <div class="card exp">
    <div class="num" id="c2bn-n"></div><div class="pct" id="c2bn-p"></div>
    <div class="lbl" data-i18n="banned">Yasak</div>
  </div>
  <div class="card warn">
    <div class="num" id="c2lc-n"></div><div class="pct" id="c2lc-p"></div>
    <div class="lbl" data-i18n="needsLic">Lisans Gerekli</div>
  </div>
  <div class="card ok">
    <div class="num" id="c2ok-n">-</div><div class="pct" id="c2ok-p"></div>
    <div class="lbl" data-i18n="compliant">Uyumlu</div>
  </div>
</div>
<div class="toolbar">
  <div class="search-wrap">
    <svg class="ico" viewBox="0 0 16 16"><path d="M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398h-.001l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85a1.007 1.007 0 0 0-.115-.099 6.5 6.5 0 0 0-1.397-1.398h-.001l.001-.001zm-5.242 1.656a5.5 5.5 0 1 1 0-11 5.5 5.5 0 0 1 0 11z"/></svg>
    <input class="search-input" id="s2" data-table="t2" oninput="filterTable(this)" data-i18n-ph="searchPh" placeholder="Yazilim ara...">
  </div>
  <label class="filter-check"><input type="checkbox" id="f2" data-table="t2" onchange="toggleFilter(this)"> <span data-i18n="issuesOnly">Sadece sorunlar</span></label>
</div>
<div class="table-wrap">
  <table id="t2">
    <thead><tr>
      <th class="sortable" onclick="sortTable('t2',0)" data-i18n="categoryCol">Kategori</th>
      <th class="sortable" onclick="sortTable('t2',1)" data-i18n="softwareCol">Yazilim</th>
      <th data-i18n="descCol">Aciklama / Oneri</th>
      <th class="sortable" onclick="sortTable('t2',3)" data-i18n="statusCol">Durum</th>
    </tr></thead>
    <tbody>
$policyRows
    </tbody>
  </table>
</div>

</div>
<footer>LicenseGuard &middot; Mustafa Sercan Sak</footer>

<script>
var i18n = {
  tr: {
    pageTitle:'LicenseGuard Raporu', reportTitle:'LicenseGuard',
    licenseSection:'&#x1F4CA; Lisans Durumu',
    policySection:'&#x1F6E1;&#xFE0F; Kurumsal Lisans Uyumluluk',
    moduleCol:'Modul', nameCol:'Ad', detailCol:'Detay', statusCol:'Durum',
    categoryCol:'Kategori', softwareCol:'Yazilim', descCol:'Aciklama / Oneri',
    searchPh:'Yazilim ara...', issuesOnly:'Sadece sorunlar',
    valid:'Gecerli', warning:'Uyari', errorExp:'Hata / Dolmus',
    banned:'Yasak', needsLic:'Lisans Gerekli', compliant:'Uyumlu',
    warnThreshold:'Uyari esigi', days:'gun'
  },
  en: {
    pageTitle:'LicenseGuard Report', reportTitle:'LicenseGuard',
    licenseSection:'&#x1F4CA; License Status',
    policySection:'&#x1F6E1;&#xFE0F; Corporate License Compliance',
    moduleCol:'Module', nameCol:'Name', detailCol:'Detail', statusCol:'Status',
    categoryCol:'Category', softwareCol:'Software', descCol:'Description / Suggestion',
    searchPh:'Search software...', issuesOnly:'Issues only',
    valid:'Valid', warning:'Warning', errorExp:'Error / Expired',
    banned:'Banned', needsLic:'Needs License', compliant:'Compliant',
    warnThreshold:'Warning threshold', days:'days'
  }
};

var currentLang = '$initLang';

function applyLang(lang) {
  currentLang = lang;
  document.getElementById('htmlRoot').lang = lang;
  document.getElementById('langBtn').textContent = lang === 'tr' ? 'EN' : 'TR';
  document.querySelectorAll('[data-i18n]').forEach(function(el) {
    var k = el.getAttribute('data-i18n');
    if (i18n[lang][k] !== undefined) el.innerHTML = i18n[lang][k];
  });
  document.querySelectorAll('[data-i18n-ph]').forEach(function(el) {
    var k = el.getAttribute('data-i18n-ph');
    if (i18n[lang][k] !== undefined) el.placeholder = i18n[lang][k];
  });
  document.querySelectorAll('[data-val-tr]').forEach(function(el) {
    el.textContent = lang === 'tr' ? el.dataset.valTr : el.dataset.valEn;
  });
  document.title = i18n[lang].pageTitle;
  try { localStorage.setItem('lg_lang', lang); } catch(e) {}
}

function toggleLang() { applyLang(currentLang === 'tr' ? 'en' : 'tr'); }

function filterTable(inp) {
  var tid = inp.dataset.table;
  var q   = inp.value.toLowerCase();
  var n   = tid.replace('t','');
  applyFilter(tid, q, document.getElementById('f'+n).checked);
}
function toggleFilter(cb) {
  var tid = cb.dataset.table;
  var n   = tid.replace('t','');
  applyFilter(tid, document.getElementById('s'+n).value.toLowerCase(), cb.checked);
}
function applyFilter(tid, q, issuesOnly) {
  var rows = document.querySelectorAll('#'+tid+' tbody tr:not(.no-results-row)');
  var vis  = 0;
  rows.forEach(function(r) {
    var badge   = r.querySelector('.badge');
    var isIssue = badge && (badge.classList.contains('expired') || badge.classList.contains('warn'));
    var show    = (!q || r.textContent.toLowerCase().indexOf(q) !== -1) && (!issuesOnly || isIssue);
    r.classList.toggle('row-hidden', !show);
    if (show) vis++;
  });
  var nr = document.querySelector('#'+tid+' .no-results-row');
  if (!nr) {
    nr = document.createElement('tr');
    nr.className = 'no-results-row row-hidden';
    nr.innerHTML = '<td colspan="4" class="no-results">&#x2205; Sonuc yok / No results</td>';
    document.querySelector('#'+tid+' tbody').appendChild(nr);
  }
  nr.classList.toggle('row-hidden', vis > 0);
}

var sortState = {};
function sortTable(tid, ci) {
  var key = tid+':'+ci;
  var asc = !sortState[key];
  sortState[key] = asc;
  var t = document.getElementById(tid);
  t.querySelectorAll('th.sortable').forEach(function(th) { th.classList.remove('sort-asc','sort-desc'); });
  t.querySelectorAll('th')[ci].classList.add(asc ? 'sort-asc' : 'sort-desc');
  var tb   = t.querySelector('tbody');
  var rows = Array.prototype.slice.call(tb.querySelectorAll('tr:not(.no-results-row)'));
  rows.sort(function(a,b) {
    var av = (a.cells[ci] ? a.cells[ci].textContent : '').trim();
    var bv = (b.cells[ci] ? b.cells[ci].textContent : '').trim();
    return asc ? av.localeCompare(bv,undefined,{numeric:true,sensitivity:'base'})
               : bv.localeCompare(av,undefined,{numeric:true,sensitivity:'base'});
  });
  var nr = tb.querySelector('.no-results-row');
  rows.forEach(function(r) { tb.insertBefore(r, nr); });
}

function updateCards() {
  var t1rows = document.querySelectorAll('#t1 tbody tr:not(.no-results-row)');
  var l1ok=0, l1wn=0, l1er=0;
  t1rows.forEach(function(r) {
    var s = r.getAttribute('data-status');
    if (s==='OK') l1ok++; else if (s==='WARN') l1wn++; else l1er++;
  });
  var lt = t1rows.length || 1;
  document.getElementById('c1ok-n').textContent = l1ok;
  document.getElementById('c1ok-p').textContent = Math.round(l1ok/lt*100)+'%';
  document.getElementById('c1wn-n').textContent = l1wn || '';
  document.getElementById('c1wn-p').textContent = l1wn ? Math.round(l1wn/lt*100)+'%' : '';
  document.getElementById('c1er-n').textContent = l1er || '';
  document.getElementById('c1er-p').textContent = l1er ? Math.round(l1er/lt*100)+'%' : '';

  var t2rows = document.querySelectorAll('#t2 tbody tr:not(.no-results-row)');
  var l2bn=0, l2lc=0, l2ok=0;
  t2rows.forEach(function(r) {
    var s = r.getAttribute('data-policy');
    if (s==='PROHIBITED') l2bn++; else if (s==='REQUIRES_LICENSE') l2lc++; else l2ok++;
  });
  var pt = t2rows.length || 1;
  document.getElementById('c2bn-n').textContent = l2bn || '';
  document.getElementById('c2bn-p').textContent = l2bn ? Math.round(l2bn/pt*100)+'%' : '';
  document.getElementById('c2lc-n').textContent = l2lc || '';
  document.getElementById('c2lc-p').textContent = l2lc ? Math.round(l2lc/pt*100)+'%' : '';
  document.getElementById('c2ok-n').textContent = l2ok;
  document.getElementById('c2ok-p').textContent = Math.round(l2ok/pt*100)+'%';
}

window.addEventListener('load', function() {
  updateCards();
  try {
    var saved = localStorage.getItem('lg_lang');
    if (saved && saved !== currentLang) applyLang(saved);
  } catch(e) {}
});
</script>
</body>
</html>
"@

    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "`n  $($L["reportSaved"]) $OutputPath" -ForegroundColor Cyan
}

# ─────────────────────────────────────────────
#  CALISTIRICI
# ─────────────────────────────────────────────
Write-Host "`n  $($L["starting"])`n" -ForegroundColor White

$allResults     = [System.Collections.Generic.List[hashtable]]::new()
$policyFindings = @()

$r1 = Get-WindowsActivation;      if ($r1) { $allResults.Add($r1) }
$r2 = Get-InstalledSoftwareAudit; if ($r2) { $r2 | ForEach-Object { $allResults.Add($_) } }
$r3 = Get-FlexLMStatus;           if ($r3) { $r3 | ForEach-Object { $allResults.Add($_) } }
$r4 = Get-SaaSStatus;             if ($r4) { $r4 | ForEach-Object { $allResults.Add($_) } }
$policyFindings = Invoke-PolicyCheck -PolicyPath $PolicyPath

if (-not $ConsoleOnly) {
    Export-HtmlReportFull -AllResults $allResults -PolicyFindings $policyFindings
}

$criticalLicense = @($allResults     | Where-Object { $_.Status -in @("EXPIRED","ERROR") })
$prohibited      = @($policyFindings | Where-Object { $_.PolicyStatus -eq "PROHIBITED"       })
$needsLic        = @($policyFindings | Where-Object { $_.PolicyStatus -eq "REQUIRES_LICENSE" })

Write-Host ""
if ($criticalLicense) { Write-Host "  [!!] $($criticalLicense.Count) $($L["criticalCount"])"   -ForegroundColor Red    }
if ($prohibited)      { Write-Host "  [XX] $($prohibited.Count) $($L["prohibitedFound"])"       -ForegroundColor Red    }
if ($needsLic)        { Write-Host "  [!]  $($needsLic.Count) $($L["needsLicCount"])"           -ForegroundColor Yellow }
if (-not $criticalLicense -and -not $prohibited -and -not $needsLic) {
    Write-Host "  [OK] $($L["allClear"])" -ForegroundColor Green
}
Write-Host ""
