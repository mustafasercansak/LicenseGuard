# 🔐 LicenseGuard

**TR** | [EN](#english)

Kurumsal Windows ortamlarında yüklü yazılımları tarayarak lisans uyumluluğunu denetleyen, HTML rapor üreten PowerShell aracı.

![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Platform](https://img.shields.io/badge/Platform-Windows-informational?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Özellikler

- **Windows Aktivasyon** durumu (WMI üzerinden)
- **Yüklü yazılım envanteri** — 3 registry yolu, expire date tarama
- **FlexLM lisans sunucusu** ping (opsiyonel, `lg-config.json`)
- **SaaS / API key** sağlık kontrolü (opsiyonel)
- **Kurumsal politika kontrolü** — 79 kural, 16 kategori (`lg-policy.json`)
- **HTML rapor** — koyu tema, TR/EN dil geçişi, arama, sıralama, filtre
- **PowerShell 5.1 uyumlu** — Windows Update gerektirmez

## Kurulum

```powershell
git clone https://github.com/kullaniciadi/LicenseGuard.git
cd LicenseGuard
```

Config dosyasını kopyalayın (opsiyonel):
```powershell
Copy-Item lg-config.example.json lg-config.json
# lg-config.json içindeki FlexLM / SaaS alanlarını doldurun
```

## Kullanım

```powershell
# Temel kullanım (Türkçe rapor)
.\LicenseGuard.ps1

# İngilizce rapor
.\LicenseGuard.ps1 -Lang en

# Özel çıktı yolu
.\LicenseGuard.ps1 -OutputPath "C:\Reports\rapor.html"

# Yalnızca konsol çıktısı (HTML oluşturma)
.\LicenseGuard.ps1 -ConsoleOnly

# Özel policy dosyası
.\LicenseGuard.ps1 -PolicyPath ".\ozel-policy.json"

# Tüm parametreler
.\LicenseGuard.ps1 -Lang en -OutputPath ".\rapor.html" -ConfigPath ".\lg-config.json" -PolicyPath ".\lg-policy.json"
```

## Parametreler

| Parametre | Varsayılan | Açıklama |
|---|---|---|
| `-Lang` | `tr` | Rapor dili: `tr` veya `en` |
| `-OutputPath` | `.\license-report.html` | HTML çıktı yolu |
| `-ConfigPath` | `.\lg-config.json` | FlexLM/SaaS config dosyası |
| `-PolicyPath` | `.\lg-policy.json` | Politika kuralları dosyası |
| `-ConsoleOnly` | `$false` | HTML oluşturmadan yalnızca konsol çıktısı |

## Politika Kuralları

`lg-policy.json` dosyası özelleştirilebilir. Her kural şu alanları içerir:

```json
{
  "id": "IDE-001",
  "category": "IDE",
  "pattern": "Visual Studio Community",
  "matchType": "contains",
  "status": "PROHIBITED",
  "reason": "Ticari kullanım için lisanslı değil.",
  "alternative": "VS Code (MIT lisanslı)",
  "referenceUrl": "https://..."
}
```

| Alan | Değerler |
|---|---|
| `matchType` | `contains`, `startsWith`, `exact`, `regex` |
| `status` | `ALLOWED`, `REQUIRES_LICENSE`, `PROHIBITED` |

### Mevcut Kategoriler (79 kural)

| Kategori | Kural Sayısı |
|---|---|
| Medya / Ofis | 10 |
| IDE | 7 |
| Geliştirme Araçları | 7 |
| Güvenlik / Parola | 6 |
| Ağ / Transfer | 6 |
| Uzak Bağlantı | 5 |
| Konteyner / DevOps | 5 |
| AI Araçları | 4 |
| API / DB | 4 |
| İletişim | 4 |
| Tasarım | 4 |
| Versiyon Kontrol | 4 |
| Üretkenlik / Not | 4 |
| Terminal | 3 |
| Arşiv | 3 |
| Tarayıcı | 3 |

## Rapor Özellikleri

- Koyu GitHub-primer tema
- TR / EN dil geçişi (localStorage kalıcı)
- Özet kartlar (sayı + yüzde, tablodan dinamik hesaplanır)
- Her tablo için arama kutusu
- "Sadece sorunlar" filtresi
- Sütun başlıklarına tıklayarak sıralama
- Mobil uyumlu tasarım
- XSS koruması

## Dosya Yapısı

```
LicenseGuard/
├── LicenseGuard.ps1          # Ana script
├── lg-policy.json            # Politika kuralları (79 kural)
├── lg-config.example.json    # Config şablonu
├── LICENSE                   # MIT
└── README.md
```

> `lg-config.json` ve üretilen `*.html` raporları `.gitignore` ile hariç tutulmuştur.

---

## English

A PowerShell tool that scans installed software on Windows machines, checks license compliance against a customizable policy, and generates a bilingual HTML report.

### Features

- **Windows Activation** status check (via WMI)
- **Installed software inventory** — 3 registry paths, expiration date scanning
- **FlexLM license server** ping (optional, via `lg-config.json`)
- **SaaS / API key** health check (optional)
- **Corporate policy check** — 79 rules across 16 categories (`lg-policy.json`)
- **HTML report** — dark theme, TR/EN language toggle, search, sort, filter
- **PowerShell 5.1 compatible** — no Windows Update required

### Quick Start

```powershell
git clone https://github.com/yourusername/LicenseGuard.git
cd LicenseGuard

# Run with defaults (Turkish report)
.\LicenseGuard.ps1

# English report
.\LicenseGuard.ps1 -Lang en
```

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `-Lang` | `tr` | Report language: `tr` or `en` |
| `-OutputPath` | `.\license-report.html` | HTML output path |
| `-ConfigPath` | `.\lg-config.json` | FlexLM/SaaS config file |
| `-PolicyPath` | `.\lg-policy.json` | Policy rules file |
| `-ConsoleOnly` | `$false` | Console output only, skip HTML |

### Policy Rule Format

```json
{
  "id": "CONT-001",
  "category": "Container / DevOps",
  "pattern": "Docker Desktop",
  "matchType": "contains",
  "status": "REQUIRES_LICENSE",
  "reason": "Requires Docker Business license for companies with 250+ employees or $10M+ revenue.",
  "alternative": "Rancher Desktop (Apache 2.0, free)",
  "referenceUrl": "https://www.docker.com/pricing/"
}
```

### License

MIT © 2026 Mustafa Sercan Sak
