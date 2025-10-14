# Features

A number of new functionalities are required before this product can be released as version 1. After reviewing the needed improvements, make the changes necessary to support this new feature set. This implementation must follow my minimalist approach of fewer files and straightforward implementation. We do not need overengineered complexity or exhaustive design worries. Stick as much as possible to apple and swift's fundamentals and coding standards. 

## Condensed token view
The current state of the token view requires minimal updates. Some changes will be required to support the new features identified below. Unless otherwise specified, do not alter the default TokenView unless this condensed view can be preserved. 

## Counters
A token may have one to many "Counters" applied to it. There are a variety of counters with various names. Counters modify either the abilities or the pt of a token. A CounterDatabase, similar to TokenDatabase, needs to be created in order to keep track of these. 

The current list of counters is:

+1/+1, -1/-1, Acorn, Aegis, Age, Aim, Arrow, Arrowhead, Art, Awakening, Bait, Blaze, Blessing, Blight, Blood, Bloodline, Bloodstain, Book, Bore, Bounty, Brain, Bribery, Brick, Burden, Cage, Carrion, Charge, Chip, Chorus, Coin, Collection, Component, Contested, Corpse, Corruption, CRANK!, Credit, Croak, Crystal, Cube, Currency, Day, Death, Defense, Delay, Depletion, Descent, Despair, Devotion, Discovery, Divinity, Doom, Dread, Dream, Duty, Echo, Egg, Elixir, Ember, Energy, Enlightened, Eon, Eruption, Everything, Experience, Eyeball, Eyestalk, Fade, Fate, Feather, Feeding, Fellowship, Fetch, Filibuster, Finality, Flame, Flood, Foreshadow, Fungus, Funk, Fury, Fuse, Gem, Ghostform, Glass, Globe, Glyph, Gold, Growth, Hack, Harmony, Hatching, Hatchling, Healing, Hit, Hole, Hone, Hoofprint, Hope, Hour, Hourglass, Hunger, Husk, Ice, Impostor, Incarnation, Incubation, Infection, Influence, Ingenuity, Intel, Intervention, Invitation, Isolation, Javelin, Judgment, Ki, Kick, Knickknack, Knowledge, Landmark, Level, Loot, Lore, Loyalty, Luck, Magnet, Manabond, Manifestation, Mannequin, Matrix, Memory, Midway, Milk, Mine, Mining, Mire, Music, Muster, Necrodermis, Nest, Net, Night, Oil, Omen, Ore, Page, Pain, Palliation, Paralyzation, Pause, Petal, Petrification, Phylactery, Phyresis, Pin, Plague, Plot, Point, Poison, Polyp, Pop!, Possession, Pressure, Prey, Primeval, Punch card, Pupa, Quest, Rad, Rebuilding, Rejection, Release, Reprieve, Resonance, Rev, Revival, Ribbon, Ritual, Rope, Rust, Scream, Scroll, Shell, Shield, Shoe, Shred, Shy, Silver, Skewer, 

* The counter database will have objects in this shape: {name, color}. Color is an optional field, and all tokens will be initialized as "default" to be updated manually at a future date.
* While editing a token, the user can add a counter and set its amount
* When adding a counter, the user is presented a searchable list. This list will allow the user to mark favorites and prioritizes their most recently used counters
* If the player types something into the search that isn't found, the "not found" message includes a button to create a counter with the name of whatever they searched for and apply it to that token
* All counters except +1/+1 and -1/-1 should appear on the condensed view of a token as "pills" Above the token's abilties text. The token pills will contain the name of the counter and its quantity. If there is only one of a given counter on a token the quantity is not displayed.
* While editing a token in a detailed view, the counters have buttons to increment and decrement
* When a counter is chosen, the user is prompted whether they wish to add the counter to all tokens in the stack or to add it to one. If they select "add to one", the stack is split by 1 and the new token is given the counter.

### Handling +1/+1 and -1/-1
* Users will not have to open the counter menu to add +1/+1s, but if they do it will interact with this feature
* The P/T part of the token's condensed view will display something like "p/t (+x/+x)"
* The expanded view of a token by default will have a stepper that can increase or decrease next to power and toughness. When the value of the stepper is positive, the token has that many +1/+1 counters, when it is negative, the token has that many -1/-1 counters. 
* +1/+1 and -1/-1 tokens have a special interaction with each other. A token cannot have both types. If a token has a +1/+1 counter and gains a -1/-1 counter, it simply removes one of the +1/+1s
* These counters do not prompt the user to split the stack unless manually added with the "add counter" search menu.

## Stack Splitting
When viewing a token, users can "split" it into two tokens. Splitting creates a duplicate copy of the existing token and assigns an amount to it based off of the existing token.

* Use case: A user has a "soldier" token with an amount of 10. When they select to "split" it they are asked how many tokens to split. Using a slider or manual entry, they can specify an exact number (5) and select "split". A new copy of the existing soldier token is created and assigned an amount of 5, the original token's amount is reduced to 5
* When splitting, the new stack must be aware of tapped and untapped tokens. During the splitting prompt, the user has an option to toggle "tapped first".
* If the new stack exceeds the original token's "amount - tapped" then the difference should be set to tapped on the newly created token. The original tokens amount should be decreased by the appropriate amount while leaving the remainder tapped. 
* If "tapped first" is selected, the newly created tokens should have a tapped value up to the number tapped on the original. 
* Use case: A user has a token with an amount of 5 and tapped value of 2. They split to create a new stack of 3 with "tapped first" false. The new stack has an amount of 3 with a tapped count of 0. The original stack has an amount of 2 with a tapped count of 2. 
* Use case: A user has a token with an amount of 5 and tapped value of 2. They split to create a new stack of 3 with "tapped first" false. The new stack has an amount of 3 with a tapped count of 2. The original stack has an amount of 2 with a tapped count of 0.
* When a user adds a counter to just one token, it triggers a stack split and adds a new counter. Because the original stack does not have the speified counter, this should be handled by an overriding method that adds the specified counter to the newly created token while splitting. 

## Expanded token viewer
Tapping on the body of a token will expand the token to a more detailed view of a given stack. Information visible on detailed view incldues:

* All fields from the condensed view
* A list of counters on the given token, both the type and amount
* A [+] button on the counters section to add new ones
* An edit button that allows the player to modify the token's details such as name, colors, p/t and abilities
* Labelled buttons for "add 1", "remove 1", "tap", "untap" instead of just symbols
* A button to "split stack" which will duplicate the existing token and split the "amount" between the two based on user input

## Relocated About View
The about view toggle should be removed from the bottom of the content view and instead added to the toolbar at the top of the app. It should have a circled question mark as its toolbar icon. 

## Multiplier
Replacing the "About View" toggle at the bottom of the screen is an indicator for the token multipler. It defaults to "x1" but the user can tap it to view buttons for increasing/decreasing the multipler value. 

* Every time the user presses the "+" button on a token to add to the token's amount, instead they add (1 x multipler) added to the amount.
* When the user creates a new token, the reminder text indicates to users to create the base number of tokens and that the multiplier will be applied automatically.
* Use case: A user creates a new "Saproling" token while the multiplier is set to x4. The user selects 1 and taps  "create". The new Saproling token is created with an amount of 4. 
* The multiplier only applies to tokens created or added, not to tapping, untapping, or removing. 
* If tokens are created with "create tapped" selected, the final amount after the multiplier applies should be the amount that are set to tapped.

## Database Deduplication
A nontrivial amount of tokens in the token database appear to have duplicate entries. These should be consolidated. 

## Emblems
Tokens with the type "Emblem" should be visually represented as distinct from normal tokens. They do not have a p/t value and cannot be tapped, so the indicators for tapped amount, tap and untap buttons, and p/t sections of the token should not be rendered. Emblems should not have the color indicator border. Their name and ability text should be centered. 



