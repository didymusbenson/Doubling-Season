# Remote token database drops 1.11 artist credits

Status: fixed and published as database v9 on 2026-09-26 (UTC manifest date
2026-09-27). Original reproduction: iOS simulator, 1.11.0+19 with DB v8.

After accepting the v8 update, create a standard 2/2 black Zombie and open its
artwork selector. 10E displays Artist unknown instead of Carl Critchlow (the
previous 1.11 acceptance pass confirmed that credit). Current published records
lack the artist field because main's generator predates the 1.11 artist-credit
changes. The 1.11 bundled database includes credits; the newer downloaded
database supersedes it. Images still display correctly.

The Reality Fracture refresh in this task ran main's older generator. Fix the
published generator to retain authoritative credits and regenerate a new,
monotonically higher database version. Verify the remote payload and repeat
artwork selection in the simulator. No correction applied during this check.

## Investigation — before fixing

Live payload rechecked: v8, 962 definitions, 3,079 artwork entries, zero artist
values; SHA-256 matches its manifest. The problem is missing metadata, not a
partial download. Credit support is present in branch commit 4daf6a4 but absent
from main's generator. The branch custom_tokens.json also adds 26 artwork
credits across 24 definitions; its only changes versus main are artist fields.
Both generator and custom source must be included in a correction, followed by
a higher manifest version (at least 9), preserving token identities/artwork URLs.

Existing nonempty saved credits are retained by ArtworkMetadataEnricher.merge;
this update does not globally erase them from existing boards. New tokens and
legacy tokens missing credits cannot get authoritative credits from v8.
Hardcoded utility artwork is separate from the remote token database.

A corrected remote payload can fix ordinary definitions without a new app
release. Additional code concern: TokenCard first matches name/PT/colors/type/
abilities before joining variants by URL, so customized tokens may not enrich
missing credits even after corrected data arrives. Recommend a URL-based fallback
for enrichment without changing token identity or downloading images again.

No code or published-data changes made.

## Resolution and verification

Published focused main commit `e4867f4`: artist-preserving generator and custom
credits, database v9, manifest, and regeneration workflow safeguards. All 962
definitions and 3,079 artwork entries retain authoritative credits. Compared
with v8, all data other than artist metadata is identical. The exact production
URLs were verified against manifest SHA-256 and size. The synthetic `testing`
branch's v999 fixture is not a shipped/release-candidate version.

The iOS simulator accepted the update and its downloaded payload exactly matched
v9. Opening an already renamed `one Zombie` enriched the saved 10E variant to
Carl Critchlow. Artwork-cache filenames, sizes, and modification times were
unchanged across the metadata repair. Local release assets now also bundle v9.
