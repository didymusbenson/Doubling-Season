# Wildcard Replacement: Magic Symbol Rendering

## Overview

Replace bracketed wildcards in token abilities text with custom inline iconography. This is a **display-only transformation** that improves readability while preserving raw text for editing.

**Status:** Nice-to-have enhancement for visual polish
**Priority:** Low - Visual enhancement that improves readability but not critical to functionality

## Core Principle

- **Card View (TokenCard)**: Parse and replace `{variable}` with inline widget symbols
- **Expanded View (ExpandedTokenScreen)**: Show raw text with brackets intact, allow editing
- **Data Model**: No changes - symbols are purely display-level transformations
- **Backwards Compatible**: Parser handles plain text gracefully
- **Rendering Method**: Custom widgets (not Unicode/emoji replacement)

## Examples

### Before & After

| Raw Text (stored in database) | Display (in TokenCard) |
|-------------------------------|------------------------|
| `{T}: Add {G}.` | `[tap icon]: Add [green circle with G].` |
| `{T}, Sacrifice this artifact: Add {R} or {G}.` | `[tap icon], Sacrifice this artifact: Add [red circle with R] or [green circle with G].` |
| `Sacrifice this creature: Add {C}.` | `Sacrifice this creature: Add [grey circle with C].` |
| `{2}, {T}, Sacrifice this token: Draw a card.` | `[grey circle with 2], [tap icon], Sacrifice this token: Draw a card.` |
| `{1}{B}, Sacrifice a creature: You gain X life` | `[grey circle with 1][black circle with B], Sacrifice a creature: You gain X life` |
| `Defender, {CUSTOM}` | `Defender, {CUSTOM}` (unchanged - not in mapping) |

**Visual Description:**
- Tap symbol: System icon (same as tap button)
- Colored mana: Colored circle with white letter centered ({R} = red circle, white "R")
- Generic mana: Theme-aware grey circle with number (light/dark mode adaptive)
- All symbols sized to match surrounding text height

## Symbol Specifications

**Database Analysis Results:**
Based on parsing `assets/token_database.json`, the following wildcards are actually used:

| Wildcard | Count | Rendering | Description |
|----------|-------|-----------|-------------|
| `{T}` | 30 | System icon (tap button) | Tap symbol |
| `{G}` | 10 | Green circle + white "G" | Green mana |
| `{B}` | 9 | Black circle + white "B" | Black mana |
| `{R}` | 6 | Red circle + white "R" | Red mana |
| `{C}` | 5 | Grey circle + white "C" | Colorless mana |
| `{W}` | 2 | Yellow circle + white "W" | White mana |
| `{U}` | 1 | Blue circle + white "U" | Blue mana |
| `{0}` | 1 | Grey circle + "0" | Generic mana (0) |
| `{1}` | 18 | Grey circle + "1" | Generic mana (1) |
| `{2}` | 12 | Grey circle + "2" | Generic mana (2) |
| `{3}` | 1 | Grey circle + "3" | Generic mana (3) |

### Tap Symbol Rendering

**Widget:** Icon from tap/untap action buttons
- **Icon Source:** Same icon used in tap/untap action buttons (for visual consistency)
- **Color:** Theme-aware (matches surrounding text color)
- **Size:** `textHeight * 1.1` (10% larger than text)

### Colored Mana Rendering

**Widget:** Circular container with centered letter

**Circle Specifications:**
- **Shape:** Perfect circle (width = height)
- **Size:** `textHeight * 1.1` (10% larger than text)
- **Border:** None (solid fill)
- **Letter:** White text, centered, bold weight

**Color Mapping:**
Use `ColorUtils` existing color values (same as token expanded view color identity selector):

| Wildcard | Circle Color | Letter |
|----------|--------------|--------|
| `{W}` | ColorUtils white | "W" |
| `{U}` | ColorUtils blue | "U" |
| `{B}` | ColorUtils black | "B" |
| `{R}` | ColorUtils red | "R" |
| `{G}` | ColorUtils green | "G" |
| `{C}` | ColorUtils colorless (grey) | "C" |

**Note:** These colors are already tested for readability over gradients/artwork backgrounds.

### Generic Mana Rendering

**Widget:** Circular container with centered number

**Theme-Aware Rendering:**

**Light Mode:**
- **Circle Color:** Light grey (`Colors.grey[300]` or `#E0E0E0`)
- **Text Color:** Black or dark grey (`Colors.grey[900]`)
- **Border:** Optional 1px darker grey for definition

**Dark Mode:**
- **Circle Color:** Dark grey (`Colors.grey[700]` or `#616161`)
- **Text Color:** White or light grey (`Colors.grey[100]`)
- **Border:** Optional 1px lighter grey for definition

**Sizing:**
- Same diameter as colored mana circles
- Text should be slightly smaller than circle to fit comfortably
- Numbers centered both horizontally and vertically

## Implementation Details

### Parser Component

**Location:** `lib/utils/abilities_text_parser.dart`

**Interface:**
```dart
class AbilitiesTextParser {
  /// Parses abilities text and returns InlineSpan with inline widget symbols.
  ///
  /// Returns InlineSpan (mix of TextSpan and WidgetSpan) for use in Text.rich() widget.
  /// Unrecognized {variables} are rendered as-is with brackets.
  static InlineSpan parse(String rawText, TextStyle baseStyle, BuildContext context) {
    // 1. Scan for {variable} patterns using RegExp
    // 2. Match against wildcard types
    // 3. Build InlineSpan tree with TextSpan + WidgetSpan nodes
    // 4. Return InlineSpan for Text.rich()
  }

  /// RegExp pattern for matching {variable}
  static final RegExp _wildcardPattern = RegExp(r'\{([^}]+)\}');

  /// Build widget for wildcard based on type
  static Widget? _buildSymbolWidget(String wildcard, TextStyle baseStyle, BuildContext context) {
    switch (wildcard) {
      case 'T':
        return TapSymbolWidget(textHeight: baseStyle.fontSize ?? 14);
      case 'W':
      case 'U':
      case 'B':
      case 'R':
      case 'G':
      case 'C':
        return ColoredManaSymbol(
          color: wildcard,
          textHeight: baseStyle.fontSize ?? 14,
        );
      case '0':
      case '1':
      case '2':
      case '3':
        return GenericManaSymbol(
          value: wildcard,
          textHeight: baseStyle.fontSize ?? 14,
          isDarkMode: Theme.of(context).brightness == Brightness.dark,
        );
      default:
        return null; // Unrecognized wildcard, render as-is
    }
  }
}
```

**Usage in TokenCard:**
```dart
// Current (lib/widgets/token_card.dart):
Text(
  widget.item.abilities,
  style: Theme.of(context).textTheme.bodyMedium,
)

// After implementation:
Text.rich(
  AbilitiesTextParser.parse(
    widget.item.abilities,
    Theme.of(context).textTheme.bodyMedium!,
    context,
  ),
)
```

### Symbol Widget Implementations

**Location:** `lib/widgets/mana_symbols/`

#### Tap Symbol Widget
```dart
class TapSymbolWidget extends StatelessWidget {
  final double textHeight;

  const TapSymbolWidget({required this.textHeight, super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Use the exact same icon as tap/untap action buttons
    return Icon(
      Icons.rotate_right, // Replace with actual tap button icon
      size: textHeight * 1.1, // 10% larger than text
      color: Theme.of(context).textTheme.bodyMedium?.color,
    );
  }
}
```

#### Colored Mana Symbol Widget
```dart
class ColoredManaSymbol extends StatelessWidget {
  final String color; // 'W', 'U', 'B', 'R', 'G', or 'C'
  final double textHeight;

  const ColoredManaSymbol({
    required this.color,
    required this.textHeight,
    super.key,
  });

  Color _getCircleColor() {
    // Use same colors as token expanded view (ColorUtils)
    switch (color) {
      case 'W': return ColorUtils.colorForIdentity('W');
      case 'U': return ColorUtils.colorForIdentity('U');
      case 'B': return ColorUtils.colorForIdentity('B');
      case 'R': return ColorUtils.colorForIdentity('R');
      case 'G': return ColorUtils.colorForIdentity('G');
      case 'C': return ColorUtils.colorForIdentity('C'); // Colorless
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = textHeight * 1.1; // 10% larger than text

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getCircleColor(),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        color,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.6, // Letter is 60% of circle size
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    );
  }
}
```

#### Generic Mana Symbol Widget
```dart
class GenericManaSymbol extends StatelessWidget {
  final String value; // '0', '1', '2', '3'
  final double textHeight;
  final bool isDarkMode;

  const GenericManaSymbol({
    required this.value,
    required this.textHeight,
    required this.isDarkMode,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final size = textHeight * 1.1; // 10% larger than text

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
        shape: BoxShape.circle,
        border: Border.all(
          color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!,
          width: 1.0,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        value,
        style: TextStyle(
          color: isDarkMode ? Colors.grey[100] : Colors.grey[900],
          fontSize: size * 0.55, // Number is 55% of circle size
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    );
  }
}
```

### RegExp Pattern

**Pattern:** `r'\{([^}]+)\}'`

**Matches:**
- `{T}` → Captures "T"
- `{W}{U}` → Captures "W", then "U"
- `{10}` → Captures "10"
- `{CUSTOM}` → Captures "CUSTOM"

**Does NOT match:**
- `{` (missing closing brace)
- `{}` (empty braces)
- Plain text without braces

### InlineSpan Construction with WidgetSpan

**Example Input:** `"{T}, Sacrifice this artifact: Add {R} or {G}."`

**Parsing Steps:**
1. Find first match: `{T}` at position 0
2. Build TapSymbolWidget
3. Add WidgetSpan with widget
4. Continue from position 3: `, Sacrifice this artifact: Add `
5. Find next match: `{R}` at position 33
6. Build ColoredManaSymbol(color: 'R')
7. Add WidgetSpan with widget
8. Continue: ` or `
9. Find next match: `{G}` at position 39
10. Build ColoredManaSymbol(color: 'G')
11. Add WidgetSpan with widget
12. Continue: `.` (remaining text)
13. No more matches, done

**Output InlineSpan Tree:**
```dart
TextSpan(
  style: baseStyle,
  children: [
    WidgetSpan(
      child: TapSymbolWidget(textHeight: baseStyle.fontSize ?? 14),
      alignment: PlaceholderAlignment.middle, // Align with text baseline
    ),
    TextSpan(text: ', Sacrifice this artifact: Add ', style: baseStyle),
    WidgetSpan(
      child: ColoredManaSymbol(color: 'R', textHeight: baseStyle.fontSize ?? 14),
      alignment: PlaceholderAlignment.middle,
    ),
    TextSpan(text: ' or ', style: baseStyle),
    WidgetSpan(
      child: ColoredManaSymbol(color: 'G', textHeight: baseStyle.fontSize ?? 14),
      alignment: PlaceholderAlignment.middle,
    ),
    TextSpan(text: '.', style: baseStyle),
  ],
)
```

**Key Implementation Details:**
- **WidgetSpan alignment:** Use `PlaceholderAlignment.middle` to vertically center symbols with text
- **Widget sizing:** Base widget size on `textHeight` (from TextStyle.fontSize)
- **Theme context:** Pass BuildContext to widgets for theme-aware rendering (dark mode)

### Widget Sizing and Alignment

**Size Calculation:**
```dart
// Base size on text height from TextStyle
final textHeight = baseStyle.fontSize ?? 14.0;
final symbolSize = textHeight * 1.1; // 10% larger than text
// Note: This multiplier may need tweaking based on visual testing
```

**Alignment:**
- Use `PlaceholderAlignment.middle` for WidgetSpan to vertically center with surrounding text
- Ensures symbols sit on the same baseline as text
- Alternative: `PlaceholderAlignment.baseline` (may require tuning)

**Spacing:**
- No additional padding needed - symbols flow inline with text
- Browser-like text rendering handles spacing automatically
- Symbols should be visually similar to inline emoji

## Display Locations

### Where Symbols ARE Rendered

1. **TokenCard** (`lib/widgets/token_card.dart`)
   - Abilities text display (main card view)
   - Compact 3-line max with ellipsis overflow
   - Current location: Line ~250 (abilities Text widget)

2. **Future: Widget Cards** (`lib/widgets/tracker_widget_card.dart`, `lib/widgets/toggle_widget_card.dart`)
   - Description text on widget cards (maps to token abilities field)
   - Same rendering logic as TokenCard

### Where Symbols are NOT Rendered

1. **ExpandedTokenScreen** (`lib/screens/expanded_token_screen.dart`)
   - Abilities TextField (editable, shows raw text with `{brackets}`)
   - User can type `{T}`, `{W}`, etc. manually
   - Location: Line ~200-250 (abilities TextField)

2. **NewTokenSheet** (`lib/widgets/new_token_sheet.dart`)
   - Abilities input field (raw text with brackets)

3. **TokenSearchScreen** (`lib/screens/token_search_screen.dart`)
   - Search results preview (optional: could render symbols here too)
   - Decision: Keep raw text for now, revisit if users request it

4. **Data Layer**
   - Database JSON (`assets/token_database.json`) stores raw text
   - Hive models (`Item`, `TokenTemplate`) store raw text
   - No data migration needed

## Phased Implementation

### Phase 1: Foundation (Complete Feature)
**Goal:** Implement all wildcards currently used in the token database

**Scope:**
- Implement `AbilitiesTextParser` with complete symbol set:
  - `{T}` (tap symbol - 30 occurrences)
  - `{W}`, `{U}`, `{B}`, `{R}`, `{G}` (colored mana - 28 total)
  - `{C}` (colorless mana - 5 occurrences)
  - `{0}`, `{1}`, `{2}`, `{3}` (generic mana - 32 total)
- Apply parser to TokenCard abilities text
- Test with existing tokens in database

**Success Criteria:**
- All 11 wildcards from database render correctly
- Unrecognized wildcards render as-is (graceful fallback)
- No performance degradation on token list scrolling
- 100% coverage of wildcards in current token database

### Phase 2: Polish (Future Enhancement)
**Goal:** Enhanced visuals and optional improvements

**Scope:**
- User preference toggle for symbol replacement on/off
- Symbol animations (pulse, fade-in, etc.) - optional
- Fine-tune symbol sizing if 1.1x multiplier feels wrong

**Success Criteria:**
- User can disable feature via settings
- Symbol sizing feels balanced and readable
- Symbols render smoothly with animations (if implemented)

### Phase 3: Extended Support (If Needed)
**Goal:** Support for future wildcards not currently in database

**Scope:** Only implement if/when these wildcards appear in token database
- Untap symbol: `{Q}`
- Variable mana: `{X}`, `{Y}`, `{Z}`
- Extended generic mana: `{4}` - `{20}`
- Hybrid mana: `{W/U}`, `{B/R}`, etc.
- Phyrexian mana: `{W/P}`, `{U/P}`, etc.
- Half mana symbols: `{2/W}`, `{G/W}`, etc.
- Token type references: `{FOOD}`, `{TREASURE}`, `{CLUE}`, etc.

**Decision:** Do NOT implement Phase 3 unless wildcards appear in token database updates

## Design Decisions

### 1. Widget-Based Rendering Rationale

**Why custom widgets over Unicode/emoji?**
- ✅ Full control over visual appearance (colors, sizing, styling)
- ✅ Consistent rendering across all platforms (iOS, Android, Web)
- ✅ Theme-aware (dark mode, custom color schemes)
- ✅ Matches existing app design language
- ✅ Professional MTG-like appearance
- ❌ More complex implementation than simple string replacement
- ❌ Slightly higher rendering overhead (WidgetSpan vs TextSpan)

**Why custom widgets?**
- No licensing concerns
- Full control over visual appearance
- Easier to maintain and customize
- Matches app's existing design language

### 2. Fallback Behavior

**Unrecognized wildcards:** Render as-is with brackets intact

**Examples:**
- `{CUSTOM}` → `{CUSTOM}` (not in symbol map)
- `{THIS}` → `{THIS}` (not in symbol map)
- `{typo` → `{typo` (malformed, missing closing brace)

**Rationale:**
- Graceful degradation - user can still read the text
- No data loss or confusion
- Future symbols can be added without breaking existing tokens

### 3. Performance Considerations

**Parsing Overhead:**
- RegExp matching on every abilities string render
- Widget instantiation for each symbol (WidgetSpan overhead)
- Only 95 total wildcard occurrences across 883 tokens = minimal impact
- Most tokens have 0-2 wildcards

**Scrolling Performance:**
- Typically <10 tokens on screen at once
- WidgetSpan is heavier than TextSpan, but negligible for this use case
- ListView.builder already optimizes by only rendering visible items
- **Conclusion:** Performance is not a concern

**Optional Optimizations (if needed in future):**
- Skip parsing for tokens with no wildcards: `if (!abilities.contains('{')) return TextSpan(...)`
- Cache parsed results if profiling shows issues (unlikely)

### 4. Accessibility

**Screen Reader Solution:**
Wrap parsed text in `Semantics` widget with `label` set to the original unparsed text:

```dart
// In TokenCard abilities text
Semantics(
  label: widget.item.abilities, // Original text with {T}, {R}, etc.
  excludeSemantics: true, // Prevent reading individual widget symbols
  child: Text.rich(
    AbilitiesTextParser.parse(
      widget.item.abilities,
      style,
      context,
    ),
  ),
)
```

**Rationale:**
- Screen readers read the original `{T}`, `{R}`, etc. text
- Simple solution, no complex parsing needed
- MTG is a paper game requiring card reading - baseline accessibility maintained
- Visually impaired players can understand `{T}` = tap, `{R}` = red mana, etc.

## Testing Strategy

### Unit Tests

**Parser Tests:**
```dart
test('parses tap symbol', () {
  final result = AbilitiesTextParser.parse('{T}: Add {G}.', style, context);
  expect(result, isA<TextSpan>());
  final span = result as TextSpan;
  expect(span.children, isNotNull);
  expect(span.children![0], isA<WidgetSpan>()); // {T} becomes widget
  expect(span.children![1], isA<TextSpan>()); // ': Add '
  expect(span.children![2], isA<WidgetSpan>()); // {G} becomes widget
});

test('parses multiple mana symbols', () {
  final result = AbilitiesTextParser.parse('{2}{B}{B}', style, context);
  final span = result as TextSpan;
  expect(span.children!.length, 3); // Three WidgetSpans
  expect(span.children!.every((child) => child is WidgetSpan), true);
});

test('parses actual token ability from database', () {
  final result = AbilitiesTextParser.parse(
    '{T}, Sacrifice this artifact: Add {R} or {G}.',
    style,
    context,
  );
  final span = result as TextSpan;
  // Should have: WidgetSpan({T}), TextSpan(text), WidgetSpan({R}), TextSpan(text), WidgetSpan({G}), TextSpan(text)
  expect(span.children!.length, 6);
});

test('parses colorless mana', () {
  final result = AbilitiesTextParser.parse(
    'Sacrifice this creature: Add {C}.',
    style,
    context,
  );
  final span = result as TextSpan;
  expect(span.children!.any((child) => child is WidgetSpan), true);
});

test('preserves unrecognized wildcards', () {
  final result = AbilitiesTextParser.parse('{CUSTOM}', style, context);
  expect(result.toPlainText(), '{CUSTOM}');
  final span = result as TextSpan;
  expect(span.children, isNull); // Single TextSpan with no widget children
});

test('handles empty string', () {
  final result = AbilitiesTextParser.parse('', style, context);
  expect(result.toPlainText(), '');
});

test('handles text without wildcards', () {
  final result = AbilitiesTextParser.parse('Flying, Vigilance', style, context);
  expect(result.toPlainText(), 'Flying, Vigilance');
  final span = result as TextSpan;
  expect(span.children, isNull); // No wildcards = no children
});

test('handles all 11 wildcards from database', () {
  final result = AbilitiesTextParser.parse(
    '{T} {W} {U} {B} {R} {G} {C} {0} {1} {2} {3}',
    style,
    context,
  );
  final span = result as TextSpan;
  // Should have 11 WidgetSpans (one per wildcard) + TextSpans for spaces
  expect(span.children!.whereType<WidgetSpan>().length, 11);
});
```

**Widget Tests:**
```dart
testWidgets('ColoredManaSymbol renders correctly', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ColoredManaSymbol(color: 'R', textHeight: 14),
      ),
    ),
  );

  expect(find.text('R'), findsOneWidget);
  expect(find.byType(Container), findsOneWidget);
});

testWidgets('GenericManaSymbol adapts to dark mode', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: GenericManaSymbol(value: '2', textHeight: 14, isDarkMode: true),
      ),
    ),
  );

  expect(find.text('2'), findsOneWidget);
  // Container color should be dark grey in dark mode
});

testWidgets('TapSymbolWidget uses correct icon', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TapSymbolWidget(textHeight: 14),
      ),
    ),
  );

  expect(find.byType(Icon), findsOneWidget);
});
```

### Visual Tests

**Manual Testing Checklist:**

Test with actual token abilities from database:
- [ ] Treasure token: `{T}, Sacrifice this artifact: Add {R} or {G}.` → tap icon + colored circles display
- [ ] Eldrazi Spawn: `Sacrifice this creature: Add {C}.` → grey circle with "C" displays
- [ ] Food token: `{2}, {T}, Sacrifice this token: Draw a card.` → grey circle "2" + tap icon displays
- [ ] Custom counter: `{1}{B}, Sacrifice a creature: You gain X life` → grey circle "1" + black circle "B" displays
- [ ] Test all 5 colored mana: `{W}` `{U}` `{B}` `{R}` `{G}` → all colored circles render with correct colors and white letters
- [ ] Create token with `{CUSTOM}` → brackets preserved as-is (no widget rendering)
- [ ] Edit token abilities in ExpandedTokenScreen → raw text with brackets intact
- [ ] Scroll through 50+ tokens on screen → no jank, smooth scrolling
- [ ] Test on iOS, Android, Web → widget symbols render consistently across platforms

**Visual Quality Checks:**
- [ ] Symbols aligned vertically with surrounding text (baseline alignment)
- [ ] Symbol size proportional to text height (not too large or small)
- [ ] Circle borders crisp and clean (no pixelation)
- [ ] Letters/numbers centered within circles
- [ ] Dark mode: Grey circles have appropriate contrast
- [ ] Light mode: Grey circles have appropriate contrast
- [ ] Colored mana: White text readable on all colored backgrounds
- [ ] Tap icon matches existing tap button icon style

### Database Coverage

**Database Analysis Complete:**

The token database (`assets/token_database.json`) was scanned for all `{wildcard}` patterns:

```bash
grep -o '{[^}]*}' assets/token_database.json | sort | uniq -c | sort -rn
```

**Results (100% coverage in Phase 1):**
- `{T}` - 30 occurrences (tap symbol)
- `{1}` - 18 occurrences (generic mana)
- `{2}` - 12 occurrences (generic mana)
- `{G}` - 10 occurrences (green mana)
- `{B}` - 9 occurrences (black mana)
- `{R}` - 6 occurrences (red mana)
- `{C}` - 5 occurrences (colorless mana)
- `{W}` - 2 occurrences (white mana)
- `{U}` - 1 occurrence (blue mana)
- `{3}` - 1 occurrence (generic mana)
- `{0}` - 1 occurrence (generic mana)

**Total:** 11 unique wildcards, 95 total occurrences across 883 tokens

**Phase 1 implementation provides 100% coverage of all wildcards in current database.**

## Future Enhancements

### User Preference Toggle

Add setting to enable/disable symbol replacement:

**Settings:**
- `SettingsProvider.symbolReplacementEnabled` (default: true)
- UI: Toggle in Settings screen under "Display Preferences"

**Rationale:**
- Some users may prefer seeing raw `{T}` text (performance, simplicity)
- Accessibility option for screen reader users
- Testing/debugging option

**Implementation:**
```dart
// In TokenCard
final showSymbols = context.watch<SettingsProvider>().symbolReplacementEnabled;

Text.rich(
  showSymbols
    ? AbilitiesTextParser.parse(widget.item.abilities, style, context)
    : TextSpan(text: widget.item.abilities, style: style),
)
```

### Symbol Animation

Animate symbols on certain events:

**Examples:**
- Pulse animation when mana symbol appears in newly created token
- Tap icon rotation animation matching tap/untap button behavior
- Fade-in when symbols first render

**Implementation:**
- Wrap symbol widgets in AnimatedContainer or custom animation
- Trigger animations on widget initialization or state changes

**Consideration:** May hurt performance, test thoroughly

### Extended Wildcard Support

Support additional wildcards as they appear in future token database updates:

**Phase 3 Candidates:**
- Untap symbol: `{Q}`
- Variable mana: `{X}`, `{Y}`, `{Z}`
- Extended generic mana: `{4}` - `{20}`
- Hybrid mana: `{W/U}`, `{B/R}`, etc. (two-colored circles)
- Phyrexian mana: `{W/P}`, `{U/P}`, etc. (circle with Phyrexian symbol)
- Half mana: `{HW}`, `{2/W}`, etc.
- Token type references: `{FOOD}`, `{TREASURE}`, `{CLUE}`, etc. (custom icons)

**Decision:** Only implement if wildcards appear in token database after regeneration

## Design Decisions (Resolved)

1. **Tap Icon:** ✅ Use the exact same icon as tap/untap action buttons
   - Ensures visual consistency across the app
   - Users already recognize this icon

2. **Performance:** ✅ Not a concern
   - Typically <10 tokens on screen at once
   - 95 total wildcard occurrences across entire database
   - WidgetSpan overhead negligible for this use case

3. **Accessibility:** ✅ Screen readers read unparsed text
   - Wrap parsed text in `Semantics` widget with `label` set to original unparsed text
   - Simple solution: screen readers ignore symbols, read original `{T}` text
   - Paper game requires reading cards anyway, baseline accessibility maintained

4. **Color Accuracy:** ✅ Use existing `ColorUtils` color values
   - Same colors as token expanded view (color identity selector)
   - Already tested for readability over gradients/artwork
   - Maintains visual consistency across app

5. **Symbol Sizing:** ✅ `textHeight * 1.1` (10% larger than text)
   - **Note:** May need tweaking based on visual testing
   - Start conservative, adjust if symbols feel too small

## Success Criteria

### Phase 1 Complete (Full Feature)
- [ ] `AbilitiesTextParser` implemented and tested
- [ ] Symbol widget classes implemented:
  - [ ] `TapSymbolWidget` using tap button icon
  - [ ] `ColoredManaSymbol` using ColorUtils colors
  - [ ] `GenericManaSymbol` with theme-aware grey circles
- [ ] All 11 wildcards from database render correctly:
  - [ ] `{T}` tap symbol
  - [ ] `{W}`, `{U}`, `{B}`, `{R}`, `{G}` colored mana
  - [ ] `{C}` colorless mana
  - [ ] `{0}`, `{1}`, `{2}`, `{3}` generic mana
- [ ] TokenCard renders symbols in abilities text
- [ ] Symbols wrapped in `Semantics` widget with unparsed text label
- [ ] Unrecognized wildcards render as-is (graceful fallback)
- [ ] ExpandedTokenScreen still shows raw text with brackets
- [ ] No performance degradation (verify with typical <10 tokens on screen)
- [ ] Unit tests pass for parser logic
- [ ] Widget tests pass for symbol widgets
- [ ] 100% coverage of wildcards in current token database

### Phase 2 Complete (Optional Enhancements)
- [ ] User preference toggle for symbol replacement on/off
- [ ] Symbol animations (optional)
- [ ] Fine-tune symbol sizing multiplier if visual testing shows 1.1x needs adjustment

## Migration Notes

**No Data Migration Required:**
- Symbol replacement is display-only
- Database stores raw text with `{brackets}` unchanged
- Backwards compatible with all existing tokens
- If feature is removed, text displays raw (no data loss)

**Deployment:**
- Safe to deploy incrementally (symbols appear as they're added to map)
- No user action required
- No risk of data corruption
