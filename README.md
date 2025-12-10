# SurakshaX — Encrypted Password Manager (Flutter)

SurakshaX is a Flutter password manager focused on strong client-side encryption, secure sharing, and a polished Material 3 experience. The app keeps secrets local to the device/browser and lets users exchange entries via encrypted share codes that only decrypt with the same master token.

## Core Capabilities
- Master token protects all secrets; stored in `flutter_secure_storage` on mobile/desktop and `SharedPreferences` on web.
- Optional PIN (SHA-256 hashed) and biometric unlock via `local_auth`.
- AES-256-CBC + PKCS7 encryption using a PBKDF2 (HMAC-SHA256, 20k iterations, 256-bit) key derived from the master token.
- Full CRUD for password entries with categories, tags, hints, descriptions, and 2FA backup code storage.
- Secure sharing: generates `PM2:` base64 payloads with per-field encryption; recipients import and decrypt with their master token.
- Filtering and search across title/email/website/tags; summary stats for entries, categories, tags, and 2FA coverage.

## Security Model (at a glance)
- **Key derivation:** Master token → PBKDF2 (HMAC-SHA256, 20k iterations, salt `password_manager_salt`) → AES-256 key.
- **Encryption:** AES-256-CBC with random 16-byte IVs; PKCS7 padding. Each password (and shared fields) carries its own IV.
- **Storage:** Encrypted entries + metadata persisted in `SharedPreferences`; master token stored in secure storage when available.
- **PIN:** Stored as SHA-256 hash; used only for local unlock. Master token is still required for decryption.
- **Biometrics:** Delegated to platform via `local_auth` where supported.
- **Sharing:** `PM2:` payload = base64-encoded JSON; all sensitive fields encrypted. Legacy JSON format still supported on import.
- **Scope:** Data lives on-device/in-browser; no server sync is included.

## App Flow
- **Startup:** Collect master token (and optional PIN) once, then store securely. Subsequent launches show the lock screen (PIN/biometric).
- **Home/Vault:** List of entries with filters (categories, tags, 2FA). Reveal decrypts the selected entry in-memory only.
- **Create/Edit:** Bottom sheet to add or update entries, tags, and 2FA info; password and 2FA backups are encrypted per entry.
- **Share/Import:** Share produces `PM2:` codes; Import accepts `PM2:` or legacy JSON and decrypts with the current master token.

## Data Model (PasswordEntry)
- Identity: `id`, timestamps (`created_at`, `updated_at`, `password_last_changed_at`).
- Secrets: `encryptedPassword` + `iv`; optional 2FA backup codes + IV.
- Metadata: `username`, `email`, `title`, `website`, `alias`, `category`, `hint`, `description`, `tags`, `is_2fa_enabled`, `two_fa_type`.

## Run & Build
Prereqs: Flutter SDK 3.x, a device/emulator or Chrome (for web), and `flutter doctor` passing.

```sh
flutter pub get           # install dependencies
flutter run               # launch on connected device/emulator
flutter run -d chrome     # run web build locally
flutter build apk         # release Android APK
flutter build ios         # build iOS (codesign/profile required)
flutter build web         # static web build in build/web
```

## Project Layout
- `lib/main.dart` — all UI, state, encryption, storage, and sharing logic.
- `assets/` — app icon and fonts (see `pubspec.yaml`).
- `android/`, `ios/`/`macos/` — platform shims; Android uses Gradle Kotlin DSL.
- `web/` — web entry point and manifest.

## Operational Tips
- Always choose a strong master token; losing it means permanent loss of decryption ability.
- Treat share codes like secrets; only recipients with the same token can decrypt them.
- Use PIN/biometric for convenience, but remember the master token remains the root secret.
- Before distributing, consider additional hardening (app attestation, secure backup/export plan, clipboard hygiene, lock timeouts).

## Documentation
- End-user walkthrough and sharing guide: `USER_GUIDE.md`.
