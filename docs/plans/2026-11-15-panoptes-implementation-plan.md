# Panoptes OSINT Mobile Platform Implementation Plan

> **For Agent:** Complete end-to-end implementation of the Panoptes Mobile OSINT Platform.

**Goal:** Build and deploy Panoptes, an offline-first, zero-cost-API, Turkey + Global mobile OSINT investigation platform in Flutter with on-device face detection, 192-D biometric embedding & perceptual hash verification, EXIF forensics, 4-engine reverse image recon + WebView bridge, 35+ platform username/email/phone recon, Turkish OSINT modules, confidence scoring, relationship graph, chronological timeline, recursive pivot discovery, Markdown/PDF/JSON export, and optional Supabase cloud sync/worker.

**Architecture:** Clean modular feature-first architecture using Flutter 3.47+ (Dart 3.13+), Riverpod state management, SQLite/local encrypted-ready persistence, Google ML Kit Face Detection + pure-Dart 192-D Biometric Feature & Perceptual Hash (aHash/dHash/Histogram) engine, native HTTP + DNS-over-HTTPS + Wayback CDX API + WebView Hybrid Recon Engine, and bundled Supabase SQL migrations & Edge Function worker.

**Tech Stack:** Flutter, Dart, Riverpod (`flutter_riverpod`), Google ML Kit (`google_mlkit_face_detection`), `image_picker`, `image`, `exif`, `crypto`, `http`, `flutter_svg`, `pdf`, `printing`, `share_plus`, `url_launcher`, `path_provider`, `shared_preferences`, `webview_flutter`.

---

### Task 1: Project Scaffolding, Security Hardening & `.gitignore`
- Initialize Flutter project in `x:\mrspy\ActiveProjects\Panoptes` (`com.aegissoft.panoptes`).
- Configure strict `.gitignore` preventing any credential, keystore, `.env`, local db, or debug symbol leakage.
- Configure Android permissions (`INTERNET`, `CAMERA`, `READ_MEDIA_IMAGES`) and ProGuard/R8 anti-reverse-engineering obfuscation rules (`android/app/proguard-rules.pro`).

### Task 2: Argos Panoptes Geometric Multi-Eye SVG Assets & Custom Painter
- Create `assets/branding/panoptes_logo.svg` (Obsidian `#000000` canvas, sharp geometric central eye with Crimson-Burgundy `#E11D48`/`#9F1239` iris and razor pupil, surrounded by 8 geometric eyes of varying sizes, gaze vectors, and stroke opacities).
- Create `assets/branding/panoptes_icon.svg` (Simplified 3-eye emblem for 24px/48px icons).
- Build `lib/core/widgets/panoptes_logo.dart` with animated/static multi-eye `CustomPainter` + SVG rendering support.

### Task 3: Core Tactical Crimson-Obsidian Design System & Localization (TR + EN)
- Create `lib/core/theme/panoptes_theme.dart` (Obsidian `#000000` dark theme + Tactical Slate light theme, Crimson-Burgundy `#E11D48` / `#BE123C` / `#881337` accents, zero AI-slop sharp 1px bordered tactical cards, thumb-zone controls >= 48dp).
- Create `lib/core/l10n/app_strings.dart` supporting complete Turkish (default) and English localization.

### Task 4: Domain Models, Scoring Engine & Recursive Pivot Detector
- Create `lib/features/osint/domain/models/osint_models.dart`:
  - `TargetProfile` (photo path, full name, birth date/age range, city/hometown, username, email, phone, occupation/school/company, notes, investigation depth).
  - `FaceAnalysisResult` (bounding boxes, head Euler angles, landmarks, 192-D normalized biometric embedding vector, 64-bit dHash, 64-bit aHash, RGB/HSV histogram, quality score).
  - `ExifForensicReport` (camera make/model, GPS lat/lng + maps URL, original timestamp, software, resolution, SHA-256 digest, privacy risk flags).
  - `OsintFinding` (id, category, sourceName, title, subtitle, url, archiveUrl, confidenceScore `0-100`, matchedFields, timestamp, metadata, isFavorite, faceSimilarity, fallbackUsed).
  - `DiscoveredPivot` (type: username/email/domain/location/company/alias, value, sourceFindingId, confidence, depth).
  - `InvestigationSession` (id, createdAt, target, faceAnalysis, exifReport, findings, pivots, timelineEvents, graphNodes, graphEdges, status).

### Task 5: On-Device Face Pipeline, Biometric Embedding & EXIF Forensics
- Create `lib/features/osint/services/face_forensics_service.dart`:
  - Primary: Google ML Kit Face Detection (`google_mlkit_face_detection`) on Android/iOS with landmark & contour extraction.
  - Fallback 1: Pure-Dart multi-region luminance/chrominance face crop & symmetry detector.
  - Fallback 2: Manual interactive crop support.
  - On-Device 192-D Biometric Embedding Extractor (spatial grid Gabor/gradient orientation + L2 normalization + 64-bit dHash + perceptual color distribution) enabling real cosine similarity comparison (`compareEmbeddings`) between target photo and candidate reverse-image results.
  - Deep EXIF & file binary header parser (`exif` + `crypto` SHA-256).

### Task 6: Reverse Image Search & Interactive WebView Recon Bridge
- Create `lib/features/osint/services/reverse_image_service.dart` & `lib/features/osint/presentation/widgets/webview_recon_sheet.dart`:
  - Parallel reverse image intelligence across **Yandex Images** (primary for faces), **Google Lens**, **Bing Visual Search**, and **TinEye**.
  - On-device Candidate Image Verifier: download candidate image URL or pick from WebView/Gallery -> compute 192-D face embedding -> calculate exact Cosine Similarity % against target face.
  - Interactive WebView Recon Sheet with one-tap "DOM Sonuçlarını Yakala (Extract Links)" JS injection and "Görseli Yüz Doğrulamasına Gönder" button.

### Task 7: Identity, Username (Maigret/Sherlock), Email (Holehe), Dork & Turkey OSINT Engine
- Create `lib/features/osint/services/osint_recon_engine.dart`:
  - Live concurrent username enumeration across 30+ platforms with body/status validation + Edge Function/WebView fallbacks.
  - Email recon: DNS-over-HTTPS MX/SPF/DMARC check, Gravatar SHA-256 existence probe, GitHub commit/user API probe, Holehe-style platform verification matrix.
  - Phone recon: Turkish carrier prefix analyzer (`Turkcell`, `Vodafone`, `Türk Telekom`, `NetGSM`), international E.164 normalization, WhatsApp/Telegram/Truecaller/Sync.me dork vectors.
  - Turkey-Focused OSINT (`TR-OSINT`):
    - **Ticaret Sicili Gazetesi & MERSİS & KAP** corporate search & dork probes.
    - **YÖK Akademik & Ulusal Tez Merkezi** researcher/thesis scanner.
    - **Turkish Forums & Dictionaries:** Ekşi Sözlük, Uludağ Sözlük, İnci Sözlük, DonanımHaber, Technopat Sosyal, ShiftDelete, KızlarSoruyor live probes + dork fallback.
    - **`.tr` TRABİS / RDAP / WHOIS** domain registration check (`nic.tr` / RDAP / DNS-over-HTTPS).
    - **Wayback Machine CDX API** live historical snapshot resolver for discovered URLs/domains.

### Task 8: Dossier Export (Markdown, PDF, JSON), Local Vault & Optional Supabase Module
- Create `lib/features/osint/services/export_service.dart` (generates downloadable/shareable PDF dossier with tables & confidence badges, Markdown report, and full JSON dump).
- Create `lib/features/osint/services/local_vault_service.dart` (persists investigation history, favorites, ethical consent state, and optional Supabase endpoint/key settings).
- Create `supabase/migrations/20261115000000_panoptes_schema.sql` and `supabase/functions/osint-worker/index.ts` + `docker-compose.yml` for self-hosted/optional cloud orchestration.

### Task 9: Premium Tactical UI Screens & Verification on Physical Device
- Build Ethical Gate & Onboarding Dialog (`KVKK + Açık Kaynak Etik Bildirimi`).
- Build Target Input Screen (`Hedef Tanımlama` with Photo Scanner, Face Embedding HUD, Turkish City Selector, Identity Pivot Inputs, Demo Target Loader).
- Build Active Scan Progress HUD (real-time fallback chain telemetry log).
- Build Results Dossier Screen:
  - Category Filter Bar + Confidence Score Distribution HUD.
  - Categorized Intelligence Cards with Confidence Gauge, Source Link, Wayback Link, Favorite toggle, and WebView Recon launcher.
  - Face Verification Studio ("Aday Görsel Yüz Karşılaştırma" — compare any found image URL or gallery image against target face embedding).
  - Interactive Force/Radial Relationship & Alias Graph (`CustomPainter` with pan/zoom and node inspection).
  - Chronological Intelligence Timeline.
  - Recursive Pivot Discovery Banner ("Yeni Pivot Bulundu — Derinleştir").
- Run `flutter test`, build & install on wireless ADB device (`192.168.0.160:43793`), verify live execution via ADB screenshot/logcat, commit, and push to `https://github.com/MrSpy00/Panoptes.git`.
