# Marketing Material

This document provides marketing copy, feature highlights, and survey analysis for promoting Doubling Season.

## Product-Market Fit: Survey Analysis

### Survey Question
"What is the single biggest pain point you experience when playing token decks?"

### Pain Points Analysis (89 responses)

#### ✅ FULLY ADDRESSED (75-80% of responses)

**1. Basic Token Counting/Tracking (25+ responses)**
- Quotes: "Keep track of my number of tokens", "I lose count", "Keeping track of how many you get"
- **Solution:** Automatic count tracking per token type, no manual counting required

**2. Tapped/Untapped Management (15+ responses)**
- Quotes: "keeping track of what's tapped, not tapped", "Keeping track of which tokens are tapped or untapped"
- **Solution:** Per-stack tapped/untapped counts with one-tap toggle buttons

**3. Summoning Sickness Tracking (10+ responses)**
- Quotes: "which ones have summoning sickness without the haste", "keeping track of ones with summoning sickness"
- **Solution:** Automatic summoning sickness tracking (toggleable setting), applied when tokens enter

**4. Counter Tracking (+1/+1, -1/-1, Custom) (20+ responses)**
- Quotes: "how many counters they have", "Keeping track of them additional +1/+1 counters", "Tokens with different types of counters"
- **Solution:** Per-stack counter tracking, automatic +1/+1 and -1/-1 cancellation, modified P/T display, custom counters support

**5. Mental Math / Cognitive Load (5+ responses)**
- Quotes: "MATH!!!", "The math", "I have a nervous system disorder that makes my brain foggy. Math is hard sometimes"
- **Solution:** App performs all arithmetic automatically (quantity × multiplier, counter calculations, modified P/T)

**6. Speed/Time During Play (1 direct response)**
- Quote: "The actions of calculating the tokens or digging through my token box usually takes much longer than turns"
- **Solution:**
  - Instant search with Recent/Favorites tabs
  - Bulk operations via multiplier system (1-1024)
  - Quick actions directly on token cards (no detail view needed)
  - Global actions (Untap All, Clear Summoning Sickness, +1/+1 Everything)
  - Deck save/load system

**7. Physical Limitations (10+ responses)**
- Quotes: "Not enough dice", "Space / Limited play area", "not having the actual token card I need", "Forgetting my tokens"
- **Solution:** Digital = infinite tokens, no physical space/dice needed, 883-token database always available

**8. Different P/T on Same Token Type (8+ responses)**
- Quotes: "keeping track of tokens with different +1/+1 counter amounts", "30 tokens of the same but each has different p/t or counters"
- **Solution:** Separate stacks per counter configuration, split stack feature for dividing tokens

**9. Token Variety/Types (10+ responses)**
- Quotes: "The myriad of different creature types", "variety of slightly different tokens needed (1/1 black vampire, 1/1 white vampire)"
- **Solution:** 883 tokens in searchable database, filter by category and color identity

**10. Scute Swarm Specifically (2 responses)**
- Quote: "Scute swarm duplication"
- **Solution:** Special Scute Swarm doubling button built into token card

#### ⚠️ PARTIALLY ADDRESSED (5-10% of responses)

**11. Mass Trigger Effects (3 responses)**
- Quotes: "Cathar's Crusade", "Keeping track of triggers and the sheer amount of them"
- **Solution:** Global +1/+1 Everything tool applies counters to all tokens at once
- **Limitation:** No trigger reminder system or stack tracking (out of scope - this is a token tracker, not a rules engine)

#### 🔮 PLANNED FEATURES (10-15% of responses)

**12. Multiple Token Doublers Stacking (8+ responses)**
- Quotes: "Multiple doubling season effects", "Exponentially increasing tokens with 2-3+ token doublers", "Calculating the exponential amount of token doublers stacking"
- **Current:** Manual multiplier input (user calculates x8 and sets multiplier)
- **Planned:** Token Modifier Card Toggles feature (see `PremiumVersionIdeas.md`)
  - Track active doublers (Doubling Season, Parallel Lives, Anointed Procession)
  - Auto-calculate cumulative multiplier

**13. Replacement Effects (4 responses)**
- Quotes: "chatterfang academy manufacturer, doubling season and parallel lives then making a treasure token", "Doubling effects with replacements like academy manufacturer"
- **Current:** Not supported
- **Planned:** Commander-specific modes (see `PremiumVersionIdeas.md`)
  - Chatterfang Mode (auto-creates matching squirrels)
  - Academy Manufactor toggle (prompts for additional Food/Clue tokens)

---

## Marketing Copy

### Elevator Pitch
"Doubling Season is the digital token tracker that solves every pain point of playing token decks: automatic counting, instant tapping, counter management, and lightning-fast operations—no more digging through token boxes or running out of dice."

### Feature Highlights (App Store Description)

**Never Lose Count Again**
- Automatic tracking for unlimited tokens
- Tap/untap entire stacks with one button
- Summoning sickness management built-in

**Math? The App Does It For You**
- Automatic counter calculations (+1/+1 and -1/-1 auto-cancel)
- Modified power/toughness displayed instantly
- Bulk operations with multiplier system (1-1024)

**Lightning Fast**
- Recent & Favorite tokens at your fingertips
- Global actions: Untap All, Clear Summoning Sickness, +1/+1 Everything
- Save/load entire board states instantly
- 883 tokens searchable by name, color, or type

**No Physical Limits**
- Unlimited tokens (no more running out of dice)
- Split stacks with different counter configurations
- Custom counters for any effect
- All tokens always available (no forgotten token boxes)

**Built for Complex Boards**
- Track multiple stacks of the same token with different states
- Special handling for Scute Swarm, Emblems, and more
- Separate tapped/untapped/summoning sick counts per stack
- Color-coded borders for instant token identification

### Target User Pain Points → Solutions Table

| Pain Point | User Quote | Doubling Season Solution |
|------------|------------|-------------------------|
| **Mental Math** | "I have a nervous system disorder that makes my brain foggy. Math is hard sometimes" | App does 100% of arithmetic—just tap buttons |
| **Counting** | "I lose count" | Automatic tracking, impossible to lose count |
| **Speed** | "Digging through my token box takes much longer than turns" | Instant search, Recent/Favorites tabs |
| **Physical Limits** | "Not enough dice" / "Limited play area" | Digital = infinite tokens, zero physical space |
| **Complexity** | "30 tokens of the same but each has different p/t or counters" | Separate stacks per configuration, split stack tool |
| **Mass Triggers** | "Cathar's Crusade" | Global +1/+1 Everything applies counters to all tokens at once |

### Accessibility Angle
"Designed for players with cognitive load challenges: zero mental math required, clear visual indicators, and one-tap operations for everything."

### Competitive Advantage
"Unlike generic counters or dice, Doubling Season is purpose-built for Magic tokens with deep understanding of game mechanics: summoning sickness, counter cancellation, color identity, and commander-specific effects."

---

## Survey Quantitative Summary

- **89 responses** to "What is the single biggest pain point?"
- **75-80%** of pain points are **fully solved** by current implementation
- **10-15%** have **documented planned features** in roadmap
- **5-10%** are **partially addressed** with viable workarounds

### Top Pain Points by Frequency:
1. Counter tracking: ~20 responses (✅ SOLVED)
2. Basic counting: ~25 responses (✅ SOLVED)
3. Tapped/untapped: ~15 responses (✅ SOLVED)
4. Summoning sickness: ~10 responses (✅ SOLVED)
5. Physical limits (space/dice): ~10 responses (✅ SOLVED)
6. Token variety: ~10 responses (✅ SOLVED)
7. Different P/T on same token: ~8 responses (✅ SOLVED)
8. Multiple doublers: ~8 responses (🔮 PLANNED)
9. Math/cognitive load: ~5 responses (✅ SOLVED)
10. Replacement effects: ~4 responses (🔮 PLANNED)

**Key Insight:** The app solves all top pain points except advanced doubler calculation and replacement effects—which are planned premium features.

---

## Feature Roadmap Communication

### Current (v1.3.0)
- ✅ 883-token searchable database
- ✅ Automatic count/tap/counter tracking
- ✅ Multiplier system (1-1024)
- ✅ Global actions (Untap All, +1/+1 Everything, etc.)
- ✅ Deck save/load system
- ✅ Custom counters
- ✅ Summoning sickness tracking
- ✅ Split stack tool
- ✅ Token artwork display (two style modes)

### Planned (Premium Features)
- 🔮 Automatic doubler calculation (Doubling Season + Parallel Lives = x4)
- 🔮 Token Modifier Card Toggles (track active doublers)
- 🔮 Chatterfang Mode (auto-create matching squirrels)
- 🔮 Academy Manufactor Mode (prompt for Food/Clue/Treasure)
- 🔮 Other commander-specific tools (Krenko, Brudiclad, Rhys)

### Intentionally Out of Scope
- ❌ Comprehensive rules engine
- ❌ Trigger/stack tracking
- ❌ Game state automation beyond tokens

---

## User Testimonial Candidates

*(These are direct quotes from survey that showcase solved pain points)*

**Math/Accessibility:**
> "I have a nervous system disorder that makes my brain foggy. Math is hard sometimes. Keeping track is difficult once I get to like twenty +12/+12"

**Speed:**
> "The actions of calculating the tokens or digging through my token box usually takes much longer than turns."

**Complexity:**
> "When I am managing a lot of the same token with different counters on them like one batch of sapperlings with plus five plus five on them and another batch with plus two plus two on them"

**Physical Limits:**
> "Not enough dice" / "Space" / "I use a deck that like to have lots of different tokens, often my board just becomes far too cluttered"

**Counting:**
> "shit gets hectic when u have 400 tokens with various different amounts of counters on them"

---

## App Store Keywords

**Primary:**
- Magic the Gathering token tracker
- MTG token counter
- Commander token manager
- Token deck tracker
- Magic token app

**Secondary:**
- Doubling Season calculator
- Scute Swarm tracker
- MTG counter tracker
- Commander token helper
- Magic token database

**Long-tail:**
- Track tapped untapped tokens
- MTG summoning sickness tracker
- Token +1/+1 counter app
- Magic token deck manager
- Commander token organizer

---

## Social Proof Strategy

### Reddit/Forum Posts
**Title:** "I surveyed 89 token deck players. Here are the biggest pain points—and how I solved them."

**Body:** Link to survey results, showcase top pain points → app features mapping

### Content Marketing
- Blog post: "The Hidden Accessibility Crisis in Magic Token Decks"
- Video: "Can You Actually Track 400 Tokens? We Put It to the Test"
- Infographic: Survey pain points visualization

### Community Engagement
- Post in r/EDH, r/magicTCG with survey insights
- Share on Magic Discord servers
- Reach out to Commander content creators for review

---

## Future: Premium vs. Free Model

### Free (Current Features)
Everything in v1.3.0 remains free:
- Full token database (883 tokens)
- Unlimited token tracking
- All counter management
- Deck save/load
- Global actions

### Premium Features (Planned)
Commander-specific power tools:
- Automatic doubler calculation
- Chatterfang Mode
- Academy Manufactor Mode
- Token Modifier Card Toggles
- Advanced deck analysis
- Custom app icons

**Justification:** Free version solves 80% of pain points. Premium targets edge cases (stacking doublers, replacement effects) that affect 10-15% of advanced players.
