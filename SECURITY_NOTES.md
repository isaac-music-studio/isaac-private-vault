# Security notes and threat boundaries

## Data flow

1. Supabase Auth authenticates an account and issues a session token.
2. The vault master password is processed locally by Web Crypto PBKDF2.
3. AES-256-GCM encrypts note JSON, file metadata JSON, and file bytes in the browser.
4. Only ciphertext is sent to Supabase. The server receives the vault ID, random record IDs, record kinds, timestamps, salt, and KDF iteration count as metadata.
5. Row Level Security binds every vault and record row to `auth.uid()`.

## What this protects against

- A database read-only compromise should expose ciphertext rather than plaintext, assuming the master password is strong and the implementation/runtime is uncompromised.
- One authenticated account cannot read another account's rows through the provided RLS policies.
- AES-GCM detects ciphertext tampering and V3 record swapping through authenticated additional data.

## What this does not protect against

- A compromised phone/browser, malicious browser extension, phishing, weak/reused passwords, keyloggers, or malicious JavaScript served by a compromised hosting account.
- A user who shares the vault master password or leaves an unlocked device unattended.
- Loss of the vault master password. There is no recovery key in this release.
- Metadata leakage: the service can see account identity, vault/record IDs, record kinds, approximate ciphertext sizes, and update times.
- Concurrent edits to the same note: latest timestamp wins. The UI does not yet offer a conflict-resolution screen.

## Operational rules

- Keep Supabase RLS enabled. Never add public policies to these tables.
- Never place `service_role`, database credentials, or private API keys in browser code.
- Use HTTPS only for public hosting.
- Treat the public GitHub repository as readable by everyone. Only the Supabase publishable/anon key belongs in `config.js`.
- Do not describe this project as audited, zero-risk, or production-ready until independent review and recovery/restore tests are complete.
