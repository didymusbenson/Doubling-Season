# Four-seat landscape drawer translation

Build 21 opened the center tray by narrowing both board halves. After review,
the wide four-player landscape layout now translates each entire half outward
by the same distance. The seat, token, life and utility dimensions never
change while the tray moves. Only the outer viewport trims the overflow; the
two rounded inner edges follow the tray. The center controls retain their
tap targets and ride the same opening. A visible token-area tap dismisses
without triggering gameplay, and life and utility controls remain blocked
until the tray closes.

The closed center river starts at 8 logical pixels. Each half moves by half
the revealed tray width beyond that river. This applies only to wide four-player
landscape with the existing split lanes: two 520-pixel seats plus the river,
or at least 1048 logical pixels at default text scaling. The existing
font-scaling policy still applies. Narrow/adaptive landscape, portrait, empty
seat/three-player, two-player, and phone layouts keep their existing behavior.

Flutter regression checks cover the first moving frame, partial opening,
overshoot, settled opening, reversal, repeat open/close, exact restored
geometry, and actual visible and clipped hit targets. The 1133×744 and
1366×1024 Flutter captures were reviewed with real fonts. Physical-device
acceptance remains separate.
