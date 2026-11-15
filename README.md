<div align="center">
  <img src="assets/branding/panoptes_logo.svg" width="160" height="160" alt="Panoptes Logo" />
  <h1>PANOPTES</h1>
  <p><strong>Mobile-First, Offline/Edge-Capable Biometric & Identity OSINT Platform (Turkey + Global)</strong></p>
  <p>
    <img src="https://img.shields.io/badge/Flutter-3.47%2B-E11D48?style=flat-square&logo=flutter" alt="Flutter" />
    <img src="https://img.shields.io/badge/Engine-On--Device%20192--D%20Face%20%2B%20OSINT-BE123C?style=flat-square" alt="Engine" />
    <img src="https://img.shields.io/badge/License-MIT-10B981?style=flat-square" alt="License" />
  </p>
</div>

---

## Genel Bakış (Overview)

**Panoptes** (*Yunanca Πανόπτης — "her şeyi gören"*), tamamen telefon üzerinde bağımsız (standalone) çalışabilen, ücretli API gerektirmeyen, **Türkiye + Global** açık kaynak istihbarat (OSINT) ve cihaz içi biyometrik yüz doğrulama platformudur.

### Temel İlkeler
- **Mobile-First & Offline-Capable:** Yüz tespiti (Google ML Kit + saf Dart krominans/simetri motoru), 192-boyutlu biyometrik yüz embedding çıkarımı, kosinüs benzerliği (`0–100%`) ile aday görsel doğrulama, 64-bit `dHash`/`aHash` ve EXIF/GPS adli analizi tamamen cihaz üzerinde çalışır.
- **Ücretsiz & Çok Katmanlı Fallback Zinciri:** Her istihbarat modülü birden fazla katmanla (`Birincil -> Fallback 1 -> Fallback 2`) çalışır. Uygulama içi **WebView Recon Köprüsü** ile Yandex, Google Lens, Bing Visual Search ve TinEye üzerinde DOM görsel/link yakalama ve tek dokunuşla yüz karşılaştırma yapılabilir.
- **Türkiye Odaklı Derin Kapsama (`TR-OSINT`):** Türkiye Ticaret Sicili Gazetesi (TTSG), MERSİS, Resmi Gazete, YÖK Akademik, Ulusal Tez Merkezi, DergiPark, TRABİS `.tr` (`cloudflare-dns` DoH canlı sorgu), Ekşi Sözlük, DonanımHaber, Technopat Sosyal, ShiftDelete, Uludağ/İnci Sözlük, KızlarSoruyor ve ulusal basın arşivleri.
- **Privacy by Design:** Yüz vektörleri ve sorgu geçmişi varsayılan olarak cihaz dışına çıkmaz. Opsiyonel Supabase şeması ve Edge Function (`supabase/`) sadece kullanıcı kendi sunucusunu bağlamak isterse devreye girer.

---

## Mimari Akış (Architecture)

```text
[Panoptes Mobil Uygulama (Flutter + Riverpod)]
│
├── 1. Cihaz İçi Yüz & Görsel Adli Bilişim (On-Device)
│   ├── Google ML Kit Face Detection -> Fallback 1: YCbCr/Symmetry -> Fallback 2: Portre Crop
│   ├── 192-D L2-Normalized Biometric Embedding + 64-bit dHash / aHash + 24-Bin Histogram
│   ├── EXIF / JFIF / GPS Koordinat & SHA-256 Bütünlük Analizi
│   └── Ters Görsel Arama (Yandex -> Google Lens -> Bing Visual -> TinEye + WebView DOM Bridge)
│
├── 2. Kimlik, Username & E-Posta İstihbaratı
│   ├── Canlı API / İmza Yoklaması (GitHub + Otomatik Avatar Yüz Doğrulama, GitLab, Keybase, Reddit, HN, Dev.to, Vikipedi TR vb.)
│   ├── E-Posta: Gravatar MD5/SHA256 + Cloudflare DoH (MX/SPF) + OpenPGP + Holehe Matrisi
│   └── Telefon: Türkiye Operatör Prefix Analizi (Turkcell / Vodafone / Türk Telekom / NetGSM) + E.164 Dork
│
├── 3. Türkiye Özel Kaynaklar (TR-OSINT)
│   ├── Ticaret Sicili Gazetesi, MERSİS, Resmi Gazete
│   ├── YÖK Akademik, YÖK Ulusal Tez Merkezi, DergiPark
│   ├── TRABİS (.com.tr / .tr) Canlı DNS-over-HTTPS A Kaydı Kontrolü
│   └── Ekşi Sözlük, DonanımHaber, Technopat, SDN, Uludağ, KızlarSoruyor, Şikayetvar, R10
│
├── 4. Korelasyon, İlişki Grafiği & Raporlama
│   ├── 0–100 Güven Skoru + Wayback Machine Arşiv Köprüsü
│   ├── İnteraktif İlişki / Alias Grafiği & Kronolojik Zaman Çizelgesi
│   ├── Recursive Pivot Motoru (Derinlik Sınırı: 3)
│   └── Dışa Aktarım: Markdown (.md) / PDF Dosyası (.pdf) / JSON (.json)
│
└── 5. (Opsiyonel) Supabase Cloud & Edge Worker
    ├── supabase/migrations/20261115000000_panoptes_schema.sql
    └── supabase/functions/osint-worker/index.ts
```

---

## Ücretsiz Yöntemler & Fallback Stratejisi

| İhtiyaç | Birincil Yöntem | Fallback 1 | Fallback 2 |
| :--- | :--- | :--- | :--- |
| **Yüz Tespiti** | Google ML Kit (On-Device) | On-Device YCbCr + Simetri | Merkez Portre Kırpma |
| **Reverse Image** | Yandex Görsel (Yüz Öncelikli) | Google Lens + Bing Visual | TinEye + WebView DOM Yakalama |
| **Yüz Doğrulama** | 192-D Cosine + dHash64 + Histogram | Ters Görsel Sonuç Korelasyonu | Yüz Laboratuvarı Manuel Karşılaştırma |
| **Username** | Cihaz İçi Maigret/Sherlock Yoklama | Opsiyonel Supabase Edge Worker | Sosyal Ağ Dork + WebView |
| **Türkiye Forumları** | Doğrudan Profil/Slug Yoklama | WebView Köprüsü + DOM Parse | Hedefli Site Dorkları |
| **E-Posta & Domain** | Gravatar + Cloudflare DoH (MX/A) | OpenPGP + GitHub Commit Arama | Belge (PDF/DOCX) Dorkları |
| **Metadata** | On-Device EXIF + GPS + SHA-256 | İkili Başlık & Çözünürlük Analizi | - |

---

## Kurulum & Çalıştırma (Quick Start)

```bash
# Bağımlılıkları yükle
flutter pub get

# Testleri çalıştır
flutter test

# Bağlı Android cihazda (Kablosuz ADB veya USB) çalıştır
flutter run
```

---

## Etik Kullanım ve Yasal Uyarı (KVKK / Legal Notice)

Panoptes yalnızca **herkese açık kaynakları (OSINT)** sorgular ve biyometrik hesaplamaları yerel cihazda yürütür. 6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK) ve ilgili mevzuat kapsamında kişisel verilerin işlenmesi ve kullanım amacı tamamen kullanıcının kendi sorumluluğundadır. Yalnızca yetkili güvenlik araştırmaları, kurumsal denetim ve açık kaynak istihbarat doğrulamaları için kullanılmalıdır.
