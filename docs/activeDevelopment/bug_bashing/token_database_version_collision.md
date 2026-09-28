# Token database version collision

2026-09-25: Reality Fracture refresh published 962 tokens on main as database
version 7 (c408ed9), but the development branch already bundles version 7 with
older data. The app intentionally offers updates only when the remote version
is strictly greater, so that build cannot discover the new database.

Fix: publish manifest version 8 with the existing verified Reality Fracture
payload. No app release required. Preserve the minimum app version of 1.9.0.
Future refreshes must consider database versions bundled on development/release
branches, as well as main, before choosing the next published version.

Verified: exact live app endpoint serves version 8 after GitHub cache expiry;
962-token payload SHA-256 matches. Published as 131df1b. GitHub Pages deployment
also succeeded. Device acceptance remains unverified; use About > Token Database
> Check for Updates, download, then reopen token search.
