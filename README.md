<div align="center">

<img src="assets/branding/panoptes_logo.svg" alt="Argos Panoptes — Multi-Eye Geometric Emblem" width="160" height="160" />

# PANOPTES
### Bağımsız On-Device Biyometrik & Açık Kaynak İstihbarat (OSINT) Mobil Platformu
### Standalone On-Device Biometric & Open-Source Intelligence (OSINT) Mobile Platform

<p align="center">
  <a href="#-türkçe-dokümantasyon">
    <img src="assets/branding/flag_tr.svg" alt="TR" width="22" valign="middle" /> <b>Türkçe Dokümantasyon (Tam Rehber)</b>
  </a>
  &nbsp;&nbsp;|&nbsp;&nbsp;
  <a href="#-english-documentation">
    <img src="assets/branding/flag_en.svg" alt="EN" width="22" valign="middle" /> <b>English Documentation (Full Guide)</b>
  </a>
</p>

![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Desktop-E11D48?style=flat-square)
![Architecture](https://img.shields.io/badge/Mimari-100%25%20Edge%20%2B%20Optional%20Supabase-BE123C?style=flat-square)
![API Cost](https://img.shields.io/badge/API%20Cost-0%24%20%28Zero%20Paid%20APIs%29-10B981?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-F4F4F5?style=flat-square)

</div>

---

# <img src="assets/branding/flag_tr.svg" alt="TR" width="28" valign="middle" /> Türkçe Dokümantasyon

## 1. Vizyon & Mitolojik Köken (Argos Panoptes)

**Panoptes** (Yunanca: *Πανόπτης*, *"Her Şeyi Gören"*), Yunan mitolojisinde Hera'nın hizmetinde olan, bazıları uyurken diğerleri nöbet tutan **yüz gözlü uyanık dev bekçi Argos Panoptes**'ten ilham alır.

Uygulamanın merkezindeki özel üretim **9-gözlü geometrik SVG amblemi** ([`assets/branding/panoptes_logo.svg`](assets/branding/panoptes_logo.svg)) ve **3-gözlü kompakt ikonu** ([`assets/branding/panoptes_icon.svg`](assets/branding/panoptes_icon.svg)):
- **Simsiyah (`#000000`) Obsidian** arka plan üzerinde,
- Merkezde keskin geometrik konturlu, **Bordo-Kırmızı (`#E11D48` / `#9F1239`)** irisli ve dikey yarık pupilli ana göz,
- Çevresinde farklı boyutlarda, farklı opaklıklarda (derinlik hissi) ve hafif farklı açılara bakan **8 uydu göz** ile tasarlanmıştır.

**Hedef:** Herhangi bir ücretli API anahtarına, sürekli açık bir sunucuya veya harici GPU'ya (RTX 5070 Ti vb.) ihtiyaç duymadan; **tamamen telefon üzerinde (Standalone Edge / Offline-First)** çalışan, fotoğraf + kimlik bilgileriyle en derin herkese açık (Public) OSINT taramasını gerçekleştiren açık kaynaklı mobil istihbarat platformu sunmak.

---

## 2. Temel İlkeler

1. **Mobile-First & Offline-Capable:** Yüz tespiti, 192-boyutlu biyometrik yüz vektörü (embedding) çıkarımı, EXIF/JFIF adli bilişim analizi, dork üretimi ve yerel sonuç önbelleği (Vault) %100 cihaz üzerinde çalışır.
2. **Sıfır Ücretli API (Free-Only):** Ücretli yüz arama (PimEyes vb.) veya ücretli veri sağlayıcıları kullanılmaz; tamamen ücretsiz açık uç noktalar, DNS-over-HTTPS, şeffaf API'ler ve cihaz içi hesaplama kullanılır.
3. **Çok Katmanlı Fallback Zinciri:** Her istihbarat modülü birincil yöntem başarısız olduğunda veya ağ kısıtlandığında otomatik olarak `Fallback 1` ve `Fallback 2` katmanlarına geçer.
4. **Privacy by Design (Tasarımda Gizlilik):** Biyometrik yüz vektörleri (`192-D L2-Normalized Float Vector`) ve fotoğraflar varsayılan olarak telefondan dışarı çıkmaz.
5. **Türkiye Öncelikli + Global Kapsama:** Türkiye'ye özgü kamu/kurum arşivleri, sözlükler ve forumlar birinci sınıf modül olarak entegre edilmiştir.
6. **Çift Tema & SVG Bayraklı Çoklu Dil:** Hem **Obsidian Koyu (`#000000`)** hem de **Yüksek Kontrastlı Açık Tema (`#FFFFFF` / `#F3F4F6`)** desteği ile SVG Türk Bayrağı (<img src="assets/branding/flag_tr.svg" width="16" />) ve İngiliz Bayrağı (<img src="assets/branding/flag_en.svg" width="16" />) üzerinden anlık Türkçe / İngilizce dil geçişi sunar.

---

## 3. Sistem Mimarisi

```text
[Mobil Uygulama — %100 Bağımsız On-Device Çekirdek]
│
├─ 1. Cihaz İçi Biyometrik Yüz & Görsel Adli Bilişim Motoru
│     ├─ Birincil: Google ML Kit Face Detection (Android/iOS On-Device)
│     ├─ Fallback 1: Pure-Dart YCbCr Cilt Maskesi + Bilateral Simetri Yüz Sezgisel Motoru
│     ├─ Fallback 2: Merkez-Ağırlıklı Biyometrik Portre Kırpımı
│     ├─ 192-D L2-Normalize Biyometrik Embedding + 64-bit dHash / aHash + 24-Bin Histogram
│     └─ EXIF / JFIF / SHA-256 / GPS Koordinat & Kamera Modeli Denetçisi
│
├─ 2. Çoklu Kaynak OSINT & Türkiye İstihbarat Motoru
│     ├─ Ters Görsel Arama: Yandex Images (Öncelikli), Google Lens, Bing Visual, TinEye
│     ├─ Canlı HTTP Yoklamaları: GitHub, GitLab, Keybase, Reddit, HackerNews, Dev.to, Chess.com, Lichess, Wikipedia TR
│     ├─ Otomatik Avatar Yüz Doğrulama: Bulunan sosyal profillerin avatarlarını indirip 192-D yüz vektörüyle karşılaştırma
│     ├─ E-Posta & Telefon: Gravatar SHA-256, Cloudflare DoH MX Kayıtları, keys.openpgp.org, Holehe Matrisi, TR Operatör Tespiti
│     └─ Türkiye Özel: Ticaret Sicili (TTSG), MERSİS, YÖK Akademik, TRABİS (.tr), Ekşi, DonanımHaber, Technopat, SDN, Uludağ, KızlarSoruyor
│
├─ 3. Yerel Kasa (Local Vault) & Raporlama
│     ├─ Cihaz İçi JSON Kasa (Sorgu geçmişi, favori bulgular, çevrimdışı önbellek)
│     ├─ İlişki & Alias Grafiği (Radyal düğüm ağı) + Kronolojik Zaman Çizelgesi
│     ├─ Recursive Pivot Motoru (Derinlik sınırı = 3)
│     └─ Dışa Aktarım: Markdown (.md), JSON (.json) ve Taktiksel PDF (.pdf)
│
└─ 4. (Opsiyonel) Supabase Cloud & Edge Worker Modülü
      ├─ Postgres RLS Şeması (`osint_dossiers`, `osint_jobs`)
      ├─ Deno Edge Function (`osint-worker`) ağır asenkron username/domain taraması
      └─ Docker Compose ile %100 kendi bilgisayarınızda / sunucunuzda self-host imkanı
```

---

## 4. Ücretsiz Yöntemler & Fallback Stratejisi Tablosu

| İhtiyaç | Birincil Yöntem (Primary) | Fallback 1 | Fallback 2 |
| :--- | :--- | :--- | :--- |
| **Yüz Tespiti** | Google ML Kit On-Device | Pure-Dart YCbCr + Simetri Tespiti | Merkez-Ağırlıklı Manuel/Otomatik Kırpım |
| **Ters Görsel Arama** | Yandex Images (Yüz odaklı en güçlü) | Google Lens + Bing Visual Search | TinEye + **WebView Recon Köprüsü** (`<img>` DOM yakalama) |
| **Yüz Doğrulama** | Cihaz İçi `192-D Cosine` + `64-bit dHash` | Sosyal Profil Avatarı Otomatik İndirme & Eşleştirme | Yüz Lab Sekmesinde URL / Galeri / Kamera Doğrulama |
| **Username Tarama** | Cihaz İçi Canlı API/HTTP Yoklama (Sherlock/Maigret mantığı) | Opsiyonel Supabase `osint-worker` Edge Function | Hedefli Dork & WebView Köprüsü |
| **Türkiye Kaynakları** | Özel Kamu/Forum Sorgu & Yoklama Motoru (TTSG, YÖK, Ekşi, DH) | WebView Recon Köprüsü + DOM Ayrıştırma | Google / Yandex / Bing `site:` Operatör Dorkları |
| **E-Posta İstihbaratı** | Gravatar SHA-256 + Cloudflare DoH MX + OpenPGP | Holehe Tarzı Platform Kontrol Matrisi | PGP & Veri İhlali Dorkları |
| **Görsel Metadata** | Cihaz İçi EXIF / TIFF / GPS / SHA-256 Okuyucu | İkili (Binary) JFIF Başlık & Çözünürlük Analizi | — |

---

## 5. Ekranlar & Özellikler

1. **Hedef (`TargetInputTab`):**
   - Kamera veya galeriden fotoğraf yükleme, tek dokunuşla **Sentetik Biyometrik Portre** üretme veya **Örnek Senaryo (`Mustafa Kemal // mka_sec`)** yükleme.
   - Ad Soyad, Kullanıcı Adı/Nick, Doğum Tarihi/Yaş, Şehir/Memleket, E-posta, Telefon, Meslek/Okul/Şirket ve Serbest İstihbarat Notları.
2. **Bulgular (`DossierResultsTab`):**
   - Kategori filtreleri (Yüz & Görsel, Sosyal & Nick, Türkiye Özel, Şirket & Akademik, Forum & Sözlük, Haber & Arşiv, E-Posta & Tel).
   - Minimum güven skoru (`0-95%`) kaydırıcısı ve favori filtreleme.
   - Her bulgu kartında **Güven Skoru**, **Eşleşen Pivot Etiketleri**, **Fallback Katmanı**, **WebView Köprüsü**, **Doğrudan Kaynak** ve **Wayback Machine Arşiv** butonları.
   - Tek dokunuşla **MD**, **PDF** ve **JSON** istihbarat raporu dışa aktarımı.
3. **Yüz Lab (`FaceLabTab`):**
   - Hedef fotoğrafın kırpılmış yüzü, tespit motoru bilgisi, `dHash`, `aHash`, `192-D` vektör önizlemesi.
   - Aday fotoğrafı galeriden, kameradan veya doğrudan URL üzerinden indirip hedef yüzle karşılaştırma (`192-D Cosine`, `64-bit dHash` ve `24-Bin Histogram` skorları).
   - **EXIF / JFIF Adli Bilişim Denetçisi:** `SHA-256` özeti, çözünürlük, kamera marka/model, orijinal tarih ve GPS koordinatları.
4. **Grafik (`RelationshipGraphAndTimelineTab`):**
   - Etkileşimli radyal **İlişki & Alias Grafiği** (düğümlere dokunarak güven skoru ve detay inceleme).
   - **Keşfedilen Yeni Pivotlar (Recursive):** Bulunan yeni kullanıcı adı veya e-postaları tek dokunuşla (`Derinleştir`) hedef profiline ekleyip derinlik sınırı (`3`) dahilinde yeniden tarama.
   - **Kronolojik Zaman Çizelgesi.**
5. **Kasa (`VaultConfigTab`):**
   - Argos Panoptes 9-gözlü SVG amblem ve 48px/24px ikon vitrini.
   - Yerel sorgu geçmişi yönetimi.
   - Opsiyonel Supabase URL/Key bağlantısı ve bulut eşitleme.
   - **Obsidian Koyu / Açık Tema** geçişi ve **SVG Bayraklı (`TR` / `EN`)** dil değiştirici.

---

## 6. Kurulum & Çalıştırma

### Gereksinimler
- Flutter SDK `>= 3.10.0` (Dart `>= 3.10.0`)
- Android Studio / Android SDK (Fiziksel cihaz veya emülatör için)

### Adımlar

```bash
# 1. Repoyu klonlayın
git clone https://github.com/MrSpy00/Panoptes.git
cd Panoptes

# 2. Bağımlılıkları yükleyin
flutter pub get

# 3. Statik analiz ve testleri çalıştırın
flutter analyze
flutter test

# 4. Bağlı Android cihazda (USB veya Kablosuz ADB) çalıştırın
flutter run

# 5. APK paketi üretin
flutter build apk --debug
```

### Opsiyonel Backend (Supabase / Docker) Kurulumu
Uygulama varsayılan olarak **hiçbir sunucu olmadan** çalışır. İsteğe bağlı bulut senkronizasyonu ve Edge Worker için:
```bash
cp .env.example .env
docker compose up -d
```
Veritabanı şeması için [`supabase/migrations/20261115000000_panoptes_schema.sql`](supabase/migrations/20261115000000_panoptes_schema.sql) dosyasını, Edge Function için [`supabase/functions/osint-worker/index.ts`](supabase/functions/osint-worker/index.ts) dosyasını kullanabilirsiniz.

---

## 7. Güvenlik, Etik & KVKK Bildirimi

- **Yalnızca Herkese Açık Kaynaklar:** Panoptes yalnızca halka açık (Public) arama motorlarını, sosyal ağ profillerini ve resmi kamu/akademik dizinleri sorgular.
- **Zorunlu Etik Onay:** Uygulama ilk açılışında kullanıcıya KVKK ve açık kaynak istihbarat sorumluluk bildirimini sunar; onaylanmadan tarama başlatılamaz.
- **Sıfır Telemetri:** Biyometrik yüz embedding vektörleri cihaz dışına gönderilmez ve yerel kasadan istenildiği an tek dokunuşla silinebilir.

---
---

# <img src="assets/branding/flag_en.svg" alt="EN" width="28" valign="middle" /> English Documentation

## 1. Vision & Mythological Origin (Argos Panoptes)

**Panoptes** (Greek: *Πανόπτης*, *"All-Seeing"*) draws inspiration from **Argos Panoptes**, the hundred-eyed primordial giant in Greek mythology who served as a tireless watchman—while some of his eyes slept, the others remained wide awake.

The custom-crafted **9-eye geometric SVG emblem** ([`assets/branding/panoptes_logo.svg`](assets/branding/panoptes_logo.svg)) and **3-eye compact icon** ([`assets/branding/panoptes_icon.svg`](assets/branding/panoptes_icon.svg)) feature:
- A pitch-black **Obsidian (`#000000`)** canvas,
- A central sharp geometric eye with a **Crimson-Burgundy (`#E11D48` / `#9F1239`)** iris ring and vertical slit pupil,
- **8 surrounding geometric satellite eyes** at varied scales, opacities (creating depth), and gaze vectors.

**Objective:** Deliver the deepest possible public Open-Source Intelligence (OSINT) and biometric face verification mobile platform that runs **100% standalone on-device (Edge / Offline-First)** with **zero paid APIs** and no mandatory server or desktop GPU dependency.

---

## 2. Core Principles

1. **Mobile-First & Offline-Capable:** Face detection, 192-dimensional biometric embedding extraction, EXIF/JFIF binary forensics, dork generation, and local vault caching run natively on the handset.
2. **Free-Only (Zero Paid APIs):** Relies strictly on public endpoints, DNS-over-HTTPS, public APIs, and client-side computation—never requiring paid services.
3. **Resilient Fallback Chains:** Every reconnaissance capability degrades gracefully across 3 tiers (`Primary` -> `Fallback 1` -> `Fallback 2`).
4. **Privacy by Design:** Biometric face embeddings (`192-D L2-Normalized Float Vector`) remain on the device by default and can be wiped at any time.
5. **Turkey-First + Global Coverage:** First-class modules for Turkish public registries, academic directories, dictionaries, and forums alongside global platforms.
6. **Dual Theme & SVG Flag Localization:** Instant switching between **Obsidian Dark (`#000000`)** and **High-Contrast Light (`#FFFFFF` / `#F3F4F6`)** themes, plus instant Turkish (<img src="assets/branding/flag_tr.svg" width="16" />) and English (<img src="assets/branding/flag_en.svg" width="16" />) language switching with custom SVG flags.

---

## 3. Architecture Overview

```text
[Mobile Application — 100% Standalone On-Device Core]
│
├─ 1. On-Device Biometric Face & Image Forensics Engine
│     ├─ Primary: Google ML Kit Face Detection (Android/iOS On-Device)
│     ├─ Fallback 1: Pure-Dart YCbCr Skin-Mask + Bilateral Symmetry Heuristic Detector
│     ├─ Fallback 2: Center-Weighted Biometric Portrait Crop
│     ├─ 192-D L2-Normalized Biometric Embedding + 64-bit dHash / aHash + 24-Bin Histogram
│     └─ EXIF / JFIF / SHA-256 / GPS Coordinate & Camera Make/Model Inspector
│
├─ 2. Multi-Source OSINT & Turkey Reconnaissance Engine
│     ├─ Reverse Image Matrix: Yandex Images (Primary), Google Lens, Bing Visual, TinEye
│     ├─ Live HTTP Probes: GitHub, GitLab, Keybase, Reddit, HackerNews, Dev.to, Chess.com, Lichess, Wikipedia TR
│     ├─ Automated Avatar Face Verification: Downloads discovered social avatars and scores against target 192-D vector
│     ├─ Email & Phone Recon: Gravatar SHA-256, Cloudflare DoH MX Records, keys.openpgp.org, Holehe Matrix, TR Carrier Prefix
│     └─ Turkey Modules: Trade Registry (TTSG), MERSIS, YOK Academic, TRABIS (.tr), Eksi, DonanimHaber, Technopat, SDN, Uludag, KizlarSoruyor
│
├─ 3. Local Vault & Tactical Reporting
│     ├─ Local JSON Vault (Investigation history, bookmarked findings, offline cache)
│     ├─ Interactive Radial Relationship & Alias Graph + Chronological Timeline
│     ├─ Recursive Pivot Engine (Depth limit = 3)
│     └─ Export Formats: Markdown (.md), JSON (.json), and Tactical PDF (.pdf)
│
└─ 4. (Optional) Supabase Cloud & Edge Worker Module
      ├─ Postgres RLS Schema (`osint_dossiers`, `osint_jobs`)
      ├─ Deno Edge Function (`osint-worker`) for asynchronous batch enumeration
      └─ Self-hostable via `docker-compose.yml`
```

---

## 4. Free Methods & Fallback Strategy Matrix

| Capability | Primary Method | Fallback 1 | Fallback 2 |
| :--- | :--- | :--- | :--- |
| **Face Detection** | Google ML Kit On-Device | Pure-Dart YCbCr + Symmetry Heuristic | Center-Weighted Portrait Crop |
| **Reverse Image** | Yandex Images (Strongest free face engine) | Google Lens + Bing Visual Search | TinEye + **WebView Recon Bridge** (`<img>` DOM capture) |
| **Face Verification** | On-Device `192-D Cosine` + `64-bit dHash` | Automated Social Avatar Download & Match | Manual URL / Gallery / Camera Check in Face Lab |
| **Username Recon** | Client-Side Live API/HTTP Probes (Sherlock/Maigret style) | Optional Supabase `osint-worker` Edge Function | Targeted Search Dorks & WebView Bridge |
| **Turkey Sources** | Custom Public Registry & Forum Probes (TTSG, YOK, Eksi, DH) | WebView Recon Bridge + DOM Parser | Google / Yandex / Bing `site:` Dorks |
| **Email Recon** | Gravatar SHA-256 + Cloudflare DoH MX + OpenPGP | Holehe-Style Platform Matrix | PGP & Paste/Breach Dorks |
| **Image Metadata** | On-Device EXIF / TIFF / GPS / SHA-256 Reader | Binary JFIF Header & Dimension Parser | — |

---

## 5. Getting Started

```bash
# 1. Clone the repository
git clone https://github.com/MrSpy00/Panoptes.git
cd Panoptes

# 2. Install Flutter dependencies
flutter pub get

# 3. Run static analysis & widget/unit test suite
flutter analyze
flutter test

# 4. Run on a connected device (USB or Wireless ADB)
flutter run

# 5. Build APK
flutter build apk --debug
```

---

## 6. Ethics, Legal & Privacy Notice

- **Public Sources Only:** Panoptes queries only publicly accessible search engines, public social profiles, and official public registries.
- **Mandatory Consent Gate:** Users must review and accept the ethical and legal data-processing notice (KVKK / GDPR) upon first launch.
- **MIT License:** Open-source under the [MIT License](LICENSE). See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md) for details.
