# EOL database — loaded once into module scope at import time
$script:LGEolDatabase = @(
    [PSCustomObject]@{ Pattern='Internet Explorer';     MatchType='contains';   EolDate='2022-06-15' }
    [PSCustomObject]@{ Pattern='Office 2010';           MatchType='contains';   EolDate='2020-10-13' }
    [PSCustomObject]@{ Pattern='Office 2013';           MatchType='contains';   EolDate='2023-04-11' }
    [PSCustomObject]@{ Pattern='Microsoft Office 2013'; MatchType='contains';   EolDate='2023-04-11' }
    [PSCustomObject]@{ Pattern='Office 2016';           MatchType='contains';   EolDate='2025-10-14' }
    [PSCustomObject]@{ Pattern='Office 2019';           MatchType='contains';   EolDate='2025-10-14' }
    [PSCustomObject]@{ Pattern='Silverlight';           MatchType='contains';   EolDate='2021-10-12' }
    [PSCustomObject]@{ Pattern='Adobe Flash';           MatchType='contains';   EolDate='2020-12-31' }
    [PSCustomObject]@{ Pattern='Flash Player';          MatchType='contains';   EolDate='2020-12-31' }
    [PSCustomObject]@{ Pattern='Python 2';              MatchType='startsWith'; EolDate='2020-01-01' }
    [PSCustomObject]@{ Pattern='Visual Studio 2015';    MatchType='contains';   EolDate='2025-10-14' }
    [PSCustomObject]@{ Pattern='Visual Studio 2017';    MatchType='contains';   EolDate='2027-04-14' }
    [PSCustomObject]@{ Pattern='SQL Server 2012';       MatchType='contains';   EolDate='2022-07-12' }
    [PSCustomObject]@{ Pattern='SQL Server 2014';       MatchType='contains';   EolDate='2024-07-09' }
    [PSCustomObject]@{ Pattern='SQL Server 2016';       MatchType='contains';   EolDate='2026-07-14' }
    [PSCustomObject]@{ Pattern='SQL Server 2017';       MatchType='contains';   EolDate='2027-10-12' }
    [PSCustomObject]@{ Pattern='Exchange Server 2013';  MatchType='contains';   EolDate='2023-04-11' }
    [PSCustomObject]@{ Pattern='Exchange Server 2016';  MatchType='contains';   EolDate='2025-10-14' }
    [PSCustomObject]@{ Pattern='SharePoint 2013';       MatchType='contains';   EolDate='2023-04-11' }
    [PSCustomObject]@{ Pattern='SharePoint 2016';       MatchType='contains';   EolDate='2026-07-14' }
    [PSCustomObject]@{ Pattern='Windows 7';             MatchType='contains';   EolDate='2020-01-14' }
    [PSCustomObject]@{ Pattern='Windows 8.1';           MatchType='contains';   EolDate='2023-01-10' }
    [PSCustomObject]@{ Pattern='Node.js 14';            MatchType='contains';   EolDate='2023-04-30' }
    [PSCustomObject]@{ Pattern='Node.js 16';            MatchType='contains';   EolDate='2023-09-11' }
    [PSCustomObject]@{ Pattern='Angular 12';            MatchType='contains';   EolDate='2022-11-12' }
    [PSCustomObject]@{ Pattern='Angular 13';            MatchType='contains';   EolDate='2023-05-04' }
    [PSCustomObject]@{ Pattern='Java SE 8';             MatchType='contains';   EolDate='2030-12-31' }
)

$script:LGDefaultConfig = @{
    FlexLM                = @()
    SaaS                  = @()
    WarnDaysBeforeExpiry  = 30
    Whitelist             = @()
    SnapshotPath          = '.\lg-snapshot.json'
    EolCheck              = $true
    Email                 = $null
    Webhook               = $null
    Jira                  = $null
    Branding              = $null
    ScanBrowserExtensions = $true
    ScanVsCodeExtensions  = $true
    ScanStartup           = $true
}

function Get-LGDefaultStrings {
    param([ValidateSet('tr','en')][string]$Language = 'tr')
    $strings = @{
        tr = @{
            reportTitle     = 'LicenseGuard'
            valid           = 'Gecerli'
            warn            = 'Uyari'
            expired         = 'Hata / Dolmus'
            noRule          = 'Kural Yok/Uyumlu'
            allowed         = 'UYUMLU'
            prohibited      = 'YASAK'
            requiresLicense = 'LISANS GEREKLI'
            policySection   = 'Kurumsal Lisans Uyumluluk'
            noMatch         = 'Kural Yok/Uyumlu'
            reportSaved     = 'HTML rapor kaydedildi:'
            criticalCount   = 'kritik lisans sorunu.'
            prohibitedFound = 'YASAK yazilim tespit edildi -- acil aksiyon gerekli!'
            needsLicCount   = 'yazilim lisans dogrulamasi bekliyor.'
            allClear        = 'Tum kontroller tamamlandi, uyumluluk sorunu yok.'
            starting        = 'LicenseGuard baslatiliyor...'
            hdrWinAct       = 'Windows Aktivasyon'
            hdrOffice       = 'Microsoft Office Lisans Durumu'
            hdrSoftware     = 'Kurulu Yazilim Envanteri'
            hdrFlexLM       = 'FlexLM Lisans Sunucusu'
            hdrSaaS         = 'SaaS / API Key Durumu'
            hdrEol          = 'EOL / Destek Sonu Taramasi'
            publisherUnknown= 'Bilinmiyor'
            eolSection      = 'EOL / Destek Sonu'
            calSection      = 'Lisans Takvimi'
            severity        = 'Onem'
            whitelist       = 'ONAYLANMIS'
            noExpiry        = 'Yaklasan bitis tarihi bulunamadi'
            exportCsv       = 'CSV Indir'
            exportJson      = 'JSON Indir'
            printPdf        = 'PDF Yazdir'
            deltaTitle      = 'Degisiklikler'
            deltaNew        = 'yeni sorun'
            deltaResolved   = 'cozuldu'
            deltaSince      = 'Onceki tarama:'
            snapshotSaved   = 'Snapshot kaydedildi:'
            officeNotFound  = 'Kurulu degil veya tespit edilemedi'
            hdrBrowser      = 'Tarayici Eklentileri Taramasi'
            hdrVsCode       = 'VS Code Eklentileri'
            hdrStartup      = 'Baslangi Programlari'
            hdrProcess      = 'Yasak Process Taramasi'
            hdrSignature    = 'Dijital Imza Dogrulama'
            updateAvail     = 'Yeni surum mevcut'
            updateCurrent   = 'Guncel surum kullaniliyor'
            sarifSaved      = 'SARIF rapor kaydedildi:'
        }
        en = @{
            reportTitle     = 'LicenseGuard'
            valid           = 'Valid'
            warn            = 'Warning'
            expired         = 'Error / Expired'
            noRule          = 'No Policy/Compliant'
            allowed         = 'COMPLIANT'
            prohibited      = 'PROHIBITED'
            requiresLicense = 'REQUIRES LICENSE'
            policySection   = 'Corporate License Compliance'
            noMatch         = 'No Policy/Compliant'
            reportSaved     = 'HTML report saved:'
            criticalCount   = 'critical license issues.'
            prohibitedFound = 'PROHIBITED software detected -- immediate action required!'
            needsLicCount   = 'software awaiting license verification.'
            allClear        = 'All checks passed, no compliance issues.'
            starting        = 'LicenseGuard starting...'
            hdrWinAct       = 'Windows Activation'
            hdrOffice       = 'Microsoft Office License Status'
            hdrSoftware     = 'Installed Software Inventory'
            hdrFlexLM       = 'FlexLM License Server'
            hdrSaaS         = 'SaaS / API Key Status'
            hdrEol          = 'EOL / End-of-Support Scan'
            publisherUnknown= 'Unknown'
            eolSection      = 'EOL / End of Support'
            calSection      = 'License Calendar'
            severity        = 'Severity'
            whitelist       = 'APPROVED'
            noExpiry        = 'No upcoming expiry dates found'
            exportCsv       = 'Export CSV'
            exportJson      = 'Export JSON'
            printPdf        = 'Print PDF'
            deltaTitle      = 'Changes'
            deltaNew        = 'new issue'
            deltaResolved   = 'resolved'
            deltaSince      = 'Previous scan:'
            snapshotSaved   = 'Snapshot saved:'
            officeNotFound  = 'Not installed or not detected'
            hdrBrowser      = 'Browser Extension Scan'
            hdrVsCode       = 'VS Code Extensions'
            hdrStartup      = 'Startup Programs'
            hdrProcess      = 'Prohibited Process Scan'
            hdrSignature    = 'Digital Signature Verification'
            updateAvail     = 'New version available'
            updateCurrent   = 'Using latest version'
            sarifSaved      = 'SARIF report saved:'
        }
    }
    return $strings[$Language]
}

function Get-LGEffectiveConfig {
    if ($script:LGConfig) { return $script:LGConfig }
    return $script:LGDefaultConfig
}

function Get-LGEffectiveStrings {
    if ($script:LGStrings) { return $script:LGStrings }
    return Get-LGDefaultStrings -Language 'en'
}
