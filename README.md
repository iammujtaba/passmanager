# Password Manager App

A Flutter password manager featuring AES-256 encryption, secure sharing, token-driven decryption, and biometric/PIN locking.

## Highlights
- Collects a master token on first launch and stores it in `flutter_secure_storage` (or SharedPreferences on web).
- Optional PIN fallback plus biometric unlock via `local_auth`.
- Encrypts/decrypts passwords with AES-256 (CBC + PKCS7) using a PBKDF2-derived key.
- Shares encrypted JSON payloads that recipients can decrypt with the same token.
- Full CRUD for credentials with inline reveal, share, and delete actions.

## How to Run
1. Install Flutter SDK (>=3.0) and ensure `flutter doctor` passes.
2. Fetch dependencies:
   ```sh
   flutter pub get
   ```
3. Launch the app:
   ```sh
   flutter run
   ```

## Security Notes
- Choose a strong master token and never share it publicly.
- Verify the source of any shared JSON payload before importing.
- This sample targets demo scenarios; apply additional hardening and penetration testing for high-risk environments.
