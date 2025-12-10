# SurakshaX User Guide

A practical walkthrough for using SurakshaX to store, protect, and share credentials. Keep this alongside the app; it is device-local only (no cloud sync).

## 1) Quick Start
- Install Flutter runtime/device and run the app (see `README.md` for commands).
- On first launch, set a **master token** (strong passphrase). Optionally add a **PIN** for fast unlock.
- The master token never leaves your device and is required for all decryption.

## 2) Unlocking the Vault
- Default unlock: enter PIN (if set) or tap **Continue** to skip PIN.
- Biometric unlock is available on supported platforms via the system prompt.
- If you forget the master token, you cannot recover existing data.

## 3) Adding Passwords
- Tap **Add Password**.
- Provide any mix of fields: title, username/email, website, alias, category, tags, hint, description.
- Enter the password (required for new entries). A random IV is generated and the value is AES-256 encrypted.
- Optionally enable **Two-factor** and store type plus encrypted backup codes.
- Save to persist locally in encrypted form.

## 4) Viewing & Copying
- Tap an entry to **Reveal**. Decryption happens in-memory only for that session.
- Copy password (or 2FA backups) from the reveal panel. Remember clipboard hygiene on shared machines.

## 5) Editing or Deleting
- Open the entry menu (⋮) → **Edit** to change metadata/password/2FA. New passwords re-encrypt with a fresh IV.
- Choose **Delete** to remove permanently from local storage.

## 6) Searching & Filtering
- Search bar covers title, email, website, alias, category, description, and tags.
- Filter by categories, tags, and 2FA status. Reset filters with the **Reset filters** action.
- Summary chips show counts for entries, 2FA coverage, categories, and tags.

## 7) Sharing Securely
- Open entry menu (⋮) → **Share** to generate a `PM2:` code.
- The code is a base64 JSON payload where each sensitive field is encrypted with your master-token-derived key.
- Send the code through a trusted channel. Anyone without the same master token cannot decrypt.
- **Importing:** Tap the download icon on the home screen → paste the `PM2:` code (or legacy JSON). The app decrypts with your master token and adds the entry.
- After import, the app shows the decrypted password once; it then stores only the encrypted form.

## 8) Two-Factor Backup Handling
- Enable **Two-factor** in the entry form to track 2FA type and (optionally) encrypted backup codes.
- Backup codes are encrypted with the same master-token-derived key and IV per entry.

## 9) Safety Best Practices
- Pick a long, unique master token; do not reuse other passwords.
- Treat share codes as secrets; rotate the master token if you suspect compromise.
- Clear clipboard after copying sensitive data (platform dependent).
- Use PIN/biometric for convenience but remember they do not replace the master token for recovery.
- Periodically export entries by sharing individual items to a secure location if you need an external backup plan.

## 10) Troubleshooting
- **Cannot decrypt/reveal:** Ensure you entered the exact master token used to create the entry.
- **Biometric prompt missing:** Check device support and permissions; tap "Check biometrics" on lock screen.
- **Import fails:** Verify the code starts with `PM2:` or is valid JSON; ensure it was generated with the same master token.

## 11) What Is Stored
- Encrypted entries + metadata in `SharedPreferences`.
- Master token in `flutter_secure_storage` (mobile/desktop) or `SharedPreferences` (web fallback).
- PIN stored as SHA-256 hash; used for local unlock only.

Stay safe: the security of your vault depends entirely on the strength and secrecy of your master token.
