**TR** | [EN](#english)

# LicenseGuard'a Katkı

LicenseGuard'ı geliştirmeye ilgi duyduğunuz için teşekkürler. Bu belge nasıl katkıda bulunabileceğinizi açıklar.

---

## Katkı Türleri

- **Hata bildirimi** — yeniden üretme adımları, PowerShell sürümü ve Windows sürümüyle birlikte issue açın
- **Politika kuralları** — `lg-policy.json` içine yeni kural ekleyin veya mevcut kuralları düzeltin
- **EOL veritabanı** — `LicenseGuard.ps1` içindeki `$eolDatabase` listesini güncelleyin veya genişletin
- **Yeni tarama modülleri** — yeni tespit yetenekleri ekleyin
- **Belgeleme** — yazım hatalarını düzeltin, örnekleri iyileştirin, çeviri ekleyin

---

## Başlarken

```powershell
git clone https://github.com/mustafasercansak/LicenseGuard.git
cd LicenseGuard

# Örnek config'i kopyalayın ve düzenleyin
Copy-Item lg-config.example.json lg-config.json

# Araç çalıştırın
.\LicenseGuard.ps1 -Lang tr

# Veri toplamadan politika kurallarını doğrulayın
.\LicenseGuard.ps1 -TestPolicy
```

**Gereksinimler:** Windows üzerinde PowerShell 5.1+. Ek modül gerekmez.

---

## Politika Kuralı Formatı (`lg-policy.json`)

Her kural şu şemayı takip etmelidir:

```json
{
  "id": "KAT-001",
  "category": "Kategori Adı",
  "pattern": "Yazılım Görünen Adı",
  "matchType": "contains",
  "status": "PROHIBITED",
  "reason": "Bu yazılımın neden işaretlendiği.",
  "alternative": "Önerilen alternatif (varsa)",
  "referenceUrl": "https://uretici-fiyatlandirma-sayfasi"
}
```

| Alan | Geçerli değerler |
|---|---|
| `matchType` | `contains`, `startsWith`, `exact`, `regex` |
| `status` | `ALLOWED`, `REQUIRES_LICENSE`, `PROHIBITED` |

Kurallar Windows kayıt defterindeki (`Uninstall` anahtarları) `DisplayName` alanına göre değerlendirilir. PR göndermeden önce kuralınızı `-TestPolicy` ile test edin.

> **Not:** `SystemComponent = 1` değerine sahip kayıt defteri girdileri (dil paketleri, alt bileşenler) envanter taramasında otomatik olarak hariç tutulur.

---

## Değişiklik Gönderme

1. Repository'yi fork'layın ve branch oluşturun: `git checkout -b feat/degisikligim`
2. Değişikliklerinizi yapın — commit'leri odaklı ve açıklayıcı tutun
3. Yerel test: `.\LicenseGuard.ps1 -TestPolicy` ve tam tarama
4. `master` branch'ine yönelik açıklamalı bir pull request açın

### PR Kontrol Listesi

- [ ] `lg-config.json` commit edilmemiş (gitignore'da)
- [ ] `*.html` raporlar commit edilmemiş
- [ ] Politika kural ID'leri mevcut `KAT-NNN` formatını takip ediyor ve benzersiz
- [ ] Commit edilmiş hiçbir dosyada düz metin kimlik bilgisi yok

---

## Kod Stili

- PowerShell 5.1 uyumlu — PS 7'ye özgü özellikler kullanmayın (`??`, `ForEach-Object -Parallel` vb.)
- Konsol çıktısı için `Write-Header` / `Write-Status` kullanın
- Tüm HTML çıktısını `Encode-Html` ile temizleyin
- Dil dizelerini hem `$L.tr` hem de `$L.en` bloklarına ekleyin

---

## Güvenlik Açığı Bildirimi

Güvenlik açıkları için herkese açık issue açmayın. Doğrudan [GitHub](https://github.com/mustafasercansak) üzerinden iletişime geçin.

---

## English

# Contributing to LicenseGuard

Thank you for your interest in improving LicenseGuard. This document explains how to contribute effectively.

---

## Ways to Contribute

- **Bug reports** — open an issue with steps to reproduce, PowerShell version, and OS edition
- **Policy rules** — add or correct entries in `lg-policy.json`
- **EOL database** — update or expand `$eolDatabase` in `LicenseGuard.ps1`
- **New scan modules** — new detection capabilities
- **Documentation** — fix typos, improve examples, translate

---

## Getting Started

```powershell
git clone https://github.com/mustafasercansak/LicenseGuard.git
cd LicenseGuard

# Copy and configure the example config
Copy-Item lg-config.example.json lg-config.json

# Run the tool locally
.\LicenseGuard.ps1 -Lang en

# Validate policy rules without scanning
.\LicenseGuard.ps1 -TestPolicy
```

**Requirements:** PowerShell 5.1+ on Windows. No additional modules required.

---

## Policy Rules (`lg-policy.json`)

Each rule must follow this schema:

```json
{
  "id": "CAT-001",
  "category": "Category Name",
  "pattern": "Software Display Name",
  "matchType": "contains",
  "status": "PROHIBITED",
  "reason": "Why this software is flagged.",
  "alternative": "Suggested replacement (if any)",
  "referenceUrl": "https://vendor-pricing-or-policy-page"
}
```

| Field | Valid values |
|---|---|
| `matchType` | `contains`, `startsWith`, `exact`, `regex` |
| `status` | `ALLOWED`, `REQUIRES_LICENSE`, `PROHIBITED` |

Rules are evaluated against the `DisplayName` field from the Windows registry (`Uninstall` keys). Test your rule with `-TestPolicy` before submitting.

> **Note:** Registry entries with `SystemComponent = 1` (language packs, sub-components) are automatically excluded from the software inventory scan.

---

## Submitting Changes

1. Fork the repository and create a branch: `git checkout -b feat/my-change`
2. Make your changes — keep commits focused and descriptive
3. Test locally: `.\LicenseGuard.ps1 -TestPolicy` and a full scan
4. Open a pull request against `master` with a clear description of what and why

### PR Checklist

- [ ] `lg-config.json` is NOT committed (it is gitignored)
- [ ] `*.html` reports are NOT committed
- [ ] Policy rule IDs follow the existing `CAT-NNN` pattern and are unique
- [ ] No plaintext credentials in any committed file

---

## Code Style

- PowerShell 5.1 compatible — avoid PS 7-only features (e.g., `??`, `ForEach-Object -Parallel`)
- Use `Write-Header` / `Write-Status` for console output
- Sanitize all HTML output through `Encode-Html`
- Keep language strings in both `$L.tr` and `$L.en` blocks

---

## Reporting Security Issues

Do not open a public issue for security vulnerabilities. Contact the maintainer directly via [GitHub](https://github.com/mustafasercansak).
