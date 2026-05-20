# Changelog

**TR** | [EN](#english)

Bu projedeki tüm önemli değişiklikler bu dosyada belgelenmektedir.  
Format [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) standardını takip etmektedir.

---

## [3.1.0] - 2026-05-20

### Eklendi
- **Proje Bağımlılık Taraması (SCA)** (`Get-LGProjectDependencies`) — Node.js (`package.json`) ve .NET (`.csproj`) projelerini tarayarak kütüphane lisanslarını tespit eder.
- **Derlenmiş Dosya Lisans Denetimi (Binary Audit)** (`Get-LGBinaryLicenseAudit`) — Derlenmiş `.exe`/`.dll` dosyalarının PE başlık bilgilerini, `.deps.json` bağımlılıklarını ve SBOM dosyalarını (CycloneDX/SPDX) analiz ederek lisans uyumluluğunu doğrular.
- `lg-policy.json` içine `matchField` desteği eklendi. Artık kurallar sadece program ismine değil, kütüphanelerin lisans türüne (ör. `MIT`, `GPL`) göre de eşleştirilebilir.
- `Invoke-LicenseGuard` için `-ProjectPath` parametresi eklendi. (Hem kaynak kodlarını hem derleme çıktılarını tarar)

---

## [3.0.0] — 2026-04-06

### Eklendi
- **Microsoft Office lisans kontrolü** (`Get-OfficeLicenseStatus`) — `ospp.vbs` (Office 14/15/16) ve WMI fallback ile aktivasyon durumu ve kalan süreyi raporlar; `-ComputerName` ile uzak makineleri destekler; HTML raporda "Office" bölümünde gösterilir
- `Get-Help` comment-based belgeleme bloğu (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`)
- `-NoUpdateCheck` parametresi — sürüm kontrolünü atlar
- `-CreateJiraIssues` parametresi — ihlaller için otomatik Jira ticket açar
- `-SarifPath` ile SARIF rapor çıktısı
- `lg-snapshot.json` ve `lg-report.csv` `.gitignore`'a eklendi
- `CONTRIBUTING.md` iki dilli (TR/EN) olarak oluşturuldu

### Düzeltildi
- `Get-InstalledSoftwareCache`: `SystemComponent = 1` olan kayıt defteri girdileri (dil paketleri, Office proof paketleri, alt bileşenler) artık envanter taramasından ve politika kontrolünden hariç tutulmaktadır — bu özellik yanlış pozitif politika eşleşmelerini (ör. `tr-tr.proof`) gidermektedir

---

## [2.0] — 2026-03-27

### Eklendi
- **Tarayıcı Eklentileri Taraması** — Chrome/Firefox/Edge üzerindeki eklentiler (`ScanBrowserExtensions`)
- **VS Code Eklentileri Taraması** — kurulu uzantılar politikaya göre değerlendirilir (`ScanVsCodeExtensions`)
- **Başlangıç Programları Taraması** — sistem başlangıcında çalışan programlar (`ScanStartup`)
- **Aktif Process Taraması** — yasaklı süreçlerin çalışıp çalışmadığını kontrol eder
- **Dijital İmza Doğrulama** — yürütülebilir dosyaların imzaları (`-CheckSignatures`)
- **EOL / Destek Sonu Taraması** — 27 yazılım/platform için yerleşik EOL veritabanı
- `-ExportCsv`, `-ExportJson`, `-SarifPath` parametreleri
- `-SendMail` — SSL destekli SMTP ile HTML rapor gönderimi
- `-ComputerName` — WinRM üzerinden uzak makine taraması
- `-NoDelta` — delta karşılaştırmasını devre dışı bırakır
- `-TestPolicy` — veri toplamadan politika kurallarını doğrular
- Delta/Snapshot sistemi: `lg-snapshot.json` taramalar arasındaki ihlalleri izler
- Teams ve Slack webhook bildirimleri
- Jira entegrasyonu (`-CreateJiraIssues`)
- `Register-LicenseGuardTask.ps1` — Windows Görev Zamanlayıcısı kaydı
- Kurumsal markalaşma: şirket adı ve birincil renk (`lg-config.json`)
- HTML rapor: CSV/JSON/PDF dışa aktarım, delta paneli, gezinti menüsü
- Whitelist desteği: onaylanmış yazılımlar `ONAYLANMIŞ` olarak etiketlenir

### Düzeltildi
- Config yükleme `$null` kontrolüne geçirildi — `0` ve `$false` değerler artık doğru işlenir
- HTML çıktısında XSS güvenliği için `Encode-Html` fonksiyonu
- Konsol çıktısı `Write-Header` / `Write-Status` ile standardize edildi
- PS 5.1 `Where-Object` tek sonuç `Count` özelliği sorunu

---

## [1.0] — 2026-03-26

### Eklendi
- İlk sürüm
- 5 tarama modülü: Windows Aktivasyon, Yazılım Envanteri, FlexLM, SaaS, Politika Kontrolü
- 79 politika kuralı, 16 kategori
- TR/EN iki dilli HTML rapor (karanlık tema, arama, sıralama, filtreleme)
- PowerShell 5.1 uyumlu

---

## English

All notable changes to this project will be documented in this file.  
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [3.1.0] - 2026-05-20

### Added
- **Project Dependency Scan (SCA)** (`Get-LGProjectDependencies`) — Scans Node.js (`package.json`) and .NET (`.csproj`) projects to detect library licenses.
- **Compiled File License Audit (Binary Audit)** (`Get-LGBinaryLicenseAudit`) — Audits compiled `.exe` and `.dll` files by analyzing PE metadata, `.deps.json` dependencies, and SBOM files (CycloneDX/SPDX) for licensing compliance.
- Added `matchField` support to `lg-policy.json`, allowing rules to match by license type (e.g., `MIT`, `GPL`) instead of just the software name.
- Added `-ProjectPath` parameter to `Invoke-LicenseGuard` to support scanning project dependencies and compiled outputs.

---

## [3.0.0] — 2026-04-06

### Added
- **Microsoft Office license check** (`Get-OfficeLicenseStatus`) — queries `ospp.vbs` (Office 14/15/16) with WMI fallback; reports activation status and remaining grace period; supports remote machines via `-ComputerName`; shown in a dedicated "Office" nav section in the HTML report
- `Get-Help` comment-based documentation block (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`)
- `-NoUpdateCheck` switch to skip version update check
- `-CreateJiraIssues` switch to automatically open Jira tickets for violations
- SARIF report output via `-SarifPath` parameter
- `lg-snapshot.json` and `lg-report.csv` added to `.gitignore`
- `CONTRIBUTING.md` created in bilingual (TR/EN) format

### Fixed
- `Get-InstalledSoftwareCache`: registry entries with `SystemComponent = 1` (language packs, Office proof packs, sub-components) are now excluded from the software inventory and policy checks — eliminates false-positive policy matches (e.g. `tr-tr.proof`)

---

## [2.0] — 2026-03-27

### Added
- **Browser Extension Scan** — Chrome/Firefox/Edge installed extensions (`ScanBrowserExtensions`)
- **VS Code Extension Scan** — installed extensions evaluated against policy (`ScanVsCodeExtensions`)
- **Startup Program Scan** — programs running at system start (`ScanStartup`)
- **Running Process Scan** — checks for prohibited active processes
- **Digital Signature Verification** — validates executable signatures (`-CheckSignatures`)
- **EOL / End-of-Support Scan** — built-in database of 27 software/platforms
- `-ExportCsv`, `-ExportJson`, `-SarifPath` export parameters
- `-SendMail` — SMTP HTML report delivery (SSL supported)
- `-ComputerName` — remote machine scan via WinRM
- `-NoDelta` — disable delta comparison with previous scan
- `-TestPolicy` — validate policy rules without collecting data
- Delta/Snapshot system: `lg-snapshot.json` tracks violations between scans
- Teams and Slack webhook notifications
- Jira integration (`-CreateJiraIssues`)
- `Register-LicenseGuardTask.ps1` — Windows Task Scheduler registration
- Branding support: company name and primary color via `lg-config.json`
- HTML report: CSV/JSON/PDF export buttons, delta panel, navigation menu
- Whitelist support: approved software tagged as `APPROVED`
- `Encode-Html` utility for XSS protection in HTML output
- `Write-Header` / `Write-Status` for standardized console output

### Fixed
- Config loading switched to `$null` checks — `0` and `$false` values now handled correctly
- PowerShell 5.1 `Where-Object` single-result `Count` property issue

---

## [1.0] — 2026-03-26

### Added
- Initial release
- 5 scan modules: Windows Activation, Software Inventory, FlexLM, SaaS, Policy Check
- 79 policy rules across 16 categories
- Bilingual HTML report (TR/EN, dark theme, search, sort, filter)
- PowerShell 5.1 compatible
