# ISAAC PRIVATE VAULT V3 — encrypted sync starter

This version builds on the V2 browser vault. It adds a Supabase account connection and an encrypted-record sync path. The browser encrypts note content, file metadata, and file bytes with AES-GCM before uploading them. Supabase stores ciphertext and a public salt/iteration count; it does not receive the vault master password or a decryption key.

**Status:** source and database policy starter prepared; not deployed or connected to a real Supabase project yet. This is not an audited production password manager.

## What's included

- Black & Gold identity and Blue & White dashboard.
- PBKDF2-HMAC-SHA-256 (600,000 iterations for new vaults) derives a non-extractable AES-256-GCM key.
- Fresh 96-bit random IV per encryption; V3 records authenticate the vault ID, record kind, and record ID as AES-GCM additional authenticated data.
- Encrypted notes, file metadata, and file bytes in IndexedDB.
- Optional Supabase Auth email/password account (separate from the vault master password).
- Supabase Postgres tables with Row Level Security policies for per-user access.
- Per-note/per-file metadata cloud records to reduce lost updates when different devices create different notes concurrently. Simultaneous edits to the same note use last-write-wins timestamps.
- Encrypted backup/restore with password verification before local replacement.
- Five-minute inactivity lock; manual lock remains available.
- A restrictive browser Content Security Policy and pinned Supabase JS v2.119.0 CDN version.
- QR code contains only a random vault ID.

## Important limitations

- Supabase project URL and the user-provided publishable key are configured in `config.js`. This only configures the browser client; account sign-in, cloud sync, and hosting still need to be completed and tested.
- Cloud file sync is limited to 8 MB per file in this starter. Large videos need private object storage and resumable uploads.
- No independent security audit, penetration test, MFA enforcement, account recovery key, or formal disaster-recovery test has been completed.
- If you forget the vault master password, Supabase account password reset cannot decrypt the vault. Keep the password and encrypted backups safe.
- Deleted items are represented by encrypted tombstones so offline devices do not resurrect them. Encrypted file payloads may remain on the server until a later secure garbage-collection feature is implemented.
- V2 legacy ciphertext is still readable locally. Existing V2 vaults keep their original 310,000 PBKDF2 iteration count; new vaults use 600,000.
- GitHub Pages hosts only static files. It is not the database or authentication backend.

## Moving from V2

V3 intentionally reuses the V2 browser database name (`isaacVaultDB`), object store (`records`), and local metadata key (`ipv2_meta`). If V2 and V3 are opened under the same exact website origin, V3 can read the existing encrypted local vault and migrate note IDs/metadata when it is unlocked. GitHub Pages project paths under the same `https://YOUR_GITHUB_USERNAME.github.io` hostname share an origin. If the old and new sites use different hostnames/origins, export a V2 encrypted backup from the old site and restore it in V3. Keep the old copy until V3 has been unlocked and verified.

## A. Create the Supabase backend

1. Create a Supabase project at <https://supabase.com/dashboard> using your own account.
2. Open **SQL Editor → New query**.
3. Open `supabase/schema.sql`, copy the entire file, paste it into SQL Editor, and run it.
4. In **Project Settings → API**, copy the **Project URL** and the **publishable key** (or legacy `anon` key).
5. `config.js` is already populated with the project URL and publishable key supplied by the project owner. If you rotate the publishable key, update that file with the new publishable key only.
   - The publishable/anon key is designed for browser use; Row Level Security is the access boundary.
   - Never use or paste the `service_role` key, database password, or any secret key into `config.js`, GitHub, or this chat.
6. In **Authentication → URL Configuration**, set the Site URL to the final GitHub Pages URL. Add that same URL and its wildcard path to allowed Redirect URLs. If testing before deployment, add `http://localhost:8000/**` as well.
7. In **Authentication → Providers → Email**, keep email confirmation enabled for real use. Confirm the signup email before signing in. Set strong account passwords; enable MFA if available for the project.

## B. Host on GitHub Pages — use a NEW repository

Your recent screenshots show GitHub Pages configured on a repository named `isaac-music-studio` and its URL `isaac-music-studio.github.io`. That is your music-studio project. **Do not replace its `index.html` with this vault app.** Create a separate public repository named `isaac-private-vault` so the two projects remain separate.

1. On GitHub, create a new repository named `isaac-private-vault`.
2. Upload the contents of this V3 folder to the repository root: `index.html`, `config.js`, `README_SETUP.md`, and the `supabase/` folder.
3. Open the new repository's **Settings → Pages**.
4. Under **Build and deployment**, choose **Deploy from a branch**, select `main` and `/(root)`, then Save.
5. Wait for the Pages deployment to finish. The expected project URL shape is `https://YOUR_GITHUB_USERNAME.github.io/isaac-private-vault/` (replace the username with your real GitHub username).
6. Add the exact live URL to Supabase Auth's Site URL and Redirect URLs.
7. Open the HTTPS URL on your phone. Create the local vault, then create/sign in to your cloud account and press **Sync now**.
8. On a second device, open the same URL, sign in to the same cloud account, enter the original vault master password, and press **Sync now**.

## C. Safe first-use sequence

1. Create a vault master password of at least 14 characters. Do not reuse the cloud-account password.
2. Download an encrypted backup before adding important files.
3. Create/confirm your Supabase account and sign in.
4. Press **Sync now** and confirm the success message.
5. On a second device, sign in and unlock with the same vault master password, then sync.
6. Verify a test note and a small test file appear and decrypt correctly on both devices before storing anything important.
7. Keep a separate encrypted backup. Do not delete the original device's data until the second device has been verified.

## D. Local test

From this folder, run a static server (not `file://`):

```bash
python -m http.server 8000
```

Then open `http://localhost:8000/`. Web Crypto requires a secure context; browsers treat localhost as secure for development. Cloud sync still requires a configured Supabase project.

## E. Before calling this production-ready

- Add MFA enforcement and rate-limit/abuse controls for account authentication.
- Move encrypted file blobs to a private Supabase Storage bucket with RLS policies and resumable uploads.
- Add robust concurrent same-note conflict UI and server-side monotonic revisions.
- Add encrypted recovery-key wrapping with a tested recovery ceremony.
- Add data-retention/secure deletion and orphan-blob cleanup.
- Run dependency pinning, CSP/security headers, accessibility checks, browser/device tests, backup restore drills, and an independent security review.

## Official implementation references

- [Supabase JavaScript CDN installation](https://supabase.com/docs/reference/javascript/installing)
- [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase secure frontend data access and publishable keys](https://supabase.com/docs/guides/database/secure-data)
- [Supabase database function security](https://supabase.com/docs/guides/database/functions)


## Current project configuration

- Supabase project URL is configured in `config.js`.
- The publishable key supplied by the owner is configured in `config.js`; publishable keys are intended for browser clients and rely on RLS for data access.
- Never add a Supabase secret key, service-role key, database password, or vault master password to this repository.
- After deploying, configure Supabase Authentication URL settings for the exact GitHub Pages URL before signup/sign-in testing.
