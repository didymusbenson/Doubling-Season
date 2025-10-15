## ExpandedTokenView

Rather than provide an edit option where users tap to enable edit mode key fields will have a "tap to edit" functionality.

When the user taps an editable field, that field will enable edit mode, and the user can alter the value in place without editing the rest of the token. When they refocus or indicate "done" the edit ends.

Editable fields include

* Name
* Abilities
* p/t
* amount
* colors

Color selection in the editor will be based on selecting indicators for WUBRG, not by typing the letters. Colors will be automatically displayed this way with current colors already enabled. This does not enter or exit an "edit" mode, but rather alters the value of the token's color string based on what indicators are selected.

Refer to the NewTokenSheet for an exapmle of color indicators.

## Expanded Token View Styling

Update the styling of the Expanded Token View to be similar to that of the NewTokenSheet. 

The first section of the of the Expanded Token View will include details (similar to the layout of NewTokenSheet), then beneath it the controls for adding, removing, tapping, and untapping. These controls will follow their formatting on the condensed view (+ - and arrow symbols). Power and toughness will be an HStack with the p/t value on one side, and the controls for modifying plus one and minus one counters on the other side (see below for handling Power and Toughness). 

The styling of the color identity section will match NewTokenSheet.

The next section will deal with counters. It will display the list of counter pills with a `[+]` button for the add counters function. Tapping an individual counter pill will display a menu to modify the amount of a given counter the token has. If set to 0 before saving, the counter will be removed. Plus ones and minus ones in the counter section will affect power and toughness as described above. 


## Handling Power and Toughness

The p/t of a token is complicated. It may be a number/number, but may also include wildcards (such as 1+\* or \*/\*). If the token's power and toughness are two numbers, they should be able to be modified by +1/+1 and -1/-1 counters. If, for example, a 1/1 has 2 +1/+1 counters on it, the p/t should be rendered as 3/3. In the case of non-integer power and toughness values, they should simply render as `[original value] +x/+x` where X is the number of +1/+1s (or -x/-x for minus ones).

The modified power and toughness should only be seen in the condensed TokenView. In the Expanded Token view, it is displayed as the original p/t value, which is editable, and "+x/+x", indicating the number of plus ones or minus ones on the token. 

If a token's power and toughness are modified by counters, the modified p/t should be displayed with a different styling, such as a bolder typeface or alternate background in order to indicate that the p/t has been modified.

## Counters

Although plus one and minus one coutners behave differently from other counters, they still need to be represented on the token's abilities the same way that other counters are in order to maintain consistency. The special controls and views for things related to +1/+1 and -1/-1 counters should be in addition to the other counter support rather than entirely separate.

## New Token Sheet

Allow the user to tap the value indicated in the new token sheet in order to manually set the number of tokens they want to create, rather than using the quick selection buttons or the arrows.


## Summoning Sickness

A new property needs to be added to token items, similar to "tapped" that tracks the number of tokens that are "summoning sick". All newly created tokens are summoning sick, so when a new token is added, the summoning sick value also increases by the same amount.

These are represented by the circle hexagonpath sf symbol and are displayed to the left of the untapped count on the token. The number of summoning sick tokens is only displayed if it is greater than 0.

There will be a toolbar button with the same circle hexagonpath sf symbol that, when tapped, sets ALL summoning sick token values to 0.

When a user "splits the stack", the number of summoning sick tokens in both stacks should be set to zero. If a user attempts to split a stack where one or more tokens are summoningsick, there should be a footnote in the split stack view notifying the user that splitting will remove the summoning sickness status from both stacks.

If the user does a long press on the summoning sickness toolbar button, they should be given an alert that allows them to enable/disable the summoning sickness feature. When disabled, summoning sickness is ignored for creating new tokens and all existing tokens have their summoning sick counts set to 0.



