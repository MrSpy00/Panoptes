# Panoptes — Mobile-First Offline/Edge OSINT Platform Design Spec

**Date:** 2026-11-15  
**Codename:** Panoptes (*Argos Panoptes — The All-Seeing Hundred-Eyed Guardian*)  
**Target Platform:** Android & iOS (Flutter 3.47+ / Dart 3.13+, Riverpod, SQLite/SharedPreferences, ML Kit + On-Device Face Embedding Engine, InAppWebView Hybrid Recon Engine, Optional Supabase Sync/Edge Worker)

---

## 1. Intent & Why

Panoptes is a standalone, privacy-first, zero-cost-API mobile OSINT investigation platform engineered with a **Turkey-first + Global** intelligence capability. It allows an investigator or security researcher to start from any combination of a **photograph** and **identity pivots** (full name, username/nick, email, phone, city/hometown, birth year/age range, profession/school/company, freeform notes) and run deep open-source intelligence reconnaissance directly from a mobile phone without requiring a dedicated GPU server or paid API subscriptions.

### Core Principles
1. **Mobile-First & Offline-Capable:** Face detection, face cropping, perceptual hashing (aHash/dHash/pHash), 192-D biometric face embedding extraction & cosine verification, EXIF/JFIF/XMP metadata forensics, dork generation, Turkish/Global recon matrices, correlation scoring, pivot discovery, and report export (Markdown, PDF, JSON) execute 100% on-device.
2. **Free-Only & Multi-Layer Fallback Chains:** Every intelligence module has a deterministic primary method and 2+ fallback layers. When bot-protection (Cloudflare/CAPTCHA) blocks direct HTTP scraping, an integrated **InAppWebView Recon Bridge** allows headless DOM extraction or one-tap Human-in-the-Loop verification and automatic result capture.
3. **Privacy by Design & Anti-Reverse-Engineering Hardening:** Biometric face embeddings and target queries stay in local storage by default. No hardcoded secrets, strict `.gitignore`, R8/ProGuard obfuscation rules, stripped release logs, and explicit KVKK/Ethical OSINT consent gates on first launch.
4. **Tactical Crimson-Obsidian Aesthetic (Zero AI Slop):** Pure `#000000` AMOLED pitch-black canvas, sharp geometric 1px borders (`#1F1F24`), tactical Crimson/Burgundy accent (`#E11D48` / `#BE123C` / `#881337`), monospace telemetry typography, high-density intelligence cards, interactive force-directed relationship graph, chronological timeline, and recursive pivot detection.

---

## 2. Approaches Considered & Selected Architecture

### Approach 1: Fully Autonomous On-Device Core + Optional Supabase Cloud Module *(Selected)*
- **How it works:** All face detection (Google ML Kit + pure-Dart multi-scale geometric/skin-tone/landmark fallback analyzer), 192-D face embedding & cosine similarity + multi-hash (pHash/dHash/color histogram) verification, EXIF forensic parser, 4-engine Reverse Image pipeline (Yandex, Google Lens, Bing Visual Search, TinEye), 35+ platform Username & Email (Maigret/Sherlock/Holehe style) probe engine, Turkish OSINT scrapers (Ticaret Sicili, MERSİS, YÖK Akademik, Ekşi Sözlük, DonanımHaber, Technopat, ShiftDelete, Uludağ Sözlük, KızlarSoruyor, `.tr` TRABİS/WHOIS, News Archives), and Google/Yandex/Bing Dork Generator run natively on the phone. A complete `supabase/` schema + Edge Function worker (`osint-worker`) is bundled and configurable in Settings for optional cloud sync and remote heavy queue execution.
- **Trade-offs:** Slightly larger client codebase, but 100% operational out-of-the-box with zero server cost, offline resilience, and full privacy.

### Approach 2: Cloud-First Supabase Edge Orchestration
- **Why rejected:** Violates the standalone mobile-first / offline-capable principle if the user has no live backend configured.

---

## 3. Visual Identity & Argos Panoptes SVG System

- **Background:** Pure Obsidian Black (`#000000`), Elevated Surface (`#09090C`), Card Surface (`#111116`), Hairline Border (`#22222A`).
- **Primary Accent (Crimson / Burgundy):**
  - Primary Crimson: `#E11D48`
  - Deep Burgundy: `#9F1239`
  - Dark Blood Glow: `#4C0519`
  - High-Signal Text: `#F4F4F6` (Primary), `#A1A1AA` (Secondary), `#52525B` (Muted)
- **Argos Panoptes SVG Emblem (`assets/branding/panoptes_logo.svg` & CustomPainter):**
  - Pure `#000000` canvas.
  - Central sharp geometric eye with precision stroke contours, crimson-burgundy iris (`#E11D48` / `#9F1239`), and razor-thin vertical/geometric pupil.
  - Surrounded by 8 satellite eyes at varied scales, stroke opacities (`0.35` to `0.85` for depth), and subtly offset iris/pupil gaze vectors ("watching every angle").
  - Simplified 3-eye high-contrast variant (`assets/branding/panoptes_icon.svg`) optimized for 24px/48px icons and app launcher badges.

---

## 4. End-to-End Intelligence Modules

1. **Target Acquisition (Input Screen):**
   - Photo capture (Camera) or Gallery pick + interactive face crop/analysis preview.
   - Identity fields: Full Name, Birth Date / Age Range, City / Province / Hometown (81 Turkish provinces quick-filter + freeform), Username / Nick, Email, Phone (`+90` / international normalization), Profession / University / Company, and Freeform Investigation Notes.
   - Preset Demo Target ("Örnek Hedef Yükle") for instant zero-friction testing and verification.

2. **Face & Visual Forensics Pipeline (Fallback-Chained):**
   - **Step 1:** On-device Face Detection (ML Kit Face Detection on mobile with bounding box, head Euler angles, smiling/eye-open probabilities, and facial contours + pure-Dart deterministic fallback).
   - **Step 2:** On-device 192-D Biometric Embedding & Perceptual Fingerprint extraction (L2-normalized feature vector + 64-bit dHash + color-channel histogram) for offline cosine similarity verification (`0.00 - 1.00`).
   - **Step 3:** Deep EXIF / Metadata Forensics (Camera make/model, GPS coordinates + map deep-link, timestamps, software tags, image dimensions, SHA-256 file hash, manipulation indicators).
   - **Step 4:** Parallel Reverse Image Search (Yandex Images priority, Google Lens, Bing Visual Search, TinEye) + Built-in Interactive WebView Recon Bridge with "Capture DOM Results" & "Compare Candidate Face" tools.

3. **Identity, Username & Email Pipeline:**
   - Concurrent multi-platform HTTP probe engine (GitHub, GitLab, Reddit, Medium, Keybase, HackerNews, Dev.to, Mastodon, Gravatar, Linktree, Chess.com, Steam, Roblox, Scratch, Wikipedia, Duolingo, Pastebin, etc.) with status-code + response-body signature matching (eliminates false-positive 200 OK pages).
   - Email intelligence: Domain MX/SPF/DMARC DNS-over-HTTPS (`cloudflare-dns.com` / `dns.google`) verification, Gravatar SHA-256 profile lookup, GitHub commit author search, Holehe-style account registration indicators, and breach/paste dork matrices.
   - Phone intelligence: Turkish operator prefix identification (`53x` Turkcell, `54x` Vodafone, `50x/55x` Türk Telekom, NetGSM), formatting variants (`05xx`, `+905xx`, spaced/dashed) and targeted dorks.

4. **Turkey-Focused OSINT Suite (`TR-OSINT`):**
   - **Corporate & Official:** Ticaret Sicili Gazetesi, MERSİS, KAP (Kamuyu Aydınlatma Platformu), `.tr` TRABİS/RDAP domain availability & WHOIS probe.
   - **Academic:** YÖK Akademik researcher & Ulusal Tez Merkezi query builder + live probe.
   - **Turkish Communities & Forums:** Ekşi Sözlük, DonanımHaber, Technopat Sosyal, ShiftDelete (SDN), Uludağ Sözlük, İnci Sözlük, KızlarSoruyor author/mention scanners + WebView fallback.
   - **News & Archives:** Turkish national/local press dorks + Wayback Machine (`archive.org` CDX API) historical snapshot checker.

5. **Results Presentation, Scoring, Graph & Export:**
   - Categorized intelligence cards (`Yüz & Görsel`, `Sosyal & Username`, `Türkiye Kaynakları`, `Şirket & Akademik`, `Forum & Sözlük`, `Haber & Arşiv`, `Dork & E-Posta`) with `0–100` multi-factor Confidence Score, source link, and one-tap Wayback Archive link.
   - **Recursive Pivot Engine:** Automatically detects newly discovered usernames, emails, domains, or locations inside scan findings (with depth limit `maxDepth = 3`) and offers one-tap "Yeni Pivot ile Derinleştir" re-scan.
   - **Interactive Relationship & Alias Graph:** Force-directed / radial node graph connecting Target -> Faces, Usernames, Emails, Turkish Forums, Corporate Records, and Locations.
   - **Chronological Intelligence Timeline:** Extracts and orders discovered timestamps (EXIF dates, account creation dates, Wayback first-seen dates, news dates).
   - **Export Engine:** Generates structured **Markdown**, **JSON**, and printable **PDF** dossiers via native share sheet or local file save.
   - **History, Favorites & Ethics:** Local SQLite/persisted investigation history, star/bookmark findings, bilingual TR/EN support, Dark/Light tactical theme toggle (Obsidian Crimson default), and mandatory KVKK/Ethics gate.
