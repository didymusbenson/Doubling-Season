## PHASE 4: ADVANCED FEATURES

**Objective:** Implement expanded token view, stack splitting, counter management, and deck loading.

**Estimated Time:** Week 4 (14-18 hours)

### 4.1 Load Deck Sheet

Create `lib/widgets/load_deck_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../providers/token_provider.dart';

class LoadDeckSheet extends StatelessWidget {
  const LoadDeckSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final deckProvider = context.watch<DeckProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Load Deck'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Deck>>(
        future: deckProvider.decks,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 20),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final decks = snapshot.data ?? [];

          if (decks.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 60, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'No saved decks',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: decks.length,
            itemBuilder: (context, index) {
              final deck = decks[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    deck.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text('${deck.templates.length} tokens'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteConfirmation(
                          context,
                          deck,
                          deckProvider,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _loadDeck(context, deck),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _loadDeck(BuildContext context, Deck deck) {
    final tokenProvider = context.read<TokenProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load Deck'),
        content: Text('Load "${deck.name}"?\n\nThis will replace all current tokens.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Clear current tokens
              await tokenProvider.boardWipeDelete();

              // Load deck templates
              // BUG WARNING: SwiftUI LoadDeckSheet.swift line 107 has a bug where it creates
              // items with amount: 0 instead of the saved amount from the template.
              // This Flutter implementation FIXES that bug by properly using template values.
              for (final template in deck.templates) {
                final item = template.toItem();
                await tokenProvider.insertItem(item);
              }

              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close load deck sheet

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Loaded deck "${deck.name}"')),
              );
            },
            child: const Text('Load'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    Deck deck,
    DeckProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Deck'),
        content: Text('Delete "${deck.name}"?\n\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await provider.deleteDeck(deck);
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted deck "${deck.name}"')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
```

**Checklist:**
- [ ] FutureBuilder for async deck loading
- [ ] Empty state displayed
- [ ] Deck list with token count
- [ ] Delete button with confirmation
- [ ] Load button with confirmation
- [ ] Board wipe before loading deck
- [ ] Snackbar feedback

---

### 4.2 Counter Search View

Create `lib/screens/counter_search_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../database/counter_database.dart';
import '../models/item.dart';
import '../providers/token_provider.dart';
import 'package:provider/provider.dart';

class CounterSearchScreen extends StatefulWidget {
  final Item item;
  final bool applyToAll; // Apply to entire stack vs individual token

  const CounterSearchScreen({
    Key? key,
    required this.item,
    this.applyToAll = true,
  }) : super(key: key);

  @override
  State<CounterSearchScreen> createState() => _CounterSearchScreenState();
}

class _CounterSearchScreenState extends State<CounterSearchScreen> {
  final _searchController = TextEditingController();
  final _counterDatabase = CounterDatabase();
  List<String> _filteredCounters = [];

  @override
  void initState() {
    super.initState();
    _filteredCounters = _counterDatabase.predefinedCounters;
    _searchController.addListener(_filterCounters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCounters() {
    setState(() {
      _filteredCounters = _counterDatabase.searchCounters(_searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Counter'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search counters...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ),

          // Counter list
          Expanded(
            child: ListView.builder(
              itemCount: _filteredCounters.length,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (context, index) {
                final counter = _filteredCounters[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      counter,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: const Icon(Icons.add_circle, color: Colors.blue),
                    onTap: () => _showAddToAllOrOneDialog(counter),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // CRITICAL: SwiftUI CounterSearchView shows "Add to All" vs "Add to One" choice FIRST
  void _showAddToAllOrOneDialog(String counterName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add $counterName Counter'),
        content: const Text(
          'Do you want to add this counter to all tokens in the stack, '
          'or split the stack and add to just one token?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showQuantityDialog(counterName, applyToAll: true);
            },
            child: const Text('Add to All'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showQuantityDialog(counterName, applyToAll: false);
            },
            child: const Text('Split & Add to One'),
          ),
        ],
      ),
    );
  }

  void _showQuantityDialog(String counterName, {required bool applyToAll}) {
    int quantity = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add $counterName Counters'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: quantity > 1
                        ? () => setDialogState(() => quantity--)
                        : null,
                    icon: const Icon(Icons.remove_circle),
                    iconSize: 32,
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '$quantity',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setDialogState(() => quantity++),
                    icon: const Icon(Icons.add_circle),
                    iconSize: 32,
                  ),
                ],
              ),
              if (!applyToAll) ...[
                const SizedBox(height: 16),
                const Text(
                  'This will split the stack and add counters to one token only',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _addCounter(counterName, quantity, applyToAll: applyToAll);
                Navigator.pop(context); // Close quantity dialog
                Navigator.pop(context); // Close counter search
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _addCounter(String name, int amount, {required bool applyToAll}) {
    final tokenProvider = context.read<TokenProvider>();

    if (applyToAll) {
      // Add counter to entire stack
      widget.item.addCounter(name: name, amount: amount);
      tokenProvider.updateItem(widget.item);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added $amount $name counter(s) to all tokens')),
      );
    } else {
      // Split stack: create new item with 1 token + counter
      if (widget.item.amount < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot split - only 1 token in stack')),
        );
        return;
      }

      // Create new single-token stack with counter
      final newItem = widget.item.createDuplicate();
      newItem.amount = 1;
      newItem.tapped = 0;
      newItem.summoningSick = 0;
      newItem.addCounter(name: name, amount: amount);

      // Reduce original stack by 1
      widget.item.amount = widget.item.amount - 1;

      tokenProvider.updateItem(widget.item);
      tokenProvider.insertItem(newItem);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Split stack and added $amount $name counter(s) to 1 token')),
      );
    }
  }
}
```

**CRITICAL PATTERN**: The "Add to All vs Add to One" dialog is shown BEFORE the quantity dialog.
This is a key UX pattern from the SwiftUI source code.

**Checklist:**
- [ ] Search bar filters counters
- [ ] Predefined counter list
- [ ] **"Add to All vs Add to One" dialog shown first**
- [ ] Quantity dialog with stepper (shown second)
- [ ] Apply to all adds counter to entire stack
- [ ] Apply to one automatically splits stack and adds to single token
- [ ] Validation prevents splitting stack with only 1 token
- [ ] Snackbar feedback

---

### 4.3 Split Stack View

**ACTUAL IMPLEMENTATION FROM SOURCE** (SplitStackView.swift):

Create `lib/widgets/split_stack_sheet.dart`:

**CRITICAL**: This is MUCH SIMPLER than expected - single stepper + "Tapped First" toggle.

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/token_provider.dart';

class SplitStackSheet extends StatefulWidget {
  final Item item;
  final VoidCallback? onSplitCompleted; // Optional callback from ExpandedTokenView

  const SplitStackSheet({
    Key? key,
    required this.item,
    this.onSplitCompleted,
  }) : super(key: key);

  @override
  State<SplitStackSheet> createState() => _SplitStackSheetState();
}

class _SplitStackSheetState extends State<SplitStackSheet> {
  late int _splitAmount; // How many tokens to split off
  bool _tappedFirst = false; // Whether to move tapped tokens first

  int get maxSplit => widget.item.amount > 1 ? widget.item.amount - 1 : 1;

  @override
  void initState() {
    super.initState();
    _splitAmount = 1; // Default: split off 1 token
    // Validate splitAmount doesn't exceed maxSplit
    if (_splitAmount > maxSplit) {
      _splitAmount = maxSplit.clamp(1, widget.item.amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Stack'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Splitting: ${widget.item.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current amount: ${widget.item.amount}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        Text(
                          'Tapped: ${widget.item.tapped}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Split amount selection
            const Text(
              'Number of tokens to split off:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _splitAmount > 1
                        ? () => setState(() => _splitAmount--)
                        : null,
                    icon: Icon(
                      Icons.remove_circle,
                      color: _splitAmount > 1 ? Colors.blue : Colors.grey,
                    ),
                    iconSize: 32,
                  ),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: '$_splitAmount'),
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null) {
                          setState(() {
                            _splitAmount = parsed.clamp(1, maxSplit);
                          });
                        }
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: _splitAmount < maxSplit
                        ? () => setState(() => _splitAmount++)
                        : null,
                    icon: Icon(
                      Icons.add_circle,
                      color: _splitAmount < maxSplit ? Colors.blue : Colors.grey,
                    ),
                    iconSize: 32,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Divider(),

            const SizedBox(height: 16),

            // Tapped first toggle
            SwitchListTile(
              title: const Text(
                'Tapped First',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'When enabled, tapped tokens will be moved to the new stack first.',
                style: TextStyle(fontSize: 12),
              ),
              value: _tappedFirst,
              onChanged: (value) => setState(() => _tappedFirst = value),
            ),

            const SizedBox(height: 24),

            const Divider(),

            const SizedBox(height: 16),

            // Preview
            Card(
              color: Colors.blue.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'After split:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...(() {
                      final result = _calculateSplit();
                      return [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Original Stack'),
                            Text(
                              'Amount: ${result.originalAmount}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              'Tapped: ${result.originalTapped}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('New Stack'),
                            Text(
                              'Amount: ${result.newAmount}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              'Tapped: ${result.newTapped}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ];
                    })(),
                  ],
                ),
              ),
            ),

            if (widget.item.summoningSick > 0) ...[
              const SizedBox(height: 12),
              const Text(
                'Note: Splitting will remove summoning sickness from both stacks.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],

            const Spacer(),

            // Split button
            ElevatedButton(
              onPressed: _splitAmount >= widget.item.amount ? null : _performSplit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.blue,
                disabledBackgroundColor: Colors.grey,
              ),
              child: const Text(
                'Split Stack',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SplitResult _calculateSplit() {
    final currentTapped = widget.item.tapped;

    if (_tappedFirst) {
      // Move tapped tokens to new stack first
      final newTapped = _splitAmount < currentTapped ? _splitAmount : currentTapped;
      final originalTapped = currentTapped - newTapped;

      return SplitResult(
        originalAmount: widget.item.amount - _splitAmount,
        originalTapped: originalTapped,
        newAmount: _splitAmount,
        newTapped: newTapped,
      );
    } else {
      // Move untapped tokens to new stack first
      final availableUntapped = widget.item.amount - currentTapped;
      final newUntapped = _splitAmount < availableUntapped ? _splitAmount : availableUntapped;
      final newTapped = _splitAmount - newUntapped;
      final originalTapped = currentTapped - newTapped;

      return SplitResult(
        originalAmount: widget.item.amount - _splitAmount,
        originalTapped: originalTapped,
        newAmount: _splitAmount,
        newTapped: newTapped,
      );
    }
  }

  void _performSplit() {
    final result = _calculateSplit();

    // CRITICAL: Dismiss sheet FIRST (early dismiss pattern from SplitStackView.swift:146)
    Navigator.pop(context);

    // CRITICAL: Use Future.delayed to ensure sheet fully dismissed before Hive operations
    Future.delayed(const Duration(milliseconds: 100), () {
      final tokenProvider = context.read<TokenProvider>();

      // Update original stack
      widget.item.amount = result.originalAmount;
      widget.item.tapped = result.originalTapped;
      widget.item.summoningSick = 0; // Clear summoning sickness
      tokenProvider.updateItem(widget.item);

      // Create new stack
      final newItem = widget.item.createDuplicate();
      newItem.amount = result.newAmount;
      newItem.tapped = result.newTapped;
      newItem.summoningSick = 0; // Clear summoning sickness

      tokenProvider.insertItem(newItem);

      // Call completion callback if provided
      widget.onSplitCompleted?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stack split successfully')),
      );
    });
  }
}

class SplitResult {
  final int originalAmount;
  final int originalTapped;
  final int newAmount;
  final int newTapped;

  SplitResult({
    required this.originalAmount,
    required this.originalTapped,
    required this.newAmount,
    required this.newTapped,
  });
}
```

**CRITICAL NOTES:**
1. **MUCH SIMPLER** than my original - just single stepper + toggle!
2. **Early Dismiss Pattern**: `dismiss()` then `Future.delayed(100ms)` then perform split
3. **"Tapped First" toggle**: Controls whether tapped or untapped tokens move to new stack first
4. **Simple calculation**: Based on tapped first flag, allocate tokens accordingly
5. **Counters always copied**: No toggle in actual source (counters always copied via createDuplicate)
6. **Summoning sickness cleared**: Both stacks get summoningSick = 0

**Checklist:**
- [ ] Single stepper for split amount (1 to maxSplit)
- [ ] "Tapped First" toggle
- [ ] Preview of both stacks after split
- [ ] Early dismiss pattern implemented
- [ ] Future.delayed(100ms) before Hive operations
- [ ] Summoning sickness cleared on both stacks
- [ ] Counters copied automatically via createDuplicate
- [ ] Snackbar feedback

---

### 4.4 Expanded Token View

Create `lib/screens/expanded_token_screen.dart`:

**CRITICAL**: This screen has tap-to-edit fields and complex counter management.

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/token_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/counter_management_pill.dart';
import '../widgets/color_selection_button.dart';
import '../widgets/split_stack_sheet.dart';
import '../screens/counter_search_screen.dart';
import '../utils/color_utils.dart';

class ExpandedTokenScreen extends StatefulWidget {
  final Item item;

  const ExpandedTokenScreen({Key? key, required this.item}) : super(key: key);

  @override
  State<ExpandedTokenScreen> createState() => _ExpandedTokenScreenState();
}

class _ExpandedTokenScreenState extends State<ExpandedTokenScreen> {
  EditableField? _editingField;
  final Map<EditableField, TextEditingController> _controllers = {};
  final Map<EditableField, FocusNode> _focusNodes = {};

  // CRITICAL: SwiftUI ExpandedTokenView uses ColorSelectionButton for colors
  late bool _whiteSelected;
  late bool _blueSelected;
  late bool _blackSelected;
  late bool _redSelected;
  late bool _greenSelected;

  @override
  void initState() {
    super.initState();
    for (final field in EditableField.values) {
      _controllers[field] = TextEditingController();
      _focusNodes[field] = FocusNode();
    }

    // Initialize color selections from item
    _whiteSelected = widget.item.colors.contains('W');
    _blueSelected = widget.item.colors.contains('U');
    _blackSelected = widget.item.colors.contains('B');
    _redSelected = widget.item.colors.contains('R');
    _greenSelected = widget.item.colors.contains('G');
  }

  void _updateColors() {
    String newColors = '';
    if (_whiteSelected) newColors += 'W';
    if (_blueSelected) newColors += 'U';
    if (_blackSelected) newColors += 'B';
    if (_redSelected) newColors += 'R';
    if (_greenSelected) newColors += 'G';

    widget.item.colors = newColors;
    context.read<TokenProvider>().updateItem(widget.item);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokenProvider = context.watch<TokenProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Token Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_split),
            onPressed: () => _showSplitStack(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              tokenProvider.deleteItem(widget.item);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Token Name
            _buildEditableField(
              label: 'Name',
              field: EditableField.name,
              value: widget.item.name,
              onSave: (value) => widget.item.name = value,
            ),

            const SizedBox(height: 16),

            // Power/Toughness
            _buildEditableField(
              label: 'Power/Toughness',
              field: EditableField.powerToughness,
              value: widget.item.pt,
              onSave: (value) => widget.item.pt = value,
            ),

            const SizedBox(height: 16),

            // Colors (using ColorSelectionButton from Phase 2)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Colors',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ColorSelectionButton(
                        symbol: 'W',
                        isSelected: _whiteSelected,
                        color: Colors.yellow,
                        label: 'White',
                        onChanged: (value) {
                          setState(() => _whiteSelected = value);
                          _updateColors();
                        },
                      ),
                      ColorSelectionButton(
                        symbol: 'U',
                        isSelected: _blueSelected,
                        color: Colors.blue,
                        label: 'Blue',
                        onChanged: (value) {
                          setState(() => _blueSelected = value);
                          _updateColors();
                        },
                      ),
                      ColorSelectionButton(
                        symbol: 'B',
                        isSelected: _blackSelected,
                        color: Colors.purple,
                        label: 'Black',
                        onChanged: (value) {
                          setState(() => _blackSelected = value);
                          _updateColors();
                        },
                      ),
                      ColorSelectionButton(
                        symbol: 'R',
                        isSelected: _redSelected,
                        color: Colors.red,
                        label: 'Red',
                        onChanged: (value) {
                          setState(() => _redSelected = value);
                          _updateColors();
                        },
                      ),
                      ColorSelectionButton(
                        symbol: 'G',
                        isSelected: _greenSelected,
                        color: Colors.green,
                        label: 'Green',
                        onChanged: (value) {
                          setState(() => _greenSelected = value);
                          _updateColors();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Abilities
            _buildEditableField(
              label: 'Abilities',
              field: EditableField.abilities,
              value: widget.item.abilities,
              onSave: (value) => widget.item.abilities = value,
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // Amount Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Token Counts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Total Amount
                    _buildCountRow(
                      icon: Icons.functions,
                      label: 'Total Amount',
                      value: widget.item.amount,
                      onIncrement: () {
                        widget.item.amount++;
                        tokenProvider.updateItem(widget.item);
                      },
                      onDecrement: widget.item.amount > 0
                          ? () {
                              widget.item.amount--;
                              tokenProvider.updateItem(widget.item);
                            }
                          : null,
                    ),

                    const Divider(height: 24),

                    if (!widget.item.isEmblem) ...[
                      // Untapped
                      _buildCountRow(
                        icon: Icons.crop_portrait,
                        label: 'Untapped',
                        value: widget.item.amount - widget.item.tapped,
                        showButtons: false,
                      ),

                      const SizedBox(height: 12),

                      // Tapped
                      _buildCountRow(
                        icon: Icons.crop_landscape,
                        label: 'Tapped',
                        value: widget.item.tapped,
                        onIncrement: widget.item.tapped < widget.item.amount
                            ? () {
                                widget.item.tapped++;
                                tokenProvider.updateItem(widget.item);
                              }
                            : null,
                        onDecrement: widget.item.tapped > 0
                            ? () {
                                widget.item.tapped--;
                                tokenProvider.updateItem(widget.item);
                              }
                            : null,
                      ),

                      const Divider(height: 24),

                      // Summoning Sickness
                      if (settings.summoningSicknessEnabled) ...[
                        _buildCountRow(
                          icon: Icons.hexagon_outlined,
                          label: 'Summoning Sick',
                          value: widget.item.summoningSick,
                          onIncrement:
                              widget.item.summoningSick < widget.item.amount
                                  ? () {
                                      widget.item.summoningSick++;
                                      tokenProvider.updateItem(widget.item);
                                    }
                                  : null,
                          onDecrement: widget.item.summoningSick > 0
                              ? () {
                                  widget.item.summoningSick--;
                                  tokenProvider.updateItem(widget.item);
                                }
                              : null,
                        ),
                        const Divider(height: 24),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Power/Toughness Counters Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Power/Toughness Counters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // +1/+1 Counters
                    Row(
                      children: [
                        const Expanded(child: Text('+1/+1 Counters')),
                        IconButton(
                          onPressed: widget.item.plusOneCounters > 0
                              ? () {
                                  widget.item.addPowerToughnessCounters(-1);
                                  tokenProvider.updateItem(widget.item);
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${widget.item.plusOneCounters}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            widget.item.addPowerToughnessCounters(1);
                            tokenProvider.updateItem(widget.item);
                          },
                          icon: const Icon(Icons.add_circle, color: Colors.green),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // -1/-1 Counters
                    Row(
                      children: [
                        const Expanded(child: Text('-1/-1 Counters')),
                        IconButton(
                          onPressed: widget.item.minusOneCounters > 0
                              ? () {
                                  widget.item.addPowerToughnessCounters(1);
                                  tokenProvider.updateItem(widget.item);
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${widget.item.minusOneCounters}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            widget.item.addPowerToughnessCounters(-1);
                            tokenProvider.updateItem(widget.item);
                          },
                          icon: const Icon(Icons.add_circle, color: Colors.green),
                        ),
                      ],
                    ),

                    if (widget.item.netPlusOneCounters != 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Modified P/T:'),
                            Text(
                              widget.item.formattedPowerToughness,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Custom Counters Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Custom Counters',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.blue),
                          onPressed: () => _showCounterSearch(context),
                        ),
                      ],
                    ),

                    if (widget.item.counters.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'No custom counters',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else ...[
                      const SizedBox(height: 12),
                      ...widget.item.counters.map((counter) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: CounterManagementPillView(
                            counter: counter,
                            onDecrement: () {
                              widget.item.removeCounter(name: counter.name);
                              tokenProvider.updateItem(widget.item);
                            },
                            onIncrement: () {
                              widget.item.addCounter(name: counter.name);
                              tokenProvider.updateItem(widget.item);
                            },
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required EditableField field,
    required String value,
    required ValueChanged<String> onSave,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    final isEditing = _editingField == field;

    return GestureDetector(
      onTap: isEditing
          ? null
          : () {
              _controllers[field]!.text = value;
              setState(() => _editingField = field);
              _focusNodes[field]!.requestFocus();
            },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isEditing ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEditing ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            isEditing
                ? TextField(
                    controller: _controllers[field],
                    focusNode: _focusNodes[field],
                    maxLines: maxLines,
                    textCapitalization: textCapitalization,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(fontSize: 16),
                    onSubmitted: (newValue) {
                      onSave(newValue);
                      setState(() => _editingField = null);
                    },
                  )
                : Text(
                    value.isEmpty ? 'Tap to edit' : value,
                    style: TextStyle(
                      fontSize: 16,
                      color: value.isEmpty ? Colors.grey : null,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountRow({
    required IconData icon,
    required String label,
    required int value,
    VoidCallback? onIncrement,
    VoidCallback? onDecrement,
    bool showButtons = true,
  }) {
    return Row(
      children: [
        Icon(icon, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        if (showButtons) ...[
          IconButton(
            onPressed: onDecrement,
            icon: Icon(
              Icons.remove_circle,
              color: onDecrement != null ? Colors.red : Colors.grey,
            ),
          ),
        ],
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (showButtons) ...[
          IconButton(
            onPressed: onIncrement,
            icon: Icon(
              Icons.add_circle,
              color: onIncrement != null ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ],
    );
  }

  void _showSplitStack(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SplitStackSheet(item: widget.item),
        fullscreenDialog: true,
      ),
    );
  }

  void _showCounterSearch(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CounterSearchScreen(item: widget.item),
        fullscreenDialog: true,
      ),
    );
  }
}

enum EditableField {
  name,
  powerToughness,
  abilities,
  // Note: colors removed - uses ColorSelectionButton instead
}
```

**CRITICAL NOTES:**
1. Tap-to-edit pattern for name, P/T, and abilities fields
2. **ColorSelectionButton used for colors** (not tap-to-edit TextField)
3. FocusNode management for keyboard handling on tap-to-edit fields
4. Counter management with +/- buttons
5. Modified P/T display when counters present
6. Split stack button in app bar
7. Delete button in app bar

**Checklist:**
- [ ] Name field tap-to-edit
- [ ] P/T field tap-to-edit
- [ ] Abilities field tap-to-edit
- [ ] **ColorSelectionButton for color selection (W/U/B/R/G)**
- [ ] Keyboard appears on edit
- [ ] Enter key saves field
- [ ] Amount, tapped, summoning sick counters
- [ ] +1/+1 and -1/-1 counter interaction
- [ ] Modified P/T displayed
- [ ] Custom counter management pills
- [ ] Add counter button opens search
- [ ] Split stack button works
- [ ] Delete button with confirmation

---

### Phase 4 Validation

**Checklist:**
- [ ] Load deck sheet displays saved decks
- [ ] Deck loading replaces current tokens
- [ ] Deck deletion works with confirmation
- [ ] Counter search filters correctly
- [ ] Counter quantity dialog works
- [ ] Split stack sheet validates totals
- [ ] Split stack early dismiss prevents crashes
- [ ] Counter copy toggle works
- [ ] Expanded token view all fields editable
- [ ] Counter management fully functional
- [ ] All Phase 4 features integrated with Phase 1-3

---

