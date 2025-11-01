## PHASE 2: CORE UI COMPONENTS

**Objective:** Build main game view, token cards, and basic UI infrastructure.

**Estimated Time:** Week 2 (10-15 hours)

### 2.1 Color Utilities

Create `lib/utils/color_utils.dart`:

```dart
import 'package:flutter/material.dart';

class ColorUtils {
  static List<Color> getColorsForIdentity(String colorString) {
    final colors = <Color>[];

    if (colorString.contains('W')) colors.add(Colors.yellow);
    if (colorString.contains('U')) colors.add(Colors.blue);
    if (colorString.contains('B')) colors.add(Colors.purple);
    if (colorString.contains('R')) colors.add(Colors.red);
    if (colorString.contains('G')) colors.add(Colors.green);

    return colors.isEmpty ? [Colors.grey] : colors;
  }

  static LinearGradient gradientForColors(String colorString, {bool isEmblem = false}) {
    if (isEmblem) {
      return const LinearGradient(colors: [Colors.transparent, Colors.transparent]);
    }

    final colors = getColorsForIdentity(colorString);
    return LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
```

**Checklist:**
- [ ] Color mapping matches SwiftUI (W=yellow, etc.)
- [ ] Gradient generation function
- [ ] Emblem handling (transparent border)

---

### 2.2 Counter Pill Views

Create `lib/widgets/counter_pill.dart`:

```dart
import 'package:flutter/material.dart';
import '../models/token_counter.dart';

/// Simple counter display pill (for TokenCard)
class CounterPillView extends StatelessWidget {
  final String name;
  final int amount;

  const CounterPillView({
    Key? key,
    required this.name,
    required this.amount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey, // Solid background for high contrast
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white, // Inverted color scheme
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (amount > 1) ...[
            const SizedBox(width: 4),
            Text(
              '$amount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

Create `lib/widgets/counter_management_pill.dart`:

```dart
import 'package:flutter/material.dart';
import '../models/token_counter.dart';

/// Interactive counter pill with +/- buttons (for ExpandedTokenView)
class CounterManagementPillView extends StatelessWidget {
  final TokenCounter counter;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const CounterManagementPillView({
    Key? key,
    required this.counter,
    required this.onDecrement,
    required this.onIncrement,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_circle),
            color: Colors.red,
            iconSize: 24,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  counter.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${counter.amount}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_circle),
            color: Colors.green,
            iconSize: 24,
          ),
        ],
      ),
    );
  }
}
```

**Checklist:**
- [ ] CounterPillView uses inverted colors (solid bg, white text)
- [ ] CounterManagementPillView has +/- buttons
- [ ] Both match SwiftUI appearance

---

### 2.3 Color Selection Button

**CRITICAL**: This is a reusable component used in BOTH NewTokenSheet AND ExpandedTokenView.

Create `lib/widgets/color_selection_button.dart`:

```dart
import 'package:flutter/material.dart';

/// Color selection button for MTG color identity (WUBRG)
/// Used in NewTokenSheet and ExpandedTokenView
class ColorSelectionButton extends StatelessWidget {
  final String symbol; // W, U, B, R, or G
  final bool isSelected;
  final Color color; // The MTG color (yellow for W, blue for U, etc.)
  final String label; // "White", "Blue", etc.
  final ValueChanged<bool> onChanged;

  const ColorSelectionButton({
    Key? key,
    required this.symbol,
    required this.isSelected,
    required this.color,
    required this.label,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!isSelected),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Circle background
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? color : Colors.grey.withOpacity(0.3),
                ),
              ),

              // Symbol text
              Text(
                symbol,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              // Selection ring
              if (isSelected)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blue,
                      width: 3,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? null : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
```

**Usage Pattern** (from SwiftUI source):

In NewTokenSheet and ExpandedTokenView:
```dart
@override
void initState() {
  super.initState();
  // Load colors from item
  _whiteSelected = widget.item.colors.contains('W');
  _blueSelected = widget.item.colors.contains('U');
  _blackSelected = widget.item.colors.contains('B');
  _redSelected = widget.item.colors.contains('R');
  _greenSelected = widget.item.colors.contains('G');
}

// Update item when selection changes
void _updateColors() {
  String newColors = '';
  if (_whiteSelected) newColors += 'W';
  if (_blueSelected) newColors += 'U';
  if (_blackSelected) newColors += 'B';
  if (_redSelected) newColors += 'R';
  if (_greenSelected) newColors += 'G';

  widget.item.colors = newColors;
}

// In build method:
Row(
  mainAxisAlignment: MainAxisAlignment.spaceAround,
  children: [
    ColorSelectionButton(
      symbol: 'W',
      isSelected: _whiteSelected,
      color: Colors.yellow,
      label: 'White',
      onChanged: (value) {
        setState(() {
          _whiteSelected = value;
          _updateColors();
        });
      },
    ),
    ColorSelectionButton(
      symbol: 'U',
      isSelected: _blueSelected,
      color: Colors.blue,
      label: 'Blue',
      onChanged: (value) {
        setState(() {
          _blueSelected = value;
          _updateColors();
        });
      },
    ),
    // ... B, R, G
  ],
)
```

**Checklist:**
- [ ] ColorSelectionButton with circle + symbol
- [ ] Blue selection ring when selected
- [ ] Gray when unselected
- [ ] Tap toggles selection
- [ ] Used in both NewTokenSheet and ExpandedTokenView

---

### 2.4 Token Card Widget

Create `lib/widgets/token_card.dart`:

**CRITICAL**: This widget has complex gesture handling - requires special attention.

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/token_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/expanded_token_screen.dart';
import '../utils/color_utils.dart';
import 'counter_pill.dart';

class TokenCard extends StatefulWidget {
  final Item item;

  const TokenCard({Key? key, required this.item}) : super(key: key);

  @override
  State<TokenCard> createState() => _TokenCardState();
}

class _TokenCardState extends State<TokenCard> {
  String _tempAlertValue = '';

  @override
  Widget build(BuildContext context) {
    final tokenProvider = context.read<TokenProvider>();
    final settings = context.watch<SettingsProvider>();
    final multiplier = settings.tokenMultiplier;
    final summoningSicknessEnabled = settings.summoningSicknessEnabled;

    return Opacity(
      opacity: widget.item.amount == 0 ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: () {
          // Open expanded view
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ExpandedTokenScreen(item: widget.item),
              fullscreenDialog: true,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              width: 5,
              // CRITICAL: Gradient border - use custom painter
              color: Colors.transparent,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          // CRITICAL: Custom painter for gradient border
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: GradientBoxBorder(
              gradient: ColorUtils.gradientForColors(
                widget.item.colors,
                isEmblem: widget.item.isEmblem,
              ),
              width: 5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row - name, summoning sickness, tapped/untapped
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.name,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: widget.item.isEmblem ? TextAlign.center : TextAlign.left,
                    ),
                  ),
                  if (!widget.item.isEmblem) ...[
                    if (widget.item.summoningSick > 0 && summoningSicknessEnabled) ...[
                      const Icon(Icons.hexagon_outlined),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.item.summoningSick}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Icon(Icons.crop_portrait),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.item.amount - widget.item.tapped}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.crop_landscape),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.item.tapped}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ],
              ),

              // Counter pills
              if (widget.item.counters.isNotEmpty ||
                  widget.item.plusOneCounters > 0 ||
                  widget.item.minusOneCounters > 0) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    ...widget.item.counters.map(
                      (c) => CounterPillView(name: c.name, amount: c.amount),
                    ),
                    if (widget.item.plusOneCounters > 0)
                      CounterPillView(
                        name: '+1/+1',
                        amount: widget.item.plusOneCounters,
                      ),
                    if (widget.item.minusOneCounters > 0)
                      CounterPillView(
                        name: '-1/-1',
                        amount: widget.item.minusOneCounters,
                      ),
                  ],
                ),
              ],

              // Abilities
              if (widget.item.abilities.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.item.abilities,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: widget.item.isEmblem ? TextAlign.center : TextAlign.left,
                ),
              ],

              // Bottom row - controls and P/T
              if (!widget.item.isEmblem) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    // CRITICAL: Gesture handling - see outstanding questions
                    // Remove button with tap + long-press
                    _buildButton(
                      icon: Icons.remove,
                      onTap: () => _removeOne(tokenProvider),
                      onLongPress: () => _showRemoveDialog(context, tokenProvider),
                    ),
                    const SizedBox(width: 8),

                    // Add button
                    _buildButton(
                      icon: Icons.add,
                      onTap: () => _addTokens(tokenProvider, multiplier),
                      onLongPress: () => _showAddDialog(context, tokenProvider, multiplier),
                    ),
                    const SizedBox(width: 8),

                    // Tap button
                    _buildButton(
                      icon: Icons.refresh,
                      onTap: () => _tapOne(),
                      onLongPress: () => _showTapDialog(context),
                    ),
                    const SizedBox(width: 8),

                    // Untap button
                    _buildButton(
                      icon: Icons.restart_alt,
                      onTap: () => _untapOne(),
                      onLongPress: () => _showUntapDialog(context),
                    ),
                    const SizedBox(width: 8),

                    // Copy button
                    _buildButton(
                      icon: Icons.content_copy,
                      onTap: () => _copyToken(tokenProvider, multiplier),
                      onLongPress: null,
                    ),

                    // Scute Swarm special button
                    if (widget.item.name.toUpperCase() == 'SCUTE SWARM') ...[
                      const SizedBox(width: 8),
                      _buildButton(
                        icon: Icons.bug_report,
                        onTap: () {
                          widget.item.amount *= 2;
                          tokenProvider.updateItem(widget.item);
                        },
                        onLongPress: null,
                      ),
                    ],

                    const Spacer(),

                    // Power/Toughness
                    if (widget.item.isPowerToughnessModified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.item.formattedPowerToughness,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      )
                    else
                      Text(
                        widget.item.formattedPowerToughness,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required VoidCallback? onTap,
    required VoidCallback? onLongPress,
  }) {
    // OUTSTANDING QUESTION: How to handle simultaneous tap + long-press in Flutter?
    // SwiftUI uses .simultaneousGesture() but Flutter's GestureDetector doesn't support this directly
    // Current implementation: separate tap and long-press (works but UX differs)
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Icon(icon, size: 24),
    );
  }

  void _removeOne(TokenProvider provider) {
    if (widget.item.amount > 0) {
      if (widget.item.amount - widget.item.tapped <= 0) {
        widget.item.tapped -= 1;
      }
      if (widget.item.amount - widget.item.summoningSick <= 0) {
        widget.item.summoningSick -= 1;
      }
      widget.item.amount -= 1;
      provider.updateItem(widget.item);
    }
  }

  void _addTokens(TokenProvider provider, int multiplier) {
    widget.item.amount += multiplier;
    widget.item.summoningSick += multiplier; // Always track summoning sickness
    provider.updateItem(widget.item);
  }

  void _tapOne() {
    if (widget.item.tapped < widget.item.amount) {
      widget.item.tapped += 1;
    }
  }

  void _untapOne() {
    if (widget.item.tapped > 0) {
      widget.item.tapped -= 1;
    }
  }

  void _copyToken(TokenProvider provider, int multiplier) {
    final newItem = widget.item.createDuplicate();
    newItem.amount = multiplier;
    newItem.summoningSick = multiplier;
    provider.insertItem(newItem);
  }

  // OUTSTANDING QUESTION: Dialog implementations
  void _showRemoveDialog(BuildContext context, TokenProvider provider) {
    // TODO: Implement text field dialog with "Remove" and "Reset" buttons
  }

  void _showAddDialog(BuildContext context, TokenProvider provider, int multiplier) {
    // TODO: Implement text field dialog with multiplier message
  }

  void _showTapDialog(BuildContext context) {
    // TODO: Implement text field dialog
  }

  void _showUntapDialog(BuildContext context) {
    // TODO: Implement text field dialog
  }
}

// OUTSTANDING QUESTION: How to implement gradient border in Flutter?
// CustomPainter or third-party package?
class GradientBoxBorder extends BoxBorder {
  final Gradient gradient;
  final double width;

  const GradientBoxBorder({required this.gradient, this.width = 1.0});

  @override
  BorderSide get bottom => BorderSide.none;

  @override
  BorderSide get top => BorderSide.none;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  bool get isUniform => true;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    // OUTSTANDING QUESTION: Gradient border implementation
    // Needs custom paint logic
  }

  @override
  ShapeBorder scale(double t) => this;
}
```

**CRITICAL NOTES FOR TOKEN CARD:**
1. Gesture handling differs from SwiftUI - see Outstanding Questions
2. Gradient border needs custom implementation
3. Dialog implementations incomplete
4. Scute Swarm special case handled

**Checklist:**
- [ ] Basic layout matches SwiftUI
- [ ] Counter pills display correctly
- [ ] Tap gesture opens ExpandedTokenScreen
- [ ] Opacity changes when amount is 0
- [ ] P/T modification highlighting works
- [ ] Scute Swarm button appears

---

### 2.4 Multiplier View

Create `lib/widgets/multiplier_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';

class MultiplierView extends StatefulWidget {
  const MultiplierView({Key? key}) : super(key: key);

  @override
  State<MultiplierView> createState() => _MultiplierViewState();
}

class _MultiplierViewState extends State<MultiplierView> {
  bool _showControls = false;
  final TextEditingController _manualInputController = TextEditingController();

  @override
  void dispose() {
    _manualInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final multiplier = settings.tokenMultiplier;

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      onLongPress: () => _showManualInput(context, settings, multiplier),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _showControls
            ? _buildExpandedControls(context, settings, multiplier)
            : _buildCollapsedBadge(multiplier),
      ),
    );
  }

  Widget _buildCollapsedBadge(int multiplier) {
    return Container(
      key: const ValueKey('collapsed'),
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'x$multiplier',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedControls(BuildContext context, SettingsProvider settings, int multiplier) {
    return Container(
      key: const ValueKey('expanded'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: multiplier > GameConstants.minMultiplier
                ? () => settings.setTokenMultiplier(multiplier - 1)
                : null,
            icon: const Icon(Icons.remove),
            color: Colors.blue,
          ),
          GestureDetector(
            onLongPress: () => _showManualInput(context, settings, multiplier),
            child: Text(
              'x$multiplier',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ),
          IconButton(
            onPressed: () => settings.setTokenMultiplier(multiplier + 1),
            icon: const Icon(Icons.add),
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  void _showManualInput(BuildContext context, SettingsProvider settings, int multiplier) {
    _manualInputController.text = multiplier.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Multiplier'),
        content: TextField(
          controller: _manualInputController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Enter multiplier value',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(_manualInputController.text);
              if (value != null && value >= GameConstants.minMultiplier) {
                settings.setTokenMultiplier(value);
              }
              Navigator.pop(context);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}
```

**CRITICAL**: MultiplierView uses +1/-1 increments (not ×2/÷2). This matches current SwiftUI implementation.

**Checklist:**
- [ ] Collapsed state shows circular badge
- [ ] Expanded state shows +/- buttons
- [ ] Long-press opens manual input dialog
- [ ] Tap toggles between states
- [ ] Animation smooth
- [ ] Multiplier clamped to 1-1024

---

### 2.5 Content Screen (Main View)

Create `lib/screens/content_screen.dart`:

**OUTSTANDING QUESTION**: How to position MultiplierView overlay at bottom of screen without blocking list?

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/token_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/token_card.dart';
import '../widgets/multiplier_view.dart';
import 'token_search_screen.dart';
import 'about_screen.dart';

class ContentScreen extends StatefulWidget {
  const ContentScreen({Key? key}) : super(key: key);

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Token list
          _buildTokenList(),

          // Multiplier view overlay (bottom center)
          // OUTSTANDING QUESTION: Padding logic for list to avoid overlap?
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: const Center(
              child: MultiplierView(),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    final tokenProvider = context.watch<TokenProvider>();
    final settings = context.watch<SettingsProvider>();

    return AppBar(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Plus button
          IconButton(
            onPressed: () => _showTokenSearch(),
            icon: const Icon(Icons.add),
          ),

          // Untap all
          IconButton(
            onPressed: () => _showUntapAllDialog(),
            icon: const Icon(Icons.refresh),
          ),

          // Clear summoning sickness
          GestureDetector(
            onTap: () => tokenProvider.clearSummoningSickness(),
            onLongPress: () => _showSummoningSicknessToggle(),
            child: const Icon(Icons.hexagon_outlined),
          ),

          // Save deck
          IconButton(
            onPressed: () => _showSaveDeckDialog(),
            icon: const Icon(Icons.save),
          ),

          // Load deck
          IconButton(
            onPressed: () => _showLoadDeckSheet(),
            icon: const Icon(Icons.folder_open),
          ),

          // Board wipe
          IconButton(
            onPressed: () => _showBoardWipeDialog(),
            icon: const Icon(Icons.delete_sweep),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => _showAbout(),
          icon: const Icon(Icons.help_outline),
        ),
      ],
    );
  }

  Widget _buildTokenList() {
    return Consumer<TokenProvider>(
      builder: (context, provider, child) {
        if (provider.items.isEmpty) {
          return _buildEmptyState();
        }

        return ValueListenableBuilder<Box<Item>>(
          valueListenable: provider.listenable,
          builder: (context, box, _) {
            final items = box.values.toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

            return ListView.builder(
              itemCount: items.length,
              padding: const EdgeInsets.only(
                top: 8,
                left: 8,
                right: 8,
                bottom: 120, // OUTSTANDING QUESTION: Calculate based on MultiplierView height?
              ),
              itemExtent: 120, // CRITICAL: Fixed height for performance
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Dismissible(
                    key: ValueKey(items[index].key), // CRITICAL: Use Hive key
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => provider.deleteItem(items[index]),
                    child: TokenCard(item: items[index]),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No tokens to display',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () => _showTokenSearch(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create your first token'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('Untap Everything'),
                    dense: true,
                  ),
                  const ListTile(
                    leading: Icon(Icons.hexagon_outlined),
                    title: Text('Clear Summoning Sickness'),
                    dense: true,
                  ),
                  const ListTile(
                    leading: Icon(Icons.save),
                    title: Text('Save Current Deck'),
                    dense: true,
                  ),
                  const ListTile(
                    leading: Icon(Icons.folder_open),
                    title: Text('Load a Deck'),
                    dense: true,
                  ),
                  const ListTile(
                    leading: Icon(Icons.delete_sweep),
                    title: Text('Board Wipe'),
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Long press the +/- and tap/untap buttons to mass edit a token group.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTokenSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TokenSearchScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  // OUTSTANDING QUESTION: Dialog implementations
  void _showUntapAllDialog() {
    // TODO
  }

  void _showSummoningSicknessToggle() {
    // TODO
  }

  void _showSaveDeckDialog() {
    // TODO
  }

  void _showLoadDeckSheet() {
    // TODO
  }

  void _showBoardWipeDialog() {
    // TODO
  }

  void _showAbout() {
    // TODO
  }
}
```

**CRITICAL NOTES:**
1. ValueListenableBuilder for reactive updates (optimization)
2. Fixed itemExtent for 60fps scrolling
3. Dismissible for swipe-to-delete
4. Padding at bottom to avoid MultiplierView overlap

**Checklist:**
- [ ] Empty state displays correctly
- [ ] Token list scrolls smoothly
- [ ] Swipe-to-delete works
- [ ] All toolbar buttons present
- [ ] MultiplierView doesn't block last token

---

### Phase 2 Validation

**Checklist:**
- [ ] ContentScreen displays empty state
- [ ] Empty state "Create your first token" button functional
- [ ] Toolbar buttons present (even if not functional yet)
- [ ] MultiplierView appears and animates
- [ ] Can create a test token manually (via code) and it displays
- [ ] Token card displays correctly
- [ ] Counter pills visible and styled correctly
- [ ] No crashes or rendering issues

---

