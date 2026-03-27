# LicenseGuard Release Notes

---

## v2.0 — 2026-03-27

Bu sürüm, v1.0'a göre büyük bir genişleme içermektedir. Yeni tarama modülleri, kurumsal entegrasyonlar ve otomasyon altyapısı eklenmiştir.

### Yeni Tarama Modülleri

- **Tarayıcı Eklentileri Taraması** — Chrome/Firefox/Edge üzerinde kurulu eklentileri tarar (`ScanBrowserExtensions`)
- **VS Code Eklentileri Taraması** — Kurulu VS Code uzantılarını listeler ve politikaya göre değerlendirir (`ScanVsCodeExtensions`)
- **Başlangıç Programları Taraması** — Sistem başlangıcında çalışan programları denetler (`ScanStartup`)
- **Aktif Process Taraması** — Yasaklı süreçlerin çalışıp çalışmadığını kontrol eder
- **Dijital İmza Doğrulama** — Yürütülebilir dosyaların dijital imzalarını doğrular (`-CheckSignatures`)
- **EOL / Destek Sonu Taraması** — 27 yazılım/platform için yerleşik EOL veritabanı ile destek süresi dolmuş ürünleri tespit eder

### Yeni CLI Parametreleri

| Parametre | Açıklama |
|---|---|
| `-ExportCsv <dosya>` | Sonuçları CSV olarak dışa aktarır |
| `-ExportJson <dosya>` | Sonuçları JSON olarak dışa aktarır |
| `-SarifPath <dosya>` | SARIF formatında güvenlik raporu üretir |
| `-SendMail` | Tarama sonrası e-posta raporu gönderir |
| `-ComputerName <makine>` | WinRM ile uzak makineyi tarar |
| `-NoDelta` | Önceki tarama ile karşılaştırmayı devre dışı bırakır |
| `-TestPolicy` | Politika kurallarını veri toplamadan test eder |
| `-CheckSignatures` | Dijital imza doğrulamasını etkinleştirir |
| `-CreateJiraIssues` | Uyumsuzluklar için otomatik Jira ticket açar |
| `-NoUpdateCheck` | Sürüm güncelleme kontrolünü atlar |

### Bildirim ve Entegrasyon

- **E-posta (SMTP)** — SSL destekli SMTP üzerinden HTML rapor gönderimi
- **Microsoft Teams Webhook** — Tarama özeti Teams kanalına gönderilir
- **Slack Webhook** — Tarama özeti Slack kanalına gönderilir
- **Jira Entegrasyonu** — `-CreateJiraIssues` ile bulunan ihlaller otomatik olarak Jira'ya kaydedilir

### Delta / Snapshot Sistemi

- Tarama sonuçları `lg-snapshot.json` dosyasına kaydedilir
- Sonraki taramada yeni ihlaller ve çözülen sorunlar ayrıca raporlanır
- HTML rapor üzerinde "Değişiklikler" paneli ile görselleştirilir

### Uzak Makine Taraması

- `-ComputerName` parametresi ile WinRM üzerinden uzak Windows makineler taranabilir
- Uzak makinenin kayıt defteri ve yazılım envanteri yerel tarama ile aynı modüllerde işlenir

### Yeni Konfigürasyon Seçenekleri (`lg-config.json`)

```json
{
  "Whitelist": ["InternalTool", "CompanyApp"],
  "SnapshotPath": ".\\lg-snapshot.json",
  "EolCheck": true,
  "ScanBrowserExtensions": true,
  "ScanVsCodeExtensions": true,
  "ScanStartup": true,
  "Email": { ... },
  "Webhook": { "Type": "teams|slack", "Url": "..." },
  "Jira": { "BaseUrl": "...", "Project": "IT", ... },
  "Branding": { "CompanyName": "Acme Corp", "PrimaryColor": "#3b82f6" }
}
```

### HTML Rapor İyileştirmeleri

- Navigasyon menüsüne yeni bölümler eklendi: Takvim, Tarayıcı Eklentileri, VS Code, Başlangıç, Aktif Processler, İmza
- Rapor üzerinden **CSV**, **JSON** ve **PDF** dışa aktarım butonları
- Delta paneli: yeni ihlaller ve çözülen sorunlar öne çıkarılır
- Whitelist kapsamındaki yazılımlar "ONAYLANMIŞ" olarak etiketlenir
- Kurumsal markalaşma: şirket adı ve renk özelleştirme

### Otomasyon

- **`Register-LicenseGuardTask.ps1`** — Windows Görev Zamanlayıcısı'na LicenseGuard'ı kaydeder
  - Varsayılan: her gün 07:00, SYSTEM hesabıyla çalışır
  - `-Remove` parametresi ile görev kaldırılabilir

### Düzeltmeler ve İyileştirmeler

- Konfigürasyon yükleme `$null` kontrolüne geçirildi; `0` veya `$false` değerler artık doğru işlenir
- HTML çıktısında `Encode-Html` fonksiyonu ile XSS güvenliği sağlandı
- Konsol çıktısı `Write-Header` ve `Write-Status` yardımcı fonksiyonları ile standartlaştırıldı

---

## v1.0 — 2026-03-26

İlk sürüm.

- 5 tarama modülü: Windows Aktivasyon, Yazılım Envanteri, FlexLM, SaaS, Politika Kontrolü
- 79 politika kuralı, 16 kategori
- TR/EN ikidilli HTML rapor (karanlık tema, arama, sıralama, filtreleme)
- PS 5.1 `Where-Object` tek sonuç `Count` hatası düzeltmesi
