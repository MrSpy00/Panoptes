# Security & Anti-Reverse-Engineering Policy

## Privacy & Local Data Isolation
- **On-Device Biometrics:** 192-D facial embedding vectors and perceptual hashes (`dHash64` / `aHash64`) are computed strictly in memory on the user's device.
- **No Secret Leakage:** `.gitignore` strictly blocks `.env*`, `*.jks`, `*.keystore`, `key.properties`, `google-services.json`, and local databases (`*.db`, `*.sqlite`, `*.isar`).
- **Release Hardening:** Android release builds use R8/ProGuard (`android/app/proguard-rules.pro`) with `allowBackup="false"`, `usesCleartextTraffic="false"`, and stripped verbose logging.

## Reporting Vulnerabilities
Please report security issues responsibly via GitHub Security Advisories on `https://github.com/MrSpy00/Panoptes`.
