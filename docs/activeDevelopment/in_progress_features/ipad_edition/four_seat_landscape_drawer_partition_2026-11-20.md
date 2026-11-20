# Four-seat landscape drawer partition

On the wide four-seat landscape board, the game drawer now reserves the center
column during each animation frame. The two physical board columns resize
evenly; within each seat, the token and life/utility lanes occupy their own
60/40 shares, without a paint translation under the tokens. Seat order, seat
rotation, the drawer and control behavior, and the closed layout are unchanged.
Token-lane dismissal still consumes the tap; utility actions stay blocked while
the game drawer is open. The centered handle cutouts are retained.

This applies only when the closed four-seat landscape layout already uses split
lanes. At default text scaling that is a usable table width of at least 1047
logical pixels (two 520-pixel seats and the 7-pixel river). The threshold still
respects the existing font-scaling policy. Narrow/adaptive landscape and
portrait, empty-seat/three-player, two-player, and phone presentations keep their
existing composition.

Render checks covered 1133×744 and 1366×1024 open, mid-animation and reversal
states, plus existing portrait/three-seat behavior. The geometry regression
checks the seat/channel boundaries, lane separation and restored closed layout.
Physical-device acceptance is separate.
