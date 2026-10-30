# Centered two-player shared controls

This correction starts from PR60/main `1a5dd07d23c74393d0bc568d646667c78bb0f0f2`.
The user explicitly limits the change to two-player mode; three/four-player
control placement, token spacing, artwork and behavior must remain unchanged.

## Confirmed cause and references

The actual supplied 966 by 932 screenshot shows Dice near the upper life/token
boundary, Day/Night near the lower boundary and Menu near the outer right edge.
The two-player branch in `table_screen.dart` deliberately anchored those controls
over life areas to keep them away from token rows. That collision avoidance
displaced the central shared group. The earlier mid-transition mockup instead
keeps shared controls grouped around the central player seam.

Returning the controls to the seam intersects the first token's name/totals row,
which starts five pixels inside its artwork. The user permits internal clearance
within that first card, with artwork filling the area, and rejects both off-center
controls and a blank outer margin pushing the whole token down.

## Two-player correction

Closed Dice/Menu/Day-Night centers are at horizontal table center minus 54,
center, and center plus 54 respectively, all on the player seam. During the
horizontal reveal, those horizontal positions remain fixed: Dice follows the
upper wall, Menu and Day/Night follow the lower wall. Menu remains one complete
52-pixel target, with the matching wall cutouts centered on the same axis.
The two-player drawer content clears the controls' inward halves by 26 pixels
above and 30 below. Its 228-pixel minimum opening also accommodates the 56-pixel
header, a complete 92-pixel menu action and the existing 24-pixel body padding.
Short seat viewports retain their normal vertical scrolling. This does not change
the existing narrow-window guard or any three/four-player drawer dimensions.

Only the first token in each opposing lane receives additional internal content
clearance. Its artwork, color rail and card bounds still begin at the lane edge;
the list has no top padding. Subsequent cards and three/four-player cards retain
their existing geometry. Full-art and fade presentation, expansion, scrolling,
saved state and hit targets remain intact. Obsolete life-corner clearances are
removed only from the two-player path; error-state controls retain real clearance
without adding a permanent empty band to normal token rows.

At narrow supported widths, a flank control can overlap a small part of the life
corner. The two-player rail clips only that actual 22-pixel control circle,
derived from the shared control and lane geometry. The clip stays on the viewport
outside its scrolling content and is disabled when a warning moves life away
from the seam. Neighboring life taps remain available; no arbitrary corner notch
or extra rectangular dead area is introduced.

## Validation and delivery

Check actual control centers and first-token name/totals/action bounds in both
opposing rotations and portrait/landscape, including narrow layouts, open/closed
and intermediate animation frames. Distinguish artwork flushness from the
intentional internal content inset. Keep expanded cards and scrolling usable,
consume token dismissal taps, and check content beneath overhanging controls.
Recheck three/four-player renders and interactions without redesigning them.

Run analysis, the full tablet test suite, Release browser rendering/input checks
and the existing platform/combined Pages CI. Record exact source, merge and live
asset evidence in the PR and private delivery receipts. Native delivery is a
signed Release IPA handoff for another Mac; do not query or install the iPad from
Kista's Mac. Preserve marketing version, signing identity, data schemas, OTA
assets and published AGENTS.md. A build-time number override is permitted.
