param(
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$ConfigPath  = '.\lg-config.json',
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$OutputPath  = '.\license-report.html',
    [Parameter(Mandatory=$false)][switch]$ConsoleOnly,
    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()][string]$PolicyPath  = '.\lg-policy.json',
    [Parameter(Mandatory=$false)][ValidateSet("tr","en")][string]$Lang          = "tr",
    [Parameter(Mandatory=$false)][string]$ExportCsv                             = "",
    [Parameter(Mandatory=$false)][string]$ExportJson                            = "",
    [Parameter(Mandatory=$false)][switch]$SendMail,
    [Parameter(Mandatory=$false)][string]$ComputerName                          = "",
    [Parameter(Mandatory=$false)][switch]$NoDelta,
    [Parameter(Mandatory=$false)][switch]$TestPolicy,
    [Parameter(Mandatory=$false)][switch]$CheckSignatures,
    [Parameter(Mandatory=$false)][string]$SarifPath                             = "",
    [Parameter(Mandatory=$false)][switch]$NoUpdateCheck,
    [Parameter(Mandatory=$false)][switch]$CreateJiraIssues
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"
$LGVersion = "3.0"

# ─────────────────────────────────────────────
#  DIL DESTEGI
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
        hdrWinAct       = "Windows Aktivasyon"
        hdrSoftware     = "Kurulu Yazilim Envanteri"
        hdrFlexLM       = "FlexLM Lisans Sunucusu"
        hdrSaaS         = "SaaS / API Key Durumu"
        hdrEol          = "EOL / Destek Sonu Taramasi"
        publisherUnknown= "Bilinmiyor"
        eolSection      = "EOL / Destek Sonu"
        calSection      = "Lisans Takvimi"
        severity        = "Onem"
        whitelist       = "ONAYLANMIS"
        noExpiry        = "Yaklasan bitis tarihi bulunamadi"
        exportCsv       = "CSV Indir"
        exportJson      = "JSON Indir"
        printPdf        = "PDF Yazdir"
        deltaTitle      = "Degisiklikler"
        deltaNew        = "yeni sorun"
        deltaResolved   = "cozuldu"
        deltaSince      = "Onceki tarama:"
        navCalendar     = "Takvim"
        navBrowserExt   = "Tarayici Eklentileri"
        navVsCode       = "VS Code"
        navStartup      = "Baslangi"
        navProcess      = "Aktif Processler"
        navSignature    = "Imza"
        snapshotSaved   = "Snapshot kaydedildi:"
        hdrBrowser      = "Tarayici Eklentileri Taramasi"
        hdrVsCode       = "VS Code Eklentileri"
        hdrStartup      = "Baslangi Programlari"
        hdrProcess      = "Yasak Process Taramasi"
        hdrSignature    = "Dijital Imza Dogrulama"
        updateAvail     = "Yeni surum mevcut"
        updateCurrent   = "Guncel surum kullaniliyor"
        sarifSaved      = "SARIF rapor kaydedildi:"
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
        hdrWinAct       = "Windows Activation"
        hdrSoftware     = "Installed Software Inventory"
        hdrFlexLM       = "FlexLM License Server"
        hdrSaaS         = "SaaS / API Key Status"
        hdrEol          = "EOL / End-of-Support Scan"
        publisherUnknown= "Unknown"
        eolSection      = "EOL / End of Support"
        calSection      = "License Calendar"
        severity        = "Severity"
        whitelist       = "APPROVED"
        noExpiry        = "No upcoming expiry dates found"
        exportCsv       = "Export CSV"
        exportJson      = "Export JSON"
        printPdf        = "Print PDF"
        deltaTitle      = "Changes"
        deltaNew        = "new issue"
        deltaResolved   = "resolved"
        deltaSince      = "Previous scan:"
        navCalendar     = "Calendar"
        navBrowserExt   = "Browser Extensions"
        navVsCode       = "VS Code"
        navStartup      = "Startup"
        navProcess      = "Running Processes"
        navSignature    = "Signature"
        snapshotSaved   = "Snapshot saved:"
        hdrBrowser      = "Browser Extension Scan"
        hdrVsCode       = "VS Code Extensions"
        hdrStartup      = "Startup Programs"
        hdrProcess      = "Prohibited Process Scan"
        hdrSignature    = "Digital Signature Verification"
        updateAvail     = "New version available"
        updateCurrent   = "Using latest version"
        sarifSaved      = "SARIF report saved:"
    }
}[$Lang]

# ─────────────────────────────────────────────
#  KONFIGURASYON
# ─────────────────────────────────────────────
$defaultConfig = @{
    FlexLM                  = @()
    SaaS                    = @()
    WarnDaysBeforeExpiry    = 30
    Whitelist               = @()
    SnapshotPath            = ".\lg-snapshot.json"
    EolCheck                = $true
    Email                   = $null
    Webhook                 = $null
    Jira                    = $null
    Branding                = $null
    ScanBrowserExtensions   = $true
    ScanVsCodeExtensions    = $true
    ScanStartup             = $true
}

$config = $defaultConfig
if (Test-Path $ConfigPath) {
    try {
        $loaded = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        if ($null -ne $loaded.FlexLM)              { $config.FlexLM               = $loaded.FlexLM               }
        if ($null -ne $loaded.SaaS)                { $config.SaaS                 = $loaded.SaaS                 }
        if ($null -ne $loaded.WarnDaysBeforeExpiry){ $config.WarnDaysBeforeExpiry = $loaded.WarnDaysBeforeExpiry }
        if ($null -ne $loaded.Whitelist)           { $config.Whitelist            = $loaded.Whitelist            }
        if ($null -ne $loaded.SnapshotPath)        { $config.SnapshotPath         = $loaded.SnapshotPath         }
        if ($null -ne $loaded.EolCheck)              { $config.EolCheck              = $loaded.EolCheck              }
        if ($null -ne $loaded.Email)               { $config.Email                = $loaded.Email                }
        if ($null -ne $loaded.Webhook)             { $config.Webhook              = $loaded.Webhook              }
        if ($null -ne $loaded.Jira)                { $config.Jira                 = $loaded.Jira                 }
        if ($null -ne $loaded.Branding)            { $config.Branding             = $loaded.Branding             }
        if ($null -ne $loaded.ScanBrowserExtensions){ $config.ScanBrowserExtensions = $loaded.ScanBrowserExtensions }
        if ($null -ne $loaded.ScanVsCodeExtensions) { $config.ScanVsCodeExtensions  = $loaded.ScanVsCodeExtensions  }
        if ($null -ne $loaded.ScanStartup)         { $config.ScanStartup          = $loaded.ScanStartup          }
        Write-Host "  Konfigurasyon yuklendi: $ConfigPath" -ForegroundColor DarkGray
    } catch {
        Write-Host "  [WARN] Konfigurasyon okunamadi: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
$warnDays = $config.WarnDaysBeforeExpiry

# ─────────────────────────────────────────────
#  EOL VERITABANI
# ─────────────────────────────────────────────
$eolDatabase = @(
    [PSCustomObject]@{ Pattern="Internet Explorer";     MatchType="contains";   EolDate="2022-06-15" }
    [PSCustomObject]@{ Pattern="Office 2010";           MatchType="contains";   EolDate="2020-10-13" }
    [PSCustomObject]@{ Pattern="Office 2013";           MatchType="contains";   EolDate="2023-04-11" }
    [PSCustomObject]@{ Pattern="Microsoft Office 2013"; MatchType="contains";   EolDate="2023-04-11" }
    [PSCustomObject]@{ Pattern="Office 2016";           MatchType="contains";   EolDate="2025-10-14" }
    [PSCustomObject]@{ Pattern="Office 2019";           MatchType="contains";   EolDate="2025-10-14" }
    [PSCustomObject]@{ Pattern="Silverlight";           MatchType="contains";   EolDate="2021-10-12" }
    [PSCustomObject]@{ Pattern="Adobe Flash";           MatchType="contains";   EolDate="2020-12-31" }
    [PSCustomObject]@{ Pattern="Flash Player";          MatchType="contains";   EolDate="2020-12-31" }
    [PSCustomObject]@{ Pattern="Python 2";              MatchType="startsWith"; EolDate="2020-01-01" }
    [PSCustomObject]@{ Pattern="Visual Studio 2015";    MatchType="contains";   EolDate="2025-10-14" }
    [PSCustomObject]@{ Pattern="Visual Studio 2017";    MatchType="contains";   EolDate="2027-04-14" }
    [PSCustomObject]@{ Pattern="SQL Server 2012";       MatchType="contains";   EolDate="2022-07-12" }
    [PSCustomObject]@{ Pattern="SQL Server 2014";       MatchType="contains";   EolDate="2024-07-09" }
    [PSCustomObject]@{ Pattern="SQL Server 2016";       MatchType="contains";   EolDate="2026-07-14" }
    [PSCustomObject]@{ Pattern="SQL Server 2017";       MatchType="contains";   EolDate="2027-10-12" }
    [PSCustomObject]@{ Pattern="Exchange Server 2013";  MatchType="contains";   EolDate="2023-04-11" }
    [PSCustomObject]@{ Pattern="Exchange Server 2016";  MatchType="contains";   EolDate="2025-10-14" }
    [PSCustomObject]@{ Pattern="SharePoint 2013";       MatchType="contains";   EolDate="2023-04-11" }
    [PSCustomObject]@{ Pattern="SharePoint 2016";       MatchType="contains";   EolDate="2026-07-14" }
    [PSCustomObject]@{ Pattern="Windows 7";             MatchType="contains";   EolDate="2020-01-14" }
    [PSCustomObject]@{ Pattern="Windows 8.1";           MatchType="contains";   EolDate="2023-01-10" }
    [PSCustomObject]@{ Pattern="Node.js 14";            MatchType="contains";   EolDate="2023-04-30" }
    [PSCustomObject]@{ Pattern="Node.js 16";            MatchType="contains";   EolDate="2023-09-11" }
    [PSCustomObject]@{ Pattern="Angular 12";            MatchType="contains";   EolDate="2022-11-12" }
    [PSCustomObject]@{ Pattern="Angular 13";            MatchType="contains";   EolDate="2023-05-04" }
    [PSCustomObject]@{ Pattern="Java SE 8";             MatchType="contains";   EolDate="2030-12-31" }
)

# ─────────────────────────────────────────────
#  YARDIMCI FONKSIYONLAR
# ─────────────────────────────────────────────

function Encode-Html ([string]$s) {
    $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;'
}

function Write-Header {
    param([string]$Text)
    Write-Host "`n+------------------------------------------+" -ForegroundColor Cyan
    Write-Host   "|  $($Text.PadRight(40))|" -ForegroundColor Cyan
    Write-Host   "+------------------------------------------+" -ForegroundColor Cyan
}

function Write-Status {
    param([string]$Label, [string]$Value, [string]$Status)
    $color = switch ($Status) { "OK" {"Green"} "WARN" {"Yellow"} "EXPIRED" {"Red"} "ERROR" {"Red"} default {"Gray"} }
    $icon  = switch ($Status) { "OK" {"[OK]"} "WARN" {"[!!]"} "EXPIRED" {"[XX]"} "ERROR" {"[XX]"} default {"[--]"} }
    Write-Host ("  {0} {1,-38} {2}" -f $icon, $Label, $Value) -ForegroundColor $color
}

function Get-RemoteSoftwareCache {
    param([string]$Computer)
    Write-Host "  Uzak makine taranıyor: $Computer" -ForegroundColor DarkGray
    try {
        $wd = $warnDays
        $result = Invoke-Command -ComputerName $Computer -ArgumentList $wd -ErrorAction Stop -ScriptBlock {
            param($wd)
            $regPaths = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )
            $today = Get-Date; $rows = @()
            foreach ($path in $regPaths) {
                Get-ItemProperty $path 2>$null | Where-Object { $_.DisplayName } | ForEach-Object {
                    $name    = $_.DisplayName
                    $version = if ($_.DisplayVersion) { $_.DisplayVersion } else { "-" }
                    $pub     = if ($_.Publisher) { $_.Publisher } else { "Unknown" }
                    $installDate = $null
                    if ($_.InstallDate -match '^\d{8}$') {
                        try { $installDate = [datetime]::ParseExact($_.InstallDate,"yyyyMMdd",$null) } catch {}
                    }
                    $expireDate = $null
                    foreach ($field in @("ExpirationDate","TrialExpireDate","ExpireDate","LicenseExpiry")) {
                        $val = $_.$field
                        if ($val) {
                            try { $expireDate = [datetime]$val; break } catch {}
                            if ($val -match '^\d{8}$') { try { $expireDate = [datetime]::ParseExact($val,"yyyyMMdd",$null); break } catch {} }
                        }
                    }
                    $status = "OK"; $expInfo = ""
                    if ($expireDate) {
                        $dl = ($expireDate - $today).Days
                        if ($dl -lt 0)       { $status="EXPIRED"; $expInfo="EXPIRED ($([math]::Abs($dl)) days ago)" }
                        elseif ($dl -le $wd) { $status="WARN";    $expInfo="Expires: $($expireDate.ToString('yyyy-MM-dd')) ($dl days)" }
                        else                 { $expInfo="Valid: $($expireDate.ToString('yyyy-MM-dd'))" }
                    }
                    $rows += [PSCustomObject]@{
                        Name=$name; Version=$version; Publisher=$pub
                        InstallDate=if($installDate){$installDate.ToString("yyyy-MM-dd")}else{"-"}
                        ExpireInfo=$expInfo; Status=$status
                    }
                }
            }
            $rows | Sort-Object Name -Unique
        }
        return $result
    } catch {
        Write-Host "  [ERROR] $Computer WinRM hatasi: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Get-InstalledSoftwareCache {
    param([string]$Computer = "")
    if ($Computer) { return Get-RemoteSoftwareCache -Computer $Computer }
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $today = Get-Date; $rows = @()
    foreach ($path in $regPaths) {
        Get-ItemProperty $path 2>$null | Where-Object { $_.DisplayName } | ForEach-Object {
            $name    = $_.DisplayName
            $version = if ($_.DisplayVersion) { $_.DisplayVersion } else { "-" }
            $pub     = if ($_.Publisher)      { $_.Publisher }      else { $L["publisherUnknown"] }
            $installDateRaw = $_.InstallDate; $installDate = $null
            if ($installDateRaw -match '^\d{8}$') {
                try { $installDate = [datetime]::ParseExact($installDateRaw,"yyyyMMdd",$null) } catch {}
            }
            $expireDate = $null
            foreach ($field in @("ExpirationDate","TrialExpireDate","ExpireDate","LicenseExpiry")) {
                $val = $_.$field
                if ($val) {
                    try { $expireDate = [datetime]$val; break } catch {}
                    if ($val -match '^\d{8}$') { try { $expireDate = [datetime]::ParseExact($val,"yyyyMMdd",$null); break } catch {} }
                }
            }
            $status = "OK"
            $expInfo = if ($expireDate) {
                $daysLeft = ($expireDate - $today).Days
                if    ($daysLeft -lt 0)          { $status="EXPIRED"; "SURESI DOLDU ($([math]::Abs($daysLeft)) gun once)" }
                elseif ($daysLeft -le $warnDays) { $status="WARN";   "Bitiyor: $($expireDate.ToString('yyyy-MM-dd')) ($daysLeft gun)" }
                else                             { "Gecerli: $($expireDate.ToString('yyyy-MM-dd'))" }
            } else { "" }
            $rows += [PSCustomObject]@{
                Name=$name; Version=$version; Publisher=$pub
                InstallDate=if($installDate){$installDate.ToString("yyyy-MM-dd")}else{"-"}
                ExpireInfo=$expInfo; Status=$status
            }
        }
    }
    return $rows | Sort-Object Name -Unique
}

function Get-EolStatus {
    param([array]$Cache = $null)
    Write-Header $L["hdrEol"]
    $rows  = if ($Cache) { $Cache } else { Get-InstalledSoftwareCache }
    $today = Get-Date; $found = @(); $eolHit = 0
    foreach ($sw in $rows) {
        foreach ($entry in $eolDatabase) {
            $match = $false
            switch ($entry.MatchType) {
                "contains"   { if ($sw.Name -like "*$($entry.Pattern)*") { $match = $true } }
                "startsWith" { if ($sw.Name -like "$($entry.Pattern)*")  { $match = $true } }
                "exact"      { if ($sw.Name -eq $entry.Pattern)           { $match = $true } }
                "regex"      { if ($sw.Name -match $entry.Pattern)        { $match = $true } }
            }
            if ($match) {
                try {
                    $eolDate  = [datetime]::ParseExact($entry.EolDate,"yyyy-MM-dd",$null)
                    $daysLeft = ($eolDate - $today).Days
                    $status   = if ($daysLeft -lt 0) { "EXPIRED" } else { "WARN" }
                    $detail   = if ($daysLeft -lt 0) {
                        "EOL: $($entry.EolDate) ($([math]::Abs($daysLeft)) gun once)"
                    } else {
                        "EOL Yaklasıyor: $($entry.EolDate) ($daysLeft gun kaldi)"
                    }
                    Write-Status $sw.Name $detail $status
                    $found += @{ Module="EOL"; Name=$sw.Name; Status=$status; Detail=$detail }
                    $eolHit++
                } catch {}
                break
            }
        }
    }
    if ($eolHit -eq 0) { Write-Status "EOL taramasi" "Destek sonu tespit edilmedi" "OK" }
    return $found
}

function Save-Snapshot {
    param([array]$AllResults, [array]$PolicyFindings, [string]$SnapshotPath)
    try {
        [PSCustomObject]@{
            Timestamp  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            Hostname   = $env:COMPUTERNAME
            Issues     = @($AllResults     | Where-Object { $_.Status -ne "OK" }            | ForEach-Object { $_.Name })
            Violations = @($PolicyFindings | Where-Object { $_.PolicyStatus -ne "ALLOWED" } | ForEach-Object { $_.Name })
        } | ConvertTo-Json -Compress | Out-File $SnapshotPath -Encoding UTF8 -Force
        Write-Host "  $($L["snapshotSaved"]) $SnapshotPath" -ForegroundColor DarkGray
    } catch {}
}

function Get-Delta {
    param([string]$SnapshotPath, [array]$CurrentResults, [array]$CurrentPolicyFindings)
    if (-not (Test-Path $SnapshotPath)) { return $null }
    try { $prev = Get-Content $SnapshotPath -Raw | ConvertFrom-Json } catch { return $null }
    if (-not $prev) { return $null }
    $prevIssues     = @(if ($prev.Issues)     { $prev.Issues }     else { @() })
    $prevViolations = @(if ($prev.Violations) { $prev.Violations } else { @() })
    $currIssues     = @($CurrentResults | Where-Object { $_.Status -ne "OK" } | ForEach-Object { $_.Name })
    $currViolations = @($CurrentPolicyFindings | Where-Object { $_.PolicyStatus -ne "ALLOWED" } | ForEach-Object { $_.Name })
    return [PSCustomObject]@{
        PreviousTimestamp  = $prev.Timestamp
        NewIssues          = @($currIssues     | Where-Object { $prevIssues     -notcontains $_ })
        ResolvedIssues     = @($prevIssues     | Where-Object { $currIssues     -notcontains $_ })
        NewViolations      = @($currViolations | Where-Object { $prevViolations -notcontains $_ })
        ResolvedViolations = @($prevViolations | Where-Object { $currViolations -notcontains $_ })
    }
}

function Write-LGEventLog {
    param([string]$Message, [string]$EntryType = "Information", [int]$EventId = 1000)
    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists("LicenseGuard")) {
            [System.Diagnostics.EventLog]::CreateEventSource("LicenseGuard","Application")
        }
        Write-EventLog -LogName "Application" -Source "LicenseGuard" -EventId $EventId -EntryType $EntryType -Message $Message
    } catch {}
}

function Export-CsvReport {
    param([array]$AllResults, [array]$PolicyFindings, [string]$CsvPath)
    try {
        $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($r in $AllResults) {
            $rows.Add([PSCustomObject]@{
                Type="LicenseStatus"; Module=$r.Module; Name=$r.Name
                Detail=if($r.Detail){$r.Detail}else{""}
                Status=$r.Status; PolicyStatus=""; Category=""; Severity=""
            })
        }
        foreach ($f in $PolicyFindings) {
            $rows.Add([PSCustomObject]@{
                Type="PolicyCheck"; Module="PolicyCheck"; Name=$f.Name
                Detail=if($f.Detail){$f.Detail}else{""}
                Status=$f.Status; PolicyStatus=$f.PolicyStatus
                Category=if($f.Category){$f.Category}else{""}
                Severity=if($f.Severity){$f.Severity}else{""}
            })
        }
        $rows | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
        Write-Host "  CSV rapor kaydedildi: $CsvPath" -ForegroundColor Cyan
    } catch {
        Write-Host "  [WARN] CSV hatasi: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Export-JsonReport {
    param([array]$AllResults, [array]$PolicyFindings, [string]$JsonPath)
    try {
        [PSCustomObject]@{
            Timestamp      = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Hostname       = $env:COMPUTERNAME
            Version        = $LGVersion
            LicenseStatus  = $AllResults
            PolicyFindings = $PolicyFindings
        } | ConvertTo-Json -Depth 5 | Out-File $JsonPath -Encoding UTF8
        Write-Host "  JSON rapor kaydedildi: $JsonPath" -ForegroundColor Cyan
    } catch {
        Write-Host "  [WARN] JSON hatasi: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Send-MailReport {
    param([object]$EmailConfig, [string]$ReportPath, [string]$Summary)
    if (-not $EmailConfig) {
        Write-Host "  [WARN] Email konfig (lg-config.json -> Email) bulunamadi." -ForegroundColor Yellow
        return
    }
    try {
        $params = @{
            SmtpServer = $EmailConfig.SmtpServer
            Port       = [int]$EmailConfig.Port
            From       = $EmailConfig.From
            To         = $EmailConfig.To
            Subject    = "LicenseGuard v$LGVersion - $env:COMPUTERNAME - $(Get-Date -Format 'yyyy-MM-dd')"
            Body       = $Summary
            UseSsl     = [bool]$EmailConfig.UseSsl
        }
        if ((Test-Path $ReportPath) -and -not $ConsoleOnly) { $params.Attachments = $ReportPath }
        if ($EmailConfig.Credential -and $EmailConfig.Credential.User) {
            $pw = ConvertTo-SecureString $EmailConfig.Credential.Password -AsPlainText -Force
            $params.Credential = New-Object System.Management.Automation.PSCredential($EmailConfig.Credential.User,$pw)
        }
        Send-MailMessage @params
        Write-Host "  Email gonderildi: $($EmailConfig.To -join ', ')" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Email gonderilemedi: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ─────────────────────────────────────────────
#  YENI MODUL FONKSİYONLARI
# ─────────────────────────────────────────────

function Send-WebhookNotification {
    param([object]$WebhookConfig, [string]$Title, [string]$Summary, [string]$Color = "FF0000")
    if (-not $WebhookConfig) { return }
    # Teams
    if ($WebhookConfig.Teams) {
        try {
            $payload = [PSCustomObject]@{
                "@type"    = "MessageCard"
                "@context" = "http://schema.org/extensions"
                themeColor = $Color
                summary    = $Title
                title      = "LicenseGuard v$LGVersion - $Title"
                text       = $Summary
            } | ConvertTo-Json -Depth 4
            Invoke-RestMethod -Uri $WebhookConfig.Teams -Method POST -Body $payload -ContentType "application/json" -TimeoutSec 10
            Write-Host "  Teams bildirimi gonderildi." -ForegroundColor Green
        } catch { Write-Host "  [WARN] Teams webhook: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
    # Slack
    if ($WebhookConfig.Slack) {
        try {
            $emoji = if ($Color -eq "FF0000") { ":red_circle:" } elseif ($Color -eq "FFA500") { ":warning:" } else { ":white_check_mark:" }
            $payload = [PSCustomObject]@{ text = "$emoji *LicenseGuard - $Title*`n$Summary" } | ConvertTo-Json
            Invoke-RestMethod -Uri $WebhookConfig.Slack -Method POST -Body $payload -ContentType "application/json" -TimeoutSec 10
            Write-Host "  Slack bildirimi gonderildi." -ForegroundColor Green
        } catch { Write-Host "  [WARN] Slack webhook: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
}

function Export-SarifReport {
    param([array]$PolicyFindings, [string]$SarifPath)
    try {
        $rules = @(); $results = @(); $seen = @{}
        foreach ($f in ($PolicyFindings | Where-Object { $_.PolicyStatus -ne "ALLOWED" })) {
            $rid = if ($f.RuleId -and $f.RuleId -ne "N/A") { $f.RuleId } else { "LG-POLICY" }
            if (-not $seen.ContainsKey($rid)) {
                $seen[$rid] = $true
                $rules += [PSCustomObject]@{
                    id               = $rid
                    name             = "LicensePolicy_$rid"
                    shortDescription = [PSCustomObject]@{ text = $f.Detail }
                    properties       = [PSCustomObject]@{ category = $f.Category; severity = $f.Severity }
                }
            }
            $level = switch ($f.PolicyStatus) { "PROHIBITED" { "error" } "REQUIRES_LICENSE" { "warning" } default { "note" } }
            $results += [PSCustomObject]@{
                ruleId    = $rid
                level     = $level
                message   = [PSCustomObject]@{ text = "$($f.Name): $($f.Detail)" }
                locations = @([PSCustomObject]@{ logicalLocations = @([PSCustomObject]@{ name = $env:COMPUTERNAME; kind = "machine" }) })
            }
        }
        [PSCustomObject]@{
            "`$schema" = "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json"
            version    = "2.1.0"
            runs       = @([PSCustomObject]@{
                tool    = [PSCustomObject]@{ driver = [PSCustomObject]@{ name="LicenseGuard"; version=$LGVersion; rules=$rules } }
                results = $results
            })
        } | ConvertTo-Json -Depth 10 | Out-File $SarifPath -Encoding UTF8
        Write-Host "  $($L["sarifSaved"]) $SarifPath" -ForegroundColor Cyan
    } catch { Write-Host "  [WARN] SARIF: $($_.Exception.Message)" -ForegroundColor Yellow }
}

function Get-BrowserExtensionAudit {
    Write-Header $L["hdrBrowser"]
    $rows = @()
    $browsers = @(
        [PSCustomObject]@{ Tag="Chrome"; Path="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Extensions" }
        [PSCustomObject]@{ Tag="Edge";   Path="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Extensions" }
    )
    foreach ($br in $browsers) {
        if (-not (Test-Path $br.Path)) { continue }
        Get-ChildItem $br.Path -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $mf = Get-ChildItem $_.FullName -Filter "manifest.json" -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($mf) {
                try {
                    $m    = Get-Content $mf.FullName -Raw | ConvertFrom-Json
                    $name = $m.name
                    if ($name -like "__MSG_*") {
                        $key = $name -replace "^__MSG_|__$",""
                        foreach ($loc in @("en_US","en","tr")) {
                            $lf = Join-Path (Split-Path $mf.FullName) "_locales\$loc\messages.json"
                            if (Test-Path $lf) {
                                $msgs = Get-Content $lf -Raw | ConvertFrom-Json
                                if ($msgs.$key -and $msgs.$key.message) { $name = $msgs.$key.message; break }
                            }
                        }
                        if ($name -like "__MSG_*") { $name = $_.Name }
                    }
                    Write-Status "[$($br.Tag)] $name" "v$($m.version)" "OK"
                    $rows += @{ Module="BrowserExt"; Name=$name; Status="OK"; Detail="[$($br.Tag)] v$($m.version)" }
                } catch {}
            }
        }
    }
    # Firefox
    $ffBase = "$env:APPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path $ffBase) {
        Get-ChildItem $ffBase -Directory | Where-Object { $_.Name -match "\.default" } | ForEach-Object {
            $extFile = Join-Path $_.FullName "extensions.json"
            if (Test-Path $extFile) {
                try {
                    $exts = (Get-Content $extFile -Raw | ConvertFrom-Json).addons |
                        Where-Object { $_.type -eq "extension" -and $_.location -ne "app-builtin" }
                    foreach ($ext in $exts) {
                        $name = if ($ext.defaultLocale -and $ext.defaultLocale.name) { $ext.defaultLocale.name } else { $ext.id }
                        Write-Status "[Firefox] $name" "v$($ext.version)" "OK"
                        $rows += @{ Module="BrowserExt"; Name=$name; Status="OK"; Detail="[Firefox] v$($ext.version)" }
                    }
                } catch {}
            }
        }
    }
    if ($rows.Count -eq 0) { Write-Status "Tarayici" "Eklenti bulunamadi" "OK" }
    return $rows
}

function Get-VsCodeExtensionAudit {
    Write-Header $L["hdrVsCode"]
    $rows = @()
    $extPath = "$env:USERPROFILE\.vscode\extensions"
    if (-not (Test-Path $extPath)) {
        Write-Status "VS Code" "Eklenti klasoru bulunamadi" "OK"
        return $rows
    }
    Get-ChildItem $extPath -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $pkg = Join-Path $_.FullName "package.json"
        if (Test-Path $pkg) {
            try {
                $p    = Get-Content $pkg -Raw | ConvertFrom-Json
                $name = if ($p.displayName) { $p.displayName } else { $p.name }
                Write-Status $name "v$($p.version) - $($p.publisher)" "OK"
                $rows += @{ Module="VSCodeExt"; Name=$name; Status="OK"; Detail="$($p.publisher) v$($p.version)" }
            } catch {
                $rows += @{ Module="VSCodeExt"; Name=$_.Name; Status="OK"; Detail="-" }
            }
        }
    }
    if ($rows.Count -eq 0) { Write-Status "VS Code" "Eklenti bulunamadi" "OK" }
    return $rows
}

function Get-StartupAudit {
    Write-Header $L["hdrStartup"]
    $rows = @()
    $regEntries = @(
        [PSCustomObject]@{ Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run";     Scope="HKLM" }
        [PSCustomObject]@{ Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"; Scope="HKLM-Once" }
        [PSCustomObject]@{ Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run";     Scope="HKCU" }
        [PSCustomObject]@{ Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"; Scope="HKCU-Once" }
    )
    foreach ($entry in $regEntries) {
        if (-not (Test-Path $entry.Path)) { continue }
        Get-ItemProperty $entry.Path | ForEach-Object {
            $_.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
                Write-Status $_.Name "[$($entry.Scope)]" "OK"
                $rows += @{ Module="Startup"; Name=$_.Name; Status="OK"; Detail="[$($entry.Scope)] $($_.Value)" }
            }
        }
    }
    foreach ($folder in @(
        [PSCustomObject]@{ Path=[Environment]::GetFolderPath("Startup");       Scope="User" }
        [PSCustomObject]@{ Path=[Environment]::GetFolderPath("CommonStartup"); Scope="AllUsers" }
    )) {
        if (Test-Path $folder.Path) {
            Get-ChildItem $folder.Path -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -in @(".lnk",".exe",".bat",".cmd",".vbs") } |
                ForEach-Object {
                    Write-Status $_.BaseName "[Folder-$($folder.Scope)]" "OK"
                    $rows += @{ Module="Startup"; Name=$_.BaseName; Status="OK"; Detail="[Folder-$($folder.Scope)] $($_.FullName)" }
                }
        }
    }
    if ($rows.Count -eq 0) { Write-Status "Baslangi" "Kayit bulunamadi" "OK" }
    return $rows
}

function Get-RunningProhibitedProcesses {
    param([array]$PolicyFindings)
    Write-Header $L["hdrProcess"]
    $prohibited = @($PolicyFindings | Where-Object { $_.PolicyStatus -eq "PROHIBITED" })
    if (-not $prohibited) { Write-Status "Process taramasi" "Yasak yazilim tanimli degil" "OK"; return @() }
    $procs = @(Get-Process | ForEach-Object { $_.ProcessName.ToLower() })
    $rows = @(); $found = 0
    foreach ($p in $prohibited) {
        $words = $p.Name.ToLower() -split '[\s\-_\(\)]+' | Where-Object { $_.Length -gt 3 }
        $active = $words | Where-Object { $procs -contains $_ }
        if ($active) {
            Write-Status $p.Name "AKTIF: $($active -join ', ')" "EXPIRED"
            $rows += @{ Module="Process"; Name=$p.Name; Status="EXPIRED"; Detail="YASAK YAZILIM AKTIF: $($active -join ', ')" }
            $found++
        }
    }
    if ($found -eq 0) { Write-Status "Process taramasi" "Yasak yazilim calismıyor" "OK" }
    return $rows
}

function Get-SignatureAudit {
    param([array]$PolicyFindings)
    Write-Header $L["hdrSignature"]
    $toCheck = @($PolicyFindings | Where-Object { $_.PolicyStatus -in @("PROHIBITED","REQUIRES_LICENSE") })
    if (-not $toCheck) { Write-Status "Imza kontrolu" "Kontrol edilecek yazilim yok" "OK"; return @() }
    $rows = @()
    foreach ($sw in $toCheck) {
        $keyword = ($sw.Name -split '[\s\-_]+')[0]
        $exe = Get-ChildItem "C:\Program Files","C:\Program Files (x86)" -Filter "$keyword*.exe" -Recurse -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($exe) {
            $sig    = Get-AuthenticodeSignature $exe.FullName
            $status = switch ($sig.Status) { "Valid" { "OK" } "NotSigned" { "WARN" } default { "EXPIRED" } }
            $subj   = if ($sig.SignerCertificate) { ($sig.SignerCertificate.Subject -replace "CN=","").Split(',')[0] } else { "Imzasiz" }
            Write-Status $sw.Name "$($sig.Status) - $subj" $status
            $rows  += @{ Module="Signature"; Name=$sw.Name; Status=$status; Detail="$($sig.Status): $subj" }
        } else {
            $rows += @{ Module="Signature"; Name=$sw.Name; Status="WARN"; Detail="Exe bulunamadi" }
        }
    }
    return $rows
}

function Get-UpdateStatus {
    try {
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/mustafasercansak/LicenseGuard/releases/latest" -TimeoutSec 5 -UseBasicParsing
        $latest = $rel.tag_name.TrimStart('v')
        if ($latest -and $latest -ne $LGVersion) {
            Write-Host "  [UPDATE] $($L["updateAvail"]): v$latest (mevcut: v$LGVersion)" -ForegroundColor Yellow
        } else {
            Write-Host "  $($L["updateCurrent"]): v$LGVersion" -ForegroundColor DarkGray
        }
    } catch {}
}

function New-JiraIssues {
    param([object]$JiraConfig, [array]$PolicyFindings)
    if (-not $JiraConfig -or -not $JiraConfig.BaseUrl) {
        Write-Host "  [WARN] Jira konfig (lg-config.json -> Jira) bulunamadi." -ForegroundColor Yellow
        return
    }
    $violations = @($PolicyFindings | Where-Object { $_.PolicyStatus -in @("PROHIBITED","REQUIRES_LICENSE") })
    if (-not $violations) { Write-Host "  Jira: Raporlanacak ihlal yok." -ForegroundColor DarkGray; return }
    $auth    = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($JiraConfig.User):$($JiraConfig.Token)"))
    $headers = @{ Authorization="Basic $auth"; "Content-Type"="application/json" }
    $created = 0
    foreach ($v in $violations) {
        try {
            $pri  = if ($v.PolicyStatus -eq "PROHIBITED") { "High" } else { "Medium" }
            $body = [PSCustomObject]@{
                fields = [PSCustomObject]@{
                    project     = [PSCustomObject]@{ key = $JiraConfig.ProjectKey }
                    summary     = "[LicenseGuard] $($v.Name) - $($v.PolicyStatus)"
                    description = "$($v.Detail)`n`nMakine: $env:COMPUTERNAME`nKategori: $($v.Category)`nAlternatif: $($v.Alternative)"
                    issuetype   = [PSCustomObject]@{ name = "Bug" }
                    priority    = [PSCustomObject]@{ name = $pri }
                }
            } | ConvertTo-Json -Depth 5
            $resp = Invoke-RestMethod -Uri "$($JiraConfig.BaseUrl)/rest/api/2/issue" -Method POST -Body $body -Headers $headers -TimeoutSec 15
            Write-Host "  Jira ticket: $($resp.key)" -ForegroundColor Green
            $created++
        } catch { Write-Host "  [WARN] Jira ($($v.Name)): $($_.Exception.Message)" -ForegroundColor Yellow }
    }
    if ($created -gt 0) { Write-Host "  $created Jira ticket olusturuldu." -ForegroundColor Green }
}

# ─────────────────────────────────────────────
#  MODUL 1: WINDOWS AKTIVASYON
# ─────────────────────────────────────────────
function Get-WindowsActivation {
    param([string]$Computer = "")
    Write-Header ($L["hdrWinAct"] + $(if ($Computer) { " [$Computer]" } else { "" }))
    $products = $null
    try {
        $cimParams = @{ Query = "SELECT Name, LicenseStatus, Description, GracePeriodRemaining FROM SoftwareLicensingProduct WHERE PartialProductKey IS NOT NULL AND ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f'" }
        if ($Computer) { $cimParams.ComputerName = $Computer }
        $products = Get-CimInstance @cimParams
    } catch {
        Write-Status "Windows Lisans" "Okunamadi" "ERROR"
        return @{ Module="WindowsActivation"; Name="Windows Aktivasyon"; Status="ERROR"; Detail="WMI sorgusu basarisiz" }
    }
    if (-not $products) {
        Write-Status "Windows Lisans" "Okunamadi" "ERROR"
        return @{ Module="WindowsActivation"; Name="Windows Aktivasyon"; Status="ERROR"; Detail="WMI sorgusu basarisiz" }
    }
    $row = $products | Sort-Object LicenseStatus | Select-Object -First 1
    $statusMap = @{
        0=@("Unlicensed","EXPIRED"); 1=@("Licensed","OK"); 2=@("OOBGrace","WARN")
        3=@("OOTGrace","WARN"); 4=@("NonGenuineGrace","WARN"); 5=@("Notification","WARN"); 6=@("ExtendedGrace","WARN")
    }
    $ls     = [int]$row.LicenseStatus
    $mapped = if ($statusMap.ContainsKey($ls)) { $statusMap[$ls] } else { @("Bilinmiyor","WARN") }
    $detail = if ($row.GracePeriodRemaining -gt 0) {
        "$($mapped[0]) -- Kalan sure: $([math]::Round($row.GracePeriodRemaining/1440,1)) gun"
    } else { $mapped[0] }
    Write-Status "Windows Aktivasyon" $detail $mapped[1]
    $name = if ($Computer) { "[$Computer] Windows Aktivasyon" } else { "Windows Aktivasyon" }
    return @{ Module="WindowsActivation"; Name=$name; Status=$mapped[1]; Detail=$detail }
}

# ─────────────────────────────────────────────
#  MODUL 2: KURULU YAZILIM ENVANTERI
# ─────────────────────────────────────────────
function Get-InstalledSoftwareAudit {
    param([array]$Cache = $null, [string]$Computer = "")
    Write-Header ($L["hdrSoftware"] + $(if ($Computer) { " [$Computer]" } else { "" }))
    $rows = if ($Cache) { $Cache } else { Get-InstalledSoftwareCache -Computer $Computer }
    Write-Host ("  {0} yazilim bulundu." -f $rows.Count) -ForegroundColor DarkGray
    $expired = $rows | Where-Object { $_.Status -eq "EXPIRED" }
    $warning = $rows | Where-Object { $_.Status -eq "WARN" }
    if ($expired) {
        Write-Host "`n  Suresi Dolmus:" -ForegroundColor Red
        $expired | ForEach-Object { Write-Status $_.Name $_.ExpireInfo "EXPIRED" }
    }
    if ($warning) {
        Write-Host "`n  Uyari (${warnDays} gun icinde bitiyor):" -ForegroundColor Yellow
        $warning | ForEach-Object { Write-Status $_.Name $_.ExpireInfo "WARN" }
    }
    if (-not $expired -and -not $warning) { Write-Status "Tum yazilimlar" "Expire kaydi yok / sorun yok" "OK" }
    $prefix = if ($Computer) { "[$Computer] " } else { "" }
    return $rows | ForEach-Object {
        @{ Module="Software"; Name="$prefix$($_.Name)"; Version=$_.Version; Publisher=$_.Publisher;
           Status=$_.Status; Detail=$_.ExpireInfo; InstallDate=$_.InstallDate }
    }
}

# ─────────────────────────────────────────────
#  MODUL 3: FLEXLM LISANS SUNUCUSU
# ─────────────────────────────────────────────
function Get-FlexLMStatus {
    Write-Header $L["hdrFlexLM"]
    if ($config.FlexLM.Count -eq 0) {
        Write-Host "  Konfigurasyonda FlexLM girisi yok. lg-config.json dosyasina ekleyin." -ForegroundColor DarkGray
        return @()
    }
    $lmutil = Get-Command "lmutil.exe" -ErrorAction SilentlyContinue
    if (-not $lmutil) {
        $candidates = @(
            "C:\Program Files\FLEXlm\lmutil.exe",
            "C:\Program Files\Flexera Software\FlexNet Publisher\lmutil.exe",
            "C:\Program Files (x86)\Common Files\Macrovision Shared\FLEXnet Publisher\lmutil.exe"
        )
        foreach ($c in $candidates) { if (Test-Path $c) { $lmutil = $c; break } }
    }
    $rows = @()
    foreach ($entry in $config.FlexLM) {
        $name = $entry.Name; $server = $entry.Server
        if (-not $lmutil) {
            Write-Status $name "lmutil.exe bulunamadi" "ERROR"
            $rows += @{ Module="FlexLM"; Name=$name; Server=$server; Status="ERROR"; Detail="lmutil.exe bulunamadi" }
            continue
        }
        try {
            $output = & $lmutil lmstat -a -c $server 2>&1 | Out-String
            if ($output -match "license server UP") {
                $used = ([regex]::Matches($output,"in use")).Count
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
    Write-Header $L["hdrSaaS"]
    if ($config.SaaS.Count -eq 0) {
        Write-Host "  Konfigurasyonda SaaS girisi yok. lg-config.json dosyasina ekleyin." -ForegroundColor DarkGray
        return @()
    }
    $rows = @()
    foreach ($svc in $config.SaaS) {
        $name = $svc.Name; $endpoint = $svc.Endpoint; $header = $svc.Header; $key = $svc.Key
        $expect = if ($svc.ExpectStatus) { [int]$svc.ExpectStatus } else { 200 }
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
    param([string]$PolicyPath = ".\lg-policy.json", [array]$SoftwareRows = $null)
    Write-Header $L["policySection"]
    if (-not (Test-Path $PolicyPath)) {
        Write-Host "  [WARN] Policy dosyasi bulunamadi: $PolicyPath" -ForegroundColor Yellow
        return @()
    }
    try {
        $policy = Get-Content $PolicyPath -Raw | ConvertFrom-Json
    } catch {
        Write-Host "  [WARN] Policy okunamadi: $($_.Exception.Message)" -ForegroundColor Yellow
        return @()
    }
    $swRows = if ($SoftwareRows) {
        $SoftwareRows | ForEach-Object { [PSCustomObject]@{ Name=$_.Name; Version=$_.Version; Publisher=$_.Publisher } }
    } else {
        Get-InstalledSoftwareCache | ForEach-Object { [PSCustomObject]@{ Name=$_.Name; Version=$_.Version; Publisher=$_.Publisher } }
    }
    $findings = @()
    foreach ($sw in $swRows) {
        # Whitelist kontrolu
        $whitelisted = $false
        if ($config.Whitelist -and $config.Whitelist.Count -gt 0) {
            foreach ($wl in $config.Whitelist) {
                if ($sw.Name -like "*$wl*") { $whitelisted = $true; break }
            }
        }
        if ($whitelisted) {
            $findings += @{
                Module="PolicyCheck"; RuleId="WL"; Category="Whitelist"
                Name=$sw.Name; Version=$sw.Version; Publisher=$sw.Publisher
                PolicyStatus="ALLOWED"; Status="OK"; Detail=$L["whitelist"]
                Alternative=""; Reference=""; Severity="LOW"
            }
            continue
        }
        # Politika kural eslemesi
        $matched = $false
        foreach ($rule in $policy.rules) {
            $match = $false
            switch ($rule.matchType) {
                "contains"   { if ($sw.Name -like "*$($rule.pattern)*") { $match = $true } }
                "startsWith" { if ($sw.Name -like "$($rule.pattern)*")  { $match = $true } }
                "exact"      { if ($sw.Name -eq $rule.pattern)           { $match = $true } }
                "regex"      { if ($sw.Name -match $rule.pattern)        { $match = $true } }
            }
            if ($match) {
                $statusMap = @{ "PROHIBITED"="EXPIRED"; "REQUIRES_LICENSE"="WARN"; "ALLOWED"="OK" }
                $severity  = if ($null -ne $rule.severity) { $rule.severity } else {
                    switch ($rule.status) { "PROHIBITED" { "HIGH" } "REQUIRES_LICENSE" { "MEDIUM" } default { "LOW" } }
                }
                $alt = if ($null -ne $rule.alternative)  { $rule.alternative  } else { "" }
                $ref = if ($null -ne $rule.referenceUrl) { $rule.referenceUrl } else { "" }
                $findings += @{
                    Module="PolicyCheck"; RuleId=$rule.id; Category=$rule.category
                    Name=$sw.Name; Version=$sw.Version; Publisher=$sw.Publisher
                    PolicyStatus=$rule.status; Status=$statusMap[$rule.status]; Detail=$rule.reason
                    Alternative=$alt; Reference=$ref; Severity=$severity
                }
                $matched = $true; break
            }
        }
        if (-not $matched) {
            $findings += @{
                Module="PolicyCheck"; RuleId="N/A"; Category="N/A"
                Name=$sw.Name; Version=$sw.Version; Publisher=$sw.Publisher
                PolicyStatus="ALLOWED"; Status="OK"; Detail=$L["noRule"]
                Alternative=""; Reference=""; Severity="LOW"
            }
        }
    }
    $proh = @($findings | Where-Object { $_.PolicyStatus -eq "PROHIBITED" })
    $lic  = @($findings | Where-Object { $_.PolicyStatus -eq "REQUIRES_LICENSE" })
    $ok   = @($findings | Where-Object { $_.PolicyStatus -eq "ALLOWED" })
    foreach ($f in $findings) {
        $suffix = if ($f.RuleId -ne "N/A" -and $f.RuleId -ne "WL") { " [$($f.RuleId)]" } else { "" }
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
    param(
        [array]$AllResults,
        [array]$PolicyFindings,
        [object]$Delta        = $null,
        [string]$BrandColor   = "#3b82f6",
        [string]$BrandCompany = ""
    )

    $ts       = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $hostname = $env:COMPUTERNAME

    $total     = if ($AllResults.Count -gt 0) { $AllResults.Count } else { 1 }
    $okCount   = @($AllResults | Where-Object { $_.Status -eq "OK"                 }).Count
    $warnCount = @($AllResults | Where-Object { $_.Status -eq "WARN"               }).Count
    $expCount  = @($AllResults | Where-Object { $_.Status -in @("EXPIRED","ERROR") }).Count
    $okPct     = [math]::Round($okCount   / $total * 100)
    $warnPct   = [math]::Round($warnCount / $total * 100)
    $expPct    = [math]::Round($expCount  / $total * 100)

    # Lisans tablosu satirlari
    $tableRows = ($AllResults | ForEach-Object {
        $bc   = switch ($_.Status) { "OK" { "ok" } "WARN" { "warn" } default { "expired" } }
        $trTx = switch ($_.Status) { "OK" { "UYUMLU" } "WARN" { "UYARI" } "EXPIRED" { "SURESI DOLDU" } default { "HATA" } }
        $enTx = switch ($_.Status) { "OK" { "OK" } "WARN" { "WARNING" } "EXPIRED" { "EXPIRED" } default { "ERROR" } }
        $det  = if ($_.Detail) { Encode-Html $_.Detail } else { "&mdash;" }
        "<tr data-status='$($_.Status)'><td><span class='mod-pill' data-mod='$($_.Module)'>$($_.Module)</span></td><td>$(Encode-Html $_.Name)</td><td>$det</td><td><span class='badge $bc' data-val-tr='$trTx' data-val-en='$enTx'>$trTx</span></td></tr>"
    }) -join "`n"

    # Policy tablosu
    $prohibCount=0; $licCount=0; $allowedCount=0; $prohibPct=0; $licPct=0; $allowedPct=0; $policyRows=""
    if ($PolicyFindings -and $PolicyFindings.Count -gt 0) {
        $pTotal       = $PolicyFindings.Count
        $prohibCount  = @($PolicyFindings | Where-Object { $_.PolicyStatus -eq "PROHIBITED"       }).Count
        $licCount     = @($PolicyFindings | Where-Object { $_.PolicyStatus -eq "REQUIRES_LICENSE" }).Count
        $allowedCount = @($PolicyFindings | Where-Object { $_.PolicyStatus -eq "ALLOWED"          }).Count
        $prohibPct    = [math]::Round($prohibCount  / $pTotal * 100)
        $licPct       = [math]::Round($licCount     / $pTotal * 100)
        $allowedPct   = [math]::Round($allowedCount / $pTotal * 100)
        $policyRows   = ($PolicyFindings | ForEach-Object {
            $bc     = switch ($_.PolicyStatus) { "PROHIBITED" { "expired" } "REQUIRES_LICENSE" { "warn" } default { "ok" } }
            $lblTr  = switch ($_.PolicyStatus) { "PROHIBITED" { "YASAK" } "REQUIRES_LICENSE" { "LISANS GEREKLI" } default { "UYUMLU" } }
            $lblEn  = switch ($_.PolicyStatus) { "PROHIBITED" { "PROHIBITED" } "REQUIRES_LICENSE" { "REQUIRES LICENSE" } default { "COMPLIANT" } }
            $sevCls = switch ($_.Severity) { "CRITICAL" { "critical" } "HIGH" { "high" } "MEDIUM" { "medium" } default { "low" } }
            $sevPill= if ($_.PolicyStatus -ne "ALLOWED" -and $_.Severity) { "<span class='sev-pill $sevCls'>$($_.Severity)</span>" } else { "" }
            $alt    = if ($_.Alternative) { "<br><small class='suggestion'>&#x1F4A1; $(Encode-Html $_.Alternative)</small>" } else { "" }
            $ref    = if ($_.Reference)   { " <a href='$(Encode-Html $_.Reference)' target='_blank' class='reflink'>&#x2197;</a>" } else { "" }
            "<tr data-policy='$($_.PolicyStatus)'><td>$(Encode-Html $_.Category)$sevPill</td><td><span class='sw-name'>$(Encode-Html $_.Name)</span><br><small class='sw-meta'>$(Encode-Html $_.Version) &middot; $(Encode-Html $_.Publisher)</small></td><td>$(Encode-Html $_.Detail)$alt$ref</td><td><span class='badge $bc' data-val-tr='$lblTr' data-val-en='$lblEn'>$lblTr</span></td></tr>"
        }) -join "`n"
    }

    # Takvim verisi (JSON)
    $calToday = Get-Date; $calParts = @()
    foreach ($r in $AllResults) {
        if ($r.Detail -and $r.Detail -match '(\d{4}-\d{2}-\d{2})') {
            $dateStr = $Matches[1]
            try {
                $expDate = [datetime]$dateStr
                $days    = [int]($expDate - $calToday).TotalDays
                $nm = ($r.Name -replace '\\','\\' -replace '"','\"')
                $md = ($r.Module -replace '"','\"')
                $st = ($r.Status -replace '"','\"')
                $calParts += "{`"name`":`"$nm`",`"module`":`"$md`",`"date`":`"$dateStr`",`"days`":$days,`"status`":`"$st`"}"
            } catch {}
        }
    }
    $calJson = "[" + ($calParts -join ",") + "]"

    # Delta kutusu HTML
    $deltaBoxHtml = ""
    if ($Delta) {
        $ni  = if ($Delta.NewIssues)          { @($Delta.NewIssues).Count }          else { 0 }
        $ri  = if ($Delta.ResolvedIssues)     { @($Delta.ResolvedIssues).Count }     else { 0 }
        $nv  = if ($Delta.NewViolations)      { @($Delta.NewViolations).Count }      else { 0 }
        $rv  = if ($Delta.ResolvedViolations) { @($Delta.ResolvedViolations).Count } else { 0 }
        if (($ni + $ri + $nv + $rv) -gt 0) {
            $dParts = @()
            if ($ni -gt 0) { $dParts += "<span class='delta-new'>&#x25B2; $ni $($L["deltaNew"])</span>" }
            if ($ri -gt 0) { $dParts += "<span class='delta-ok'>&#x25BC; $ri $($L["deltaResolved"])</span>" }
            if ($nv -gt 0) { $dParts += "<span class='delta-new'>&#x25B2; $nv policy $($L["deltaNew"])</span>" }
            if ($rv -gt 0) { $dParts += "<span class='delta-ok'>&#x25BC; $rv policy $($L["deltaResolved"])</span>" }
            $deltaBoxHtml = "<div class='delta-box'><span class='delta-lbl'>$($L["deltaTitle"])</span> &mdash; $($L["deltaSince"]) <b>$($Delta.PreviousTimestamp)</b> &nbsp; $($dParts -join " &middot; ")</div>"
        }
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
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
:root{
  --bg:#080d18;--sf:#0f1623;--sf2:#161e2e;--sf3:#1c2740;
  --bd:#1e293b;--bd2:#263347;
  --tx:#e2e8f0;--tx2:#94a3b8;--tx3:#475569;
  --blue:$BrandColor;--green:#22c55e;--yellow:#f59e0b;--red:#ef4444;
  --r:10px;
}
html{scroll-behavior:smooth}
body{font-family:'Segoe UI',system-ui,sans-serif;background:var(--bg);color:var(--tx);height:100vh;overflow:hidden;font-size:14px;line-height:1.5}

/* HEADER */
.hdr{position:sticky;top:0;z-index:200;background:rgba(8,13,24,.9);backdrop-filter:blur(12px);-webkit-backdrop-filter:blur(12px);border-bottom:1px solid var(--bd);padding:0 1.5rem;display:flex;align-items:center;height:54px;gap:1rem}
.hdr-brand{display:flex;align-items:center;gap:.55rem;flex:1}
.hdr-brand h1{font-size:.95rem;font-weight:700;color:var(--tx);letter-spacing:-.01em}
.hdr-brand h1 span{color:var(--blue)}
.hdr-meta{font-size:.72rem;color:var(--tx3);white-space:nowrap}
.hdr-meta b{color:var(--tx2)}
.btn-lang{background:var(--sf2);border:1px solid var(--bd2);color:var(--tx2);padding:.28rem .7rem;border-radius:6px;cursor:pointer;font-size:.7rem;font-weight:700;letter-spacing:.06em;transition:all .15s}
.btn-lang:hover{background:var(--sf3);border-color:var(--blue);color:var(--blue)}

/* LAYOUT */
.layout{display:flex;height:calc(100vh - 54px);overflow:hidden}
.sidebar{width:210px;flex-shrink:0;background:var(--sf);border-right:1px solid var(--bd);padding:1.25rem 0;position:sticky;top:54px;height:calc(100vh - 54px);overflow-y:auto}
.main{flex:1;min-width:0;padding:1.75rem;height:calc(100vh - 54px);overflow:hidden;display:flex;flex-direction:column}

/* SIDEBAR */
.nav-sec{padding:0 1rem .4rem;font-size:.62rem;font-weight:700;color:var(--tx3);text-transform:uppercase;letter-spacing:.1em;margin-top:.75rem}
.nav-item{display:flex;align-items:center;gap:.6rem;padding:.5rem .9rem;margin:.08rem .6rem;border-radius:8px;cursor:pointer;font-size:.8rem;color:var(--tx2);transition:all .15s;user-select:none;border:1px solid transparent}
.nav-item:hover{background:var(--sf2);color:var(--tx)}
.nav-item.active{background:rgba(59,130,246,.12);color:var(--blue);border-color:rgba(59,130,246,.2);font-weight:600}
.nav-icon{font-size:.95rem;width:18px;text-align:center;flex-shrink:0}
.nav-badge{margin-left:auto;font-size:.62rem;font-weight:700;padding:.08rem .42rem;border-radius:20px;background:var(--sf3);color:var(--tx3)}
.nav-badge.red{background:rgba(239,68,68,.15);color:var(--red)}
.nav-badge.yellow{background:rgba(245,158,11,.15);color:var(--yellow)}
.nav-badge.green{background:rgba(34,197,94,.15);color:var(--green)}
.nav-divider{height:1px;background:var(--bd);margin:.9rem .6rem}

/* HEALTH SCORE */
.health-box{margin:.25rem .6rem 1rem;background:var(--sf2);border:1px solid var(--bd2);border-radius:var(--r);padding:.9rem;text-align:center}
.health-lbl{font-size:.62rem;color:var(--tx3);text-transform:uppercase;letter-spacing:.07em;margin-bottom:.6rem}
.donut-wrap{position:relative;width:76px;height:76px;margin:0 auto .6rem}
.donut-wrap svg{width:76px;height:76px}
.donut-inner{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center}
.donut-pct{font-size:1.05rem;font-weight:700}
.donut-sub{font-size:.58rem;color:var(--tx3);text-transform:uppercase;letter-spacing:.05em}

/* TABS */
.tab-pane{display:none}.tab-pane.active{display:flex;flex-direction:column;flex:1;min-height:0;overflow:hidden}

/* SECTION HEAD */
.sec-head{display:flex;align-items:center;gap:.65rem;margin-bottom:1.1rem;flex-shrink:0}
.sec-head h2{font-size:.95rem;font-weight:600;color:var(--tx)}
.sec-icon{font-size:1rem}

/* STAT CARDS */
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

/* TOOLBAR */
.toolbar{display:flex;gap:.6rem;align-items:center;margin-bottom:.7rem;flex-wrap:wrap;flex-shrink:0}
.search-wrap{position:relative;flex:1;min-width:180px;max-width:380px}
.search-ico{position:absolute;left:.6rem;top:50%;transform:translateY(-50%);width:13px;height:13px;fill:var(--tx3);pointer-events:none}
.search-input{width:100%;background:var(--sf);border:1px solid var(--bd2);color:var(--tx);padding:.42rem .7rem .42rem 1.9rem;border-radius:8px;font-size:.82rem;outline:none;transition:border-color .15s,box-shadow .15s}
.search-input:focus{border-color:var(--blue);box-shadow:0 0 0 3px rgba(59,130,246,.12)}
.search-input::placeholder{color:var(--tx3)}
.filter-chip{display:flex;align-items:center;gap:.38rem;padding:.4rem .7rem;background:var(--sf);border:1px solid var(--bd2);border-radius:8px;font-size:.76rem;color:var(--tx2);cursor:pointer;user-select:none;transition:all .15s;white-space:nowrap}
.filter-chip:has(input:checked){background:rgba(59,130,246,.1);border-color:rgba(59,130,246,.3);color:var(--blue)}
.filter-chip input{accent-color:var(--blue);cursor:pointer}
.rc{font-size:.72rem;color:var(--tx3);margin-left:auto;white-space:nowrap}
.btn-exp{background:var(--sf);border:1px solid var(--bd2);color:var(--tx2);padding:.38rem .7rem;border-radius:8px;cursor:pointer;font-size:.73rem;transition:all .15s;white-space:nowrap}
.btn-exp:hover{background:var(--sf3);border-color:var(--blue);color:var(--blue)}

/* DELTA BOX */
.delta-box{background:rgba(59,130,246,.07);border:1px solid rgba(59,130,246,.2);border-radius:8px;padding:.55rem 1rem;margin-bottom:.8rem;font-size:.78rem;color:var(--tx2);flex-shrink:0}
.delta-lbl{font-weight:700;color:var(--blue)}
.delta-new{color:var(--red);font-weight:600}
.delta-ok{color:var(--green);font-weight:600}

/* TABLE */
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

/* Row accent */
tr[data-status="WARN"] td:first-child{border-left:3px solid var(--yellow);padding-left:calc(1rem - 3px)}
tr[data-status="EXPIRED"] td:first-child,tr[data-status="ERROR"] td:first-child{border-left:3px solid var(--red);padding-left:calc(1rem - 3px)}
tr[data-policy="PROHIBITED"] td:first-child{border-left:3px solid var(--red);padding-left:calc(1rem - 3px)}
tr[data-policy="REQUIRES_LICENSE"] td:first-child{border-left:3px solid var(--yellow);padding-left:calc(1rem - 3px)}

/* BADGES */
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

/* SEVERITY PILLS */
.sev-pill{display:inline-block;padding:.05rem .35rem;border-radius:3px;font-size:.58rem;font-weight:700;letter-spacing:.04em;margin-left:.4rem;vertical-align:middle}
.sev-pill.critical{background:rgba(239,68,68,.25);color:#fca5a5}
.sev-pill.high{background:rgba(239,68,68,.15);color:var(--red)}
.sev-pill.medium{background:rgba(245,158,11,.15);color:var(--yellow)}
.sev-pill.low{background:rgba(34,197,94,.08);color:#4ade80}

/* CALENDAR */
.cal-days{display:inline-block;font-size:.78rem;font-weight:600}
.cal-days.urgent{color:var(--red)}
.cal-days.warn{color:var(--yellow)}
.cal-days.ok{color:var(--green)}

footer{padding:.6rem 0;text-align:center;color:var(--tx3);font-size:.7rem;border-top:1px solid var(--bd);flex-shrink:0}

@media(max-width:768px){.sidebar{display:none}.main{padding:1rem}.hdr{padding:0 1rem}.hdr-meta{display:none}.stat-grid{grid-template-columns:repeat(3,1fr)}}

@media print{
  body{height:auto;overflow:visible}
  .layout{height:auto;overflow:visible}
  .main{height:auto;overflow:visible;padding:.5rem}
  .tab-pane{display:block!important;height:auto!important;overflow:visible!important;margin-bottom:2rem}
  .tab-pane:not(.active){display:none!important}
  .table-wrap{overflow:visible;height:auto;border:none}
  .sidebar,.toolbar,.hdr .btn-lang{display:none!important}
  .hdr{position:static;background:white;color:black;border-bottom:2px solid #333}
  .hdr-brand h1{color:#333}.hdr-brand h1 span{color:#1d4ed8}
  .hdr-meta{color:#555}
  footer{display:block;color:#555}
  table{font-size:.75rem}
  th,td{padding:.4rem .6rem}
  tr:hover td{background:none}
}
</style>
</head>
<body>

<header class="hdr">
  <div class="hdr-brand">
    <span style="font-size:1.15rem">&#x1F510;</span>
    <h1>License<span>Guard</span></h1>$(if ($BrandCompany) { "<span style='font-size:.72rem;color:var(--tx3);margin-left:.4rem'>&mdash; $(Encode-Html $BrandCompany)</span>" })
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
        <circle id="donut-ring" cx="38" cy="38" r="28" fill="none" stroke="#3b82f6"
          stroke-width="7" stroke-linecap="round" stroke-dasharray="0 175.9"
          transform="rotate(-90 38 38)" style="transition:stroke-dasharray .9s ease,stroke .4s ease"/>
      </svg>
      <div class="donut-inner">
        <span class="donut-pct" id="health-pct" style="color:#3b82f6">-</span>
        <span class="donut-sub">skor</span>
      </div>
    </div>
  </div>

  <div class="nav-sec" data-i18n="sections">Bolumler</div>
  <div class="nav-item active" onclick="switchTab('license',this)" id="nav-license">
    <span class="nav-icon">&#x1F4CA;</span>
    <span data-i18n="navLicense">Lisans Durumu</span>
    <span class="nav-badge" id="nb1"></span>
  </div>
  <div class="nav-item" onclick="switchTab('policy',this)" id="nav-policy">
    <span class="nav-icon">&#x1F6E1;&#xFE0F;</span>
    <span data-i18n="navPolicy">Uyumluluk</span>
    <span class="nav-badge" id="nb2"></span>
  </div>
  <div class="nav-item" onclick="switchTab('calendar',this)" id="nav-calendar">
    <span class="nav-icon">&#x1F4C5;</span>
    <span data-i18n="navCalendar">Takvim</span>
    <span class="nav-badge" id="nb-cal"></span>
  </div>

  <div class="nav-divider"></div>
  <div class="nav-sec" data-i18n="modules">Moduller</div>
  <div class="nav-item" onclick="filterMod(null,this)">
    <span class="nav-icon">&#x25A6;</span>
    <span data-i18n="allModules">Tumu</span>
  </div>
  <div class="nav-item" onclick="filterMod('WindowsActivation',this)">
    <span class="nav-icon">&#x1F5A5;&#xFE0F;</span>
    <span>Windows</span>
  </div>
  <div class="nav-item" onclick="filterMod('Software',this)">
    <span class="nav-icon">&#x1F4E6;</span>
    <span data-i18n="navSoftware">Yazilimlar</span>
  </div>
  <div class="nav-item" onclick="filterMod('EOL',this)">
    <span class="nav-icon">&#x23F1;</span>
    <span data-i18n="eolSection">EOL</span>
  </div>
  <div class="nav-item" onclick="filterMod('FlexLM',this)">
    <span class="nav-icon">&#x1F511;</span>
    <span>FlexLM</span>
  </div>
  <div class="nav-item" onclick="filterMod('SaaS',this)">
    <span class="nav-icon">&#x2601;&#xFE0F;</span>
    <span>SaaS / API</span>
  </div>
  <div class="nav-item" onclick="filterMod('BrowserExt',this)">
    <span class="nav-icon">&#x1F9E9;</span>
    <span data-i18n="navBrowserExt">Tarayici Eklentileri</span>
  </div>
  <div class="nav-item" onclick="filterMod('VSCodeExt',this)">
    <span class="nav-icon">&#x1F4BB;</span>
    <span data-i18n="navVsCode">VS Code</span>
  </div>
  <div class="nav-item" onclick="filterMod('Startup',this)">
    <span class="nav-icon">&#x1F680;</span>
    <span data-i18n="navStartup">Baslangic</span>
  </div>
  <div class="nav-item" onclick="filterMod('Process',this)">
    <span class="nav-icon">&#x26A1;</span>
    <span data-i18n="navProcess">Aktif Processler</span>
  </div>
  <div class="nav-item" onclick="filterMod('Signature',this)">
    <span class="nav-icon">&#x1F4DC;</span>
    <span data-i18n="navSignature">Imza</span>
  </div>
</nav>

<main class="main">

  <div class="tab-pane active" id="tab-license">
    <div class="sec-head">
      <span class="sec-icon">&#x1F4CA;</span>
      <h2 data-i18n="licenseSection">Lisans Durumu</h2>
    </div>
    <div class="stat-grid">
      <div class="sc ok">
        <div class="sc-ico">&#x2705;</div>
        <div class="sc-num" id="c1ok-n">-</div>
        <div class="sc-lbl" data-i18n="valid">Gecerli</div>
        <div class="sc-bar"><div class="sc-bar-fill" id="c1ok-b"></div></div>
        <div class="sc-pct" id="c1ok-p"></div>
      </div>
      <div class="sc warn">
        <div class="sc-ico">&#x26A0;&#xFE0F;</div>
        <div class="sc-num" id="c1wn-n">-</div>
        <div class="sc-lbl" data-i18n="warning">Uyari</div>
        <div class="sc-bar"><div class="sc-bar-fill" id="c1wn-b"></div></div>
        <div class="sc-pct" id="c1wn-p"></div>
      </div>
      <div class="sc exp">
        <div class="sc-ico">&#x274C;</div>
        <div class="sc-num" id="c1er-n">-</div>
        <div class="sc-lbl" data-i18n="errorExp">Hata / Dolmus</div>
        <div class="sc-bar"><div class="sc-bar-fill" id="c1er-b"></div></div>
        <div class="sc-pct" id="c1er-p"></div>
      </div>
    </div>
$deltaBoxHtml
    <div class="toolbar">
      <div class="search-wrap">
        <svg class="search-ico" viewBox="0 0 16 16"><path d="M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398h-.001l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85a1.007 1.007 0 0 0-.115-.099zM12 6.5a5.5 5.5 0 1 1-11 0 5.5 5.5 0 0 1 11 0z"/></svg>
        <input class="search-input" id="s1" data-table="t1" oninput="doFilter(this)" data-i18n-ph="searchPh" placeholder="Yazilim ara...">
      </div>
      <label class="filter-chip"><input type="checkbox" id="f1" data-table="t1" onchange="doFilterCb(this)"> <span data-i18n="issuesOnly">Sadece sorunlar</span></label>
      <button class="btn-exp" onclick="exportTableCsv('t1','lg-license.csv')" data-i18n="exportCsv">CSV Indir</button>
      <button class="btn-exp" onclick="exportTableJson('t1','lg-license.json')" data-i18n="exportJson">JSON Indir</button>
      <button class="btn-exp" onclick="window.print()" data-i18n="printPdf">PDF Yazdir</button>
      <span class="rc" id="rc1"></span>
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
  </div>

  <div class="tab-pane" id="tab-policy">
    <div class="sec-head">
      <span class="sec-icon">&#x1F6E1;&#xFE0F;</span>
      <h2 data-i18n="policySection">Kurumsal Lisans Uyumluluk</h2>
    </div>
    <div class="stat-grid">
      <div class="sc exp">
        <div class="sc-ico">&#x1F6AB;</div>
        <div class="sc-num" id="c2bn-n">-</div>
        <div class="sc-lbl" data-i18n="banned">Yasak</div>
        <div class="sc-bar"><div class="sc-bar-fill" id="c2bn-b"></div></div>
        <div class="sc-pct" id="c2bn-p"></div>
      </div>
      <div class="sc warn">
        <div class="sc-ico">&#x1F4CB;</div>
        <div class="sc-num" id="c2lc-n">-</div>
        <div class="sc-lbl" data-i18n="needsLic">Lisans Gerekli</div>
        <div class="sc-bar"><div class="sc-bar-fill" id="c2lc-b"></div></div>
        <div class="sc-pct" id="c2lc-p"></div>
      </div>
      <div class="sc ok">
        <div class="sc-ico">&#x2705;</div>
        <div class="sc-num" id="c2ok-n">-</div>
        <div class="sc-lbl" data-i18n="compliant">Uyumlu</div>
        <div class="sc-bar"><div class="sc-bar-fill" id="c2ok-b"></div></div>
        <div class="sc-pct" id="c2ok-p"></div>
      </div>
    </div>
    <div class="toolbar">
      <div class="search-wrap">
        <svg class="search-ico" viewBox="0 0 16 16"><path d="M11.742 10.344a6.5 6.5 0 1 0-1.397 1.398h-.001l3.85 3.85a1 1 0 0 0 1.415-1.414l-3.85-3.85a1.007 1.007 0 0 0-.115-.099zM12 6.5a5.5 5.5 0 1 1-11 0 5.5 5.5 0 0 1 11 0z"/></svg>
        <input class="search-input" id="s2" data-table="t2" oninput="doFilter(this)" data-i18n-ph="searchPh" placeholder="Yazilim ara...">
      </div>
      <label class="filter-chip"><input type="checkbox" id="f2" data-table="t2" onchange="doFilterCb(this)"> <span data-i18n="issuesOnly">Sadece sorunlar</span></label>
      <button class="btn-exp" onclick="exportTableCsv('t2','lg-policy.csv')" data-i18n="exportCsv">CSV Indir</button>
      <button class="btn-exp" onclick="exportTableJson('t2','lg-policy.json')" data-i18n="exportJson">JSON Indir</button>
      <span class="rc" id="rc2"></span>
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

  <div class="tab-pane" id="tab-calendar">
    <div class="sec-head">
      <span class="sec-icon">&#x1F4C5;</span>
      <h2 data-i18n="calSection">Lisans Takvimi</h2>
    </div>
    <div class="table-wrap">
      <table id="t-cal">
        <thead><tr>
          <th data-i18n="nameCol">Ad</th>
          <th data-i18n="moduleCol">Modul</th>
          <th>Tarih</th>
          <th data-i18n="remaining">Kalan</th>
          <th data-i18n="statusCol">Durum</th>
        </tr></thead>
        <tbody id="cal-tbody">
          <tr class="no-results-row"><td colspan="5">&#x2014;</td></tr>
        </tbody>
      </table>
    </div>
  </div>

  <footer>LicenseGuard v$LGVersion &middot; <a href="https://github.com/mustafasercansak/LicenseGuard" target="_blank" style="color:inherit;text-decoration:none">Mustafa Sercan Sak</a></footer>
</main>
</div>

<script>
var i18n={
  tr:{pageTitle:'LicenseGuard Raporu',licenseSection:'Lisans Durumu',policySection:'Kurumsal Lisans Uyumluluk',moduleCol:'Modul',nameCol:'Ad',detailCol:'Detay',statusCol:'Durum',categoryCol:'Kategori',softwareCol:'Yazilim',descCol:'Aciklama / Oneri',searchPh:'Yazilim ara...',issuesOnly:'Sadece sorunlar',valid:'Gecerli',warning:'Uyari',errorExp:'Hata / Dolmus',banned:'Yasak',needsLic:'Lisans Gerekli',compliant:'Uyumlu',warnThreshold:'Uyari esigi',days:'gun',navLicense:'Lisans Durumu',navPolicy:'Uyumluluk',navSoftware:'Yazilimlar',navCalendar:'Takvim',navBrowserExt:'Tarayici Eklentileri',navVsCode:'VS Code',navStartup:'Baslangic',navProcess:'Aktif Processler',navSignature:'Imza',overallHealth:'Genel Saglik',sections:'Bolumler',modules:'Moduller',allModules:'Tumu',rcOf:'{v} / {t} kayit',calSection:'Lisans Takvimi',eolSection:'EOL / Destek Sonu',noExpiry:'Yaklasan bitis tarihi bulunamadi',exportCsv:'CSV Indir',exportJson:'JSON Indir',printPdf:'PDF Yazdir',remaining:'Kalan'},
  en:{pageTitle:'LicenseGuard Report',licenseSection:'License Status',policySection:'Corporate License Compliance',moduleCol:'Module',nameCol:'Name',detailCol:'Detail',statusCol:'Status',categoryCol:'Category',softwareCol:'Software',descCol:'Description / Suggestion',searchPh:'Search software...',issuesOnly:'Issues only',valid:'Valid',warning:'Warning',errorExp:'Error / Expired',banned:'Banned',needsLic:'Needs License',compliant:'Compliant',warnThreshold:'Warning threshold',days:'days',navLicense:'License Status',navPolicy:'Compliance',navSoftware:'Software',navCalendar:'Calendar',navBrowserExt:'Browser Extensions',navVsCode:'VS Code',navStartup:'Startup',navProcess:'Running Processes',navSignature:'Signature',overallHealth:'Overall Health',sections:'Sections',modules:'Modules',allModules:'All',rcOf:'{v} / {t} records',calSection:'License Calendar',eolSection:'EOL / End of Support',noExpiry:'No upcoming expiry dates found',exportCsv:'Export CSV',exportJson:'Export JSON',printPdf:'Print PDF',remaining:'Remaining'}
};
var currentLang='$initLang', activeMod=null;
var calendarData=$calJson;

function applyLang(lang){
  currentLang=lang;
  document.getElementById('htmlRoot').lang=lang;
  document.getElementById('langBtn').textContent=lang==='tr'?'EN':'TR';
  document.querySelectorAll('[data-i18n]').forEach(function(el){var k=el.getAttribute('data-i18n');if(i18n[lang][k]!==undefined)el.innerHTML=i18n[lang][k];});
  document.querySelectorAll('[data-i18n-ph]').forEach(function(el){var k=el.getAttribute('data-i18n-ph');if(i18n[lang][k]!==undefined)el.placeholder=i18n[lang][k];});
  document.querySelectorAll('[data-val-tr]').forEach(function(el){el.textContent=lang==='tr'?el.dataset.valTr:el.dataset.valEn;});
  document.title=i18n[lang].pageTitle;
  refreshRC();
  if(document.getElementById('tab-calendar').classList.contains('active')){buildCalendar();}
  try{localStorage.setItem('lg_lang',lang);}catch(e){}
}
function toggleLang(){applyLang(currentLang==='tr'?'en':'tr');}

function switchTab(id,el){
  document.querySelectorAll('.tab-pane').forEach(function(p){p.classList.remove('active');});
  document.querySelectorAll('.nav-item').forEach(function(n){n.classList.remove('active');});
  document.getElementById('tab-'+id).classList.add('active');
  el.classList.add('active');
  if(id==='calendar'){buildCalendar();}
}
function filterMod(mod,el){
  activeMod=mod;
  document.querySelectorAll('.nav-item').forEach(function(n){n.classList.remove('active');});
  el.classList.add('active');
  if(mod){
    document.querySelectorAll('.tab-pane').forEach(function(p){p.classList.remove('active');});
    document.getElementById('tab-license').classList.add('active');
    document.getElementById('nav-license').classList.add('active');
  }
  applyFilter('t1',document.getElementById('s1').value.toLowerCase(),document.getElementById('f1').checked);
}

function doFilter(inp){var n=inp.dataset.table.replace('t','');applyFilter(inp.dataset.table,inp.value.toLowerCase(),document.getElementById('f'+n).checked);}
function doFilterCb(cb){var n=cb.dataset.table.replace('t','');applyFilter(cb.dataset.table,document.getElementById('s'+n).value.toLowerCase(),cb.checked);}

function applyFilter(tid,q,issOnly){
  var rows=document.querySelectorAll('#'+tid+' tbody tr:not(.no-results-row)');
  var vis=0;
  rows.forEach(function(r){
    var badge=r.querySelector('.badge');
    var isIssue=badge&&(badge.classList.contains('expired')||badge.classList.contains('warn'));
    var mp=r.querySelector('.mod-pill');
    var modOk=!activeMod||!mp||(mp.dataset.mod===activeMod);
    var show=(!q||r.textContent.toLowerCase().indexOf(q)!==-1)&&(!issOnly||isIssue)&&modOk;
    r.classList.toggle('row-hidden',!show);
    if(show)vis++;
  });
  var nr=document.querySelector('#'+tid+' .no-results-row');
  if(!nr){nr=document.createElement('tr');nr.className='no-results-row';nr.innerHTML='<td colspan="99">&#x2205; Sonuc yok / No results</td>';document.querySelector('#'+tid+' tbody').appendChild(nr);}
  nr.classList.toggle('row-hidden',vis>0);
  setRC(tid,vis,rows.length);
}

function setRC(tid,vis,total){
  var n=tid.replace('t','');
  var el=document.getElementById('rc'+n);
  if(!el)return;
  var tmpl=i18n[currentLang].rcOf||'{v} / {t}';
  el.textContent=tmpl.replace('{v}',vis).replace('{t}',total);
}
function refreshRC(){
  var r1=document.querySelectorAll('#t1 tbody tr:not(.no-results-row):not(.row-hidden)').length;
  var t1=document.querySelectorAll('#t1 tbody tr:not(.no-results-row)').length;
  setRC('t1',r1,t1);
  var r2=document.querySelectorAll('#t2 tbody tr:not(.no-results-row):not(.row-hidden)').length;
  var t2=document.querySelectorAll('#t2 tbody tr:not(.no-results-row)').length;
  setRC('t2',r2,t2);
}

var sortState={};
function sortTable(tid,ci){
  var key=tid+':'+ci;var asc=!sortState[key];sortState[key]=asc;
  var t=document.getElementById(tid);
  t.querySelectorAll('th.sortable').forEach(function(th){th.classList.remove('sort-asc','sort-desc');});
  t.querySelectorAll('th')[ci].classList.add(asc?'sort-asc':'sort-desc');
  var tb=t.querySelector('tbody');
  var rows=Array.prototype.slice.call(tb.querySelectorAll('tr:not(.no-results-row)'));
  rows.sort(function(a,b){var av=(a.cells[ci]?a.cells[ci].textContent:'').trim();var bv=(b.cells[ci]?b.cells[ci].textContent:'').trim();return asc?av.localeCompare(bv,undefined,{numeric:true,sensitivity:'base'}):bv.localeCompare(av,undefined,{numeric:true,sensitivity:'base'});});
  var nr=tb.querySelector('.no-results-row');
  rows.forEach(function(r){tb.insertBefore(r,nr||null);});
}

function setCard(pfx,val,total){
  var pct=Math.round(val/total*100);
  var n=document.getElementById(pfx+'-n');
  var p=document.getElementById(pfx+'-p');
  var b=document.getElementById(pfx+'-b');
  if(n)n.textContent=val;
  if(p)p.textContent=pct+'%';
  if(b)setTimeout(function(){b.style.width=pct+'%';},120);
}

function updateDonut(pct){
  var circ=2*Math.PI*28;
  var dash=circ*pct/100;
  var el=document.getElementById('donut-ring');
  var txt=document.getElementById('health-pct');
  if(!el||!txt)return;
  var color=pct>=90?'#22c55e':pct>=70?'#f59e0b':'#ef4444';
  el.style.stroke=color;
  el.setAttribute('stroke-dasharray',dash+' '+circ);
  txt.style.color=color;
  txt.textContent=pct+'%';
}

function updateAll(){
  var t1=document.querySelectorAll('#t1 tbody tr:not(.no-results-row)');
  var ok1=0,wn1=0,er1=0;
  t1.forEach(function(r){var s=r.getAttribute('data-status');if(s==='OK')ok1++;else if(s==='WARN')wn1++;else er1++;});
  var lt=t1.length||1;
  setCard('c1ok',ok1,lt);setCard('c1wn',wn1,lt);setCard('c1er',er1,lt);

  var t2=document.querySelectorAll('#t2 tbody tr:not(.no-results-row)');
  var bn=0,lc=0,ok2=0;
  t2.forEach(function(r){var s=r.getAttribute('data-policy');if(s==='PROHIBITED')bn++;else if(s==='REQUIRES_LICENSE')lc++;else ok2++;});
  var pt=t2.length||1;
  setCard('c2bn',bn,pt);setCard('c2lc',lc,pt);setCard('c2ok',ok2,pt);
  updateDonut(Math.round(ok1/lt*100));

  var i1=wn1+er1,i2=bn+lc;
  var nb1=document.getElementById('nb1'),nb2=document.getElementById('nb2');
  if(nb1){nb1.textContent=i1||'';nb1.className='nav-badge'+(er1>0?' red':wn1>0?' yellow':'');}
  if(nb2){nb2.textContent=i2||'';nb2.className='nav-badge'+(bn>0?' red':lc>0?' yellow':'');}

  if(calendarData&&calendarData.length){
    var urgent=calendarData.filter(function(d){return d.days<=30;}).length;
    var nbCal=document.getElementById('nb-cal');
    if(nbCal){nbCal.textContent=urgent||'';nbCal.className='nav-badge'+(urgent>0?' yellow':'');}
  }
  refreshRC();
}

function buildCalendar(){
  var tbody=document.getElementById('cal-tbody');
  if(!calendarData||calendarData.length===0){
    tbody.innerHTML='<tr class="no-results-row"><td colspan="5">'+((i18n[currentLang]||{}).noExpiry||'Veri yok')+'</td></tr>';
    return;
  }
  var sorted=calendarData.slice().sort(function(a,b){return a.date.localeCompare(b.date);});
  var html='';
  sorted.forEach(function(item){
    var d=item.days;
    var cls=d<0?'expired':d<=30?'warn':'ok';
    var dclsCal=d<0?'urgent':d<=30?'warn':'ok';
    var daysTr=d<0?(Math.abs(d)+' gun once'):(d+' gun kaldi');
    var daysEn=d<0?(Math.abs(d)+' days ago'):(d+' days left');
    var badgeTr=cls==='ok'?'UYUMLU':cls==='warn'?'UYARI':'SURESI DOLDU';
    var badgeEn=cls==='ok'?'OK':cls==='warn'?'WARNING':'EXPIRED';
    html+='<tr data-status="'+(d<0?'EXPIRED':d<=30?'WARN':'OK')+'">';
    html+='<td>'+item.name+'</td>';
    html+='<td><span class="mod-pill">'+item.module+'</span></td>';
    html+='<td>'+item.date+'</td>';
    html+='<td><span class="cal-days '+dclsCal+'" data-val-tr="'+daysTr+'" data-val-en="'+daysEn+'">'+(currentLang==='tr'?daysTr:daysEn)+'</span></td>';
    html+='<td><span class="badge '+cls+'" data-val-tr="'+badgeTr+'" data-val-en="'+badgeEn+'">'+(currentLang==='tr'?badgeTr:badgeEn)+'</span></td>';
    html+='</tr>';
  });
  if(!html){html='<tr class="no-results-row"><td colspan="5">'+((i18n[currentLang]||{}).noExpiry||'Veri yok')+'</td></tr>';}
  tbody.innerHTML=html;
}

function exportTableCsv(tid,filename){
  var t=document.getElementById(tid);
  var hdr=[];
  t.querySelectorAll('thead th').forEach(function(th){hdr.push('"'+th.textContent.trim().replace(/"/g,'""')+'"');});
  var rows=[hdr.join(',')];
  t.querySelectorAll('tbody tr:not(.no-results-row):not(.row-hidden)').forEach(function(tr){
    var cells=[];
    tr.querySelectorAll('td').forEach(function(td){cells.push('"'+td.textContent.trim().replace(/"/g,'""')+'"');});
    rows.push(cells.join(','));
  });
  var blob=new Blob(['\uFEFF'+rows.join('\n')],{type:'text/csv;charset=utf-8;'});
  var a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=filename;a.click();
}
function exportTableJson(tid,filename){
  var t=document.getElementById(tid);
  var hdr=[];
  t.querySelectorAll('thead th').forEach(function(th){hdr.push(th.textContent.trim());});
  var rows=[];
  t.querySelectorAll('tbody tr:not(.no-results-row):not(.row-hidden)').forEach(function(tr){
    var obj={};
    tr.querySelectorAll('td').forEach(function(td,i){obj[hdr[i]||('col'+i)]=td.textContent.trim();});
    rows.push(obj);
  });
  var blob=new Blob([JSON.stringify(rows,null,2)],{type:'application/json'});
  var a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=filename;a.click();
}

window.addEventListener('load',function(){
  updateAll();
  try{var saved=localStorage.getItem('lg_lang');if(saved&&saved!==currentLang)applyLang(saved);}catch(e){}
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

# Versiyon kontrolu
if (-not $NoUpdateCheck) { Get-UpdateStatus }

# Policy test modu
if ($TestPolicy) {
    if (-not (Test-Path $PolicyPath)) { Write-Host "Policy dosyasi bulunamadi: $PolicyPath" -ForegroundColor Red; exit 1 }
    $pol = Get-Content $PolicyPath -Raw | ConvertFrom-Json
    Write-Host "`n  Policy: $PolicyPath  |  Kural sayisi: $($pol.rules.Count)`n" -ForegroundColor Cyan
    $pol.rules | ForEach-Object {
        $icon  = switch ($_.status) { "PROHIBITED" { "[XX]" } "REQUIRES_LICENSE" { "[!!]" } default { "[OK]" } }
        $color = switch ($_.status) { "PROHIBITED" { "Red" } "REQUIRES_LICENSE" { "Yellow" } default { "Green" } }
        Write-Host ("  $icon [$($_.id)] $($_.category.PadRight(25)) $($_.pattern) ($($_.matchType))") -ForegroundColor $color
    }
    exit 0
}

Write-Host "`n  $($L["starting"])`n" -ForegroundColor White

# Branding
$brandColor   = if ($config.Branding -and $config.Branding.PrimaryColor) { $config.Branding.PrimaryColor } else { "#3b82f6" }
$brandCompany = if ($config.Branding -and $config.Branding.CompanyName)  { $config.Branding.CompanyName  } else { "" }

$allResults     = [System.Collections.Generic.List[hashtable]]::new()
$policyFindings = @()

# Uzak makine taramasi (paralel)
if ($ComputerName) {
    $computers = $ComputerName.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    Write-Host "  Paralel tarama: $($computers.Count) makine..." -ForegroundColor Cyan
    $wd = $warnDays
    $remJobs = @{}
    foreach ($pc in $computers) {
        $remJobs[$pc] = Invoke-Command -ComputerName $pc -AsJob -ArgumentList $wd -ScriptBlock {
            param($wd)
            $winResult = @{ Status="ERROR"; Detail="WMI sorgusu basarisiz" }
            try {
                $prod = Get-CimInstance -Query "SELECT LicenseStatus,GracePeriodRemaining FROM SoftwareLicensingProduct WHERE PartialProductKey IS NOT NULL AND ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f'"
                if ($prod) {
                    $row = $prod | Sort-Object LicenseStatus | Select-Object -First 1
                    $ls  = [int]$row.LicenseStatus
                    $sm  = @{0=@("Unlicensed","EXPIRED");1=@("Licensed","OK");2=@("OOBGrace","WARN");3=@("OOTGrace","WARN");4=@("NonGenuineGrace","WARN");5=@("Notification","WARN");6=@("ExtendedGrace","WARN")}
                    $mp  = if ($sm.ContainsKey($ls)) { $sm[$ls] } else { @("Bilinmiyor","WARN") }
                    $det = if ($row.GracePeriodRemaining -gt 0) { "$($mp[0]) -- Kalan: $([math]::Round($row.GracePeriodRemaining/1440,1)) gun" } else { $mp[0] }
                    $winResult = @{ Status=$mp[1]; Detail=$det }
                }
            } catch {}
            $regPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*","HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*")
            $today = Get-Date; $swRows = @()
            foreach ($path in $regPaths) {
                Get-ItemProperty $path 2>$null | Where-Object { $_.DisplayName } | ForEach-Object {
                    $status="OK"; $expInfo=""
                    $expireDate=$null
                    foreach ($field in @("ExpirationDate","TrialExpireDate","ExpireDate","LicenseExpiry")) {
                        $val=$_.$field
                        if($val){try{$expireDate=[datetime]$val;break}catch{};if($val -match '^\d{8}$'){try{$expireDate=[datetime]::ParseExact($val,"yyyyMMdd",$null);break}catch{}}}
                    }
                    if($expireDate){$dl=($expireDate-$today).Days;if($dl-lt 0){$status="EXPIRED";$expInfo="EXPIRED"}elseif($dl-le $wd){$status="WARN";$expInfo="Expires: $($expireDate.ToString('yyyy-MM-dd'))"}}
                    $swRows += [PSCustomObject]@{Name=$_.DisplayName;Version=if($_.DisplayVersion){$_.DisplayVersion}else{"-"};Publisher=if($_.Publisher){$_.Publisher}else{"Unknown"};ExpireInfo=$expInfo;Status=$status;InstallDate="-"}
                }
            }
            [PSCustomObject]@{ WinStatus=$winResult.Status; WinDetail=$winResult.Detail; Software=($swRows|Sort-Object Name -Unique) }
        }
    }
    foreach ($pc in $computers) {
        try {
            $data = Receive-Job $remJobs[$pc] -Wait -ErrorAction Stop
            if ($data) {
                $allResults.Add(@{ Module="WindowsActivation"; Name="[$pc] Windows Aktivasyon"; Status=$data.WinStatus; Detail=$data.WinDetail })
                $data.Software | ForEach-Object { $allResults.Add(@{ Module="Software"; Name="[$pc] $($_.Name)"; Status=$_.Status; Detail=$_.ExpireInfo }) }
            }
        } catch { Write-Host "  [ERROR] $pc : $($_.Exception.Message)" -ForegroundColor Red }
        Remove-Job $remJobs[$pc] -Force -ErrorAction SilentlyContinue
    }
}

# Yerel tarama
$swCache = @()
if (-not $ComputerName) {
    $r1 = Get-WindowsActivation; if ($r1) { $allResults.Add($r1) }
    $swCache = Get-InstalledSoftwareCache
    $r2 = Get-InstalledSoftwareAudit -Cache $swCache; if ($r2) { $r2 | ForEach-Object { $allResults.Add($_) } }

    if ($config.EolCheck -ne $false) {
        $eolR = Get-EolStatus -Cache $swCache; if ($eolR) { $eolR | ForEach-Object { $allResults.Add($_) } }
    }
    if ($config.ScanBrowserExtensions -ne $false) {
        $brR = Get-BrowserExtensionAudit; if ($brR) { $brR | ForEach-Object { $allResults.Add($_) } }
    }
    if ($config.ScanVsCodeExtensions -ne $false) {
        $vsR = Get-VsCodeExtensionAudit; if ($vsR) { $vsR | ForEach-Object { $allResults.Add($_) } }
    }
    if ($config.ScanStartup -ne $false) {
        $stR = Get-StartupAudit; if ($stR) { $stR | ForEach-Object { $allResults.Add($_) } }
    }
}

$r3 = Get-FlexLMStatus; if ($r3) { $r3 | ForEach-Object { $allResults.Add($_) } }
$r4 = Get-SaaSStatus;   if ($r4) { $r4 | ForEach-Object { $allResults.Add($_) } }

$policyFindings = Invoke-PolicyCheck -PolicyPath $PolicyPath -SoftwareRows $swCache

# Policy sonrasi taramalar (yerel)
if (-not $ComputerName) {
    $procR = Get-RunningProhibitedProcesses -PolicyFindings $policyFindings
    if ($procR) { $procR | ForEach-Object { $allResults.Add($_) } }
    if ($CheckSignatures) {
        $sigR = Get-SignatureAudit -PolicyFindings $policyFindings
        if ($sigR) { $sigR | ForEach-Object { $allResults.Add($_) } }
    }
}

# Delta
$delta = $null
if (-not $NoDelta) {
    $delta = Get-Delta -SnapshotPath $config.SnapshotPath -CurrentResults $allResults -CurrentPolicyFindings $policyFindings
    Save-Snapshot -AllResults $allResults -PolicyFindings $policyFindings -SnapshotPath $config.SnapshotPath
}

# HTML raporu
if (-not $ConsoleOnly) {
    Export-HtmlReportFull -AllResults $allResults -PolicyFindings $policyFindings -Delta $delta -BrandColor $brandColor -BrandCompany $brandCompany
}

# CSV / JSON / SARIF disari aktarma
if ($ExportCsv)  { Export-CsvReport  -AllResults $allResults -PolicyFindings $policyFindings -CsvPath $ExportCsv  }
if ($ExportJson) { Export-JsonReport -AllResults $allResults -PolicyFindings $policyFindings -JsonPath $ExportJson }
if ($SarifPath)  { Export-SarifReport -PolicyFindings $policyFindings -SarifPath $SarifPath }

# Jira
if ($CreateJiraIssues) { New-JiraIssues -JiraConfig $config.Jira -PolicyFindings $policyFindings }

# Ozet
$criticalLicense = @($allResults     | Where-Object { $_.Status -in @("EXPIRED","ERROR") })
$prohibited      = @($policyFindings | Where-Object { $_.PolicyStatus -eq "PROHIBITED"       })
$needsLic        = @($policyFindings | Where-Object { $_.PolicyStatus -eq "REQUIRES_LICENSE" })

# Windows Event Log
$evtType = if ($criticalLicense -or $prohibited) { "Error" } elseif ($needsLic) { "Warning" } else { "Information" }
$evtId   = if ($criticalLicense -or $prohibited) { 1002 } elseif ($needsLic) { 1001 } else { 1000 }
Write-LGEventLog -Message "LicenseGuard v$LGVersion. Kritik:$($criticalLicense.Count) Yasak:$($prohibited.Count) LisansGerekli:$($needsLic.Count)" -EntryType $evtType -EventId $evtId

Write-Host ""
if ($criticalLicense) { Write-Host "  [!!] $($criticalLicense.Count) $($L["criticalCount"])"   -ForegroundColor Red    }
if ($prohibited)      { Write-Host "  [XX] $($prohibited.Count) $($L["prohibitedFound"])"       -ForegroundColor Red    }
if ($needsLic)        { Write-Host "  [!]  $($needsLic.Count) $($L["needsLicCount"])"           -ForegroundColor Yellow }
if (-not $criticalLicense -and -not $prohibited -and -not $needsLic) {
    Write-Host "  [OK] $($L["allClear"])" -ForegroundColor Green
}
Write-Host ""

# Webhook bildirimi
if ($config.Webhook) {
    $wbColor   = if ($prohibited) { "FF0000" } elseif ($criticalLicense -or $needsLic) { "FFA500" } else { "00CC44" }
    $wbTitle   = if ($prohibited) { "Yasak Yazilim Tespit Edildi!" } elseif ($criticalLicense) { "Kritik Lisans Sorunu" } else { "Tarama Tamamlandi" }
    $wbSummary = "$env:COMPUTERNAME | Yasak:$($prohibited.Count) Kritik:$($criticalLicense.Count) LisansGerekli:$($needsLic.Count)"
    Send-WebhookNotification -WebhookConfig $config.Webhook -Title $wbTitle -Summary $wbSummary -Color $wbColor
}

# Email
if ($SendMail) {
    $summary = "LicenseGuard v$LGVersion - $env:COMPUTERNAME`nKritik: $($criticalLicense.Count) | Yasak: $($prohibited.Count) | Lisans Gerekli: $($needsLic.Count)"
    Send-MailReport -EmailConfig $config.Email -ReportPath $OutputPath -Summary $summary
}

if ($criticalLicense -or $prohibited) { exit 1 }
