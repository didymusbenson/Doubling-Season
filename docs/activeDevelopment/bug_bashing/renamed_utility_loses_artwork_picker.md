# Renamed utility loses artwork choices and displayed credit

Status: implemented and simulator-verified on 2026-09-26. Original reproduction:
iPhone 17 Pro Max / iOS 26.2, 1.11.0+19 on 2026-09-25.

## Reproduction

Rename Brudiclad, Telchor Engineer to Brudiclad QA. Open Change artwork.
The picker shows the current 2XM art, Artist unknown, and Upload, but neither
of the two official artwork choices. A read-only copy of the persisted tracker
still contains both 2XM/C18 variants and Daarken credits. No data was erased by
merely opening the sheet.

## Cause and scope

TrackerWidgetCard._artworkOptions matches definitions by editable name and
returns an empty list before considering saved variants when no match exists.
ToggleWidgetCard has the same logic (code-confirmed; not separately UI-tested).
This is independent of missing metadata in remote token DB v8: utility artwork
comes from WidgetDatabase and the saved variants already have correct credits.

Recommended fix: retain saved variants even when definition lookup fails, and
resolve authoritative utility metadata through stable identity where available
or known artwork URLs rather than editable display names. Review both tracker
and toggle cards and the related token metadata fallback for board-item parity.
No implementation changes made.

## Resolution and verification

Saved variants and the selected URL now survive failed definition lookup. A
unique action type or known artwork URL resolves utility alternate art; exact
name is a legacy fallback only. Shared enrichment fills missing metadata by
exact URL or known Scryfall face/UUID identity, without changing stored URLs,
cache keys, custom file art, or existing nonempty credits. Token cards use the
full catalog for URL-based credit recovery even after customization.

Simulator: renamed Brudiclad QA shows 2XM and C18, both with Daarken. Selecting
C18 persisted across restart. Renamed onarch QA shows CN2/FIC/OTC/LTC and Mike
Bierek for its selected CN2. Renamed one Zombie recovers Carl Critchlow on 10E
after v9 download; its artwork cache remained unchanged.

## Resumed deck round trip — 2026-09-27

iOS Save Board → Clear board and load retained the renamed token, tracker and
toggle artwork URLs, sets, variant lists and credits exactly. The restored mixed
board and an appended second deck both survived restart unchanged.
