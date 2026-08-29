# Cifra Band Security Notes

## Current boundaries

- Firebase Admin credentials must never live in this repository.
- Firebase client config files are intentionally ignored in this public repository.
- Firestore client writes are constrained by `firestore.rules`.
- Push delivery is handled by a private Node.js API outside this Flutter repository.
- Local emulator credentials should stay outside the project folder.

## Firestore authorization model

- `users/{uid}`: only the owner can create or update their profile.
- `users/{uid}/library/{songId}`: only the owner can read or write saved songs.
- `ministries/{id}`: authenticated users may read ministries for the current invite-code flow; only the ministry admin can update safe public fields.
- `schedules/{id}`: members can read schedules from their own ministry. Only admins can create, delete, approve songs, or edit schedule metadata. Members can only change `suggested_songs`.
- `setlists/{id}`: owners can create, edit, and delete; shared users can read.
- `cifras_globais` and `artist_aliases`: client writes are blocked. Cloud Functions can still write through Firebase Admin.

## GitHub hardening

- Keep the repository private until Firebase API keys are rotated/restricted and App Check is enforced.
- Do not commit `.env`, service account JSON files, Firebase generated client configs, keystores, signing keys, tokens, screenshots of dashboards, or Render environment values.
- After accidental exposure, rewrite the repository history and rotate/restrict the exposed Firebase keys.
- Enable GitHub secret scanning and Dependabot alerts in the repository settings.

## Required production follow-ups

- Restrict Firebase Web/API keys by Android package name plus SHA certificate and iOS bundle ID.
- Enable Firebase App Check for Firestore, Cloud Functions/API surfaces and other supported Firebase products.
- Add server-side authentication and rate limiting to the Render notification API before opening broader testing.
- Deploy Firestore rules with `firebase deploy --only firestore:rules`.
- Move invite-code joins to a callable/authenticated backend flow when the backend is allowed to change.
