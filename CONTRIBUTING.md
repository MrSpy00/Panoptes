# Contributing to Panoptes

Panoptes is an open-source, mobile-first, offline-capable OSINT & Biometric Reconnaissance platform focused on Turkish and global public intelligence sources.

## Core Engineering Rules
1. **Free-Only & Zero Paid API Lock-in:** Every reconnaissance module must work without paid API keys and provide a deterministic fallback chain (`Primary -> Fallback 1 -> Fallback 2`).
2. **Privacy-by-Design:** Biometric 192-D face embeddings, EXIF metadata, and investigation histories must remain on-device by default.
3. **Ethical & Legal Compliance (KVKK / GDPR):** Only publicly accessible sources may be queried. Never commit personal data, API keys, `.env` files, or signing keystores.
4. **Testing:** Run `flutter analyze` and `flutter test` before opening a Pull Request.
