# Cifra Band Security Notes

## Current boundaries

- Firebase Admin credentials must never live in this repository.
- Firestore client writes are constrained by `firestore.rules`.
- Cloud Functions use the default Firebase Admin runtime credentials.
- Local emulator credentials should stay outside the project folder.

## Firestore authorization model

- `users/{uid}`: only the owner can create or update their profile.
- `users/{uid}/library/{songId}`: only the owner can read or write saved songs.
- `ministries/{id}`: authenticated users may read ministries for the current invite-code flow; only the ministry admin can update safe public fields.
- `schedules/{id}`: members can read schedules from their own ministry. Only admins can create, delete, approve songs, or edit schedule metadata. Members can only change `suggested_songs`.
- `setlists/{id}`: owners can create, edit, and delete; shared users can read.
- `cifras_globais` and `artist_aliases`: client writes are blocked. Cloud Functions can still write through Firebase Admin.

## Required production follow-ups

- Revoke any Firebase service account key that was ever stored inside the project folder.
- Deploy Firestore rules with `firebase deploy --only firestore:rules`.
- Add Firebase App Check before exposing production Cloud Functions publicly.
- Move invite-code joins to a callable/authenticated Cloud Function when the backend is allowed to change.
- Replace local emulator URLs in the app with environment-specific production URLs when screens/app wiring are allowed to change.
