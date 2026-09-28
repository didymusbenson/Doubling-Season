# Jace missing from token search

2026-09-25: User reports Jace still does not appear in search after Reality
Fracture database publication. Do not assume category filters explain it.

Confirmed: live database v8 contains Jace, type Planeswalker — Jace, with both
loyalty abilities. Current branch parser accepts arbitrary type strings. All-tab
search matches name/type without excluding Category.other. Search creates a new
TokenDatabase when opened. Investigating installed/released behavior, source
selection, and update application. Device/database version requested.

Additional observation: loadTokens does not invalidate an existing filtered
cache, although fresh search instances do not inherit that cache. Not yet shown
to explain this report. No fix selected pending reproduction.

Resolution: user confirmed human error and cancelled the investigation. No
Jace search defect established; no application code changed.
