## PHASE 3: TOKEN INTERACTIONS

**Objective:** Implement token search, creation, and basic interactions.

**Estimated Time:** Week 3 (12-16 hours)

### 3.1 Token Search Screen

Create `lib/screens/token_search_screen.dart`:

**CRITICAL**: This screen has complex state management with tabs, search, categories, and quantity dialog.

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/token_definition.dart';
import '../database/token_database.dart';
import '../providers/token_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/new_token_sheet.dart';

enum SearchTab { all, recent, favorites }

class TokenSearchScreen extends StatefulWidget {
  const TokenSearchScreen({Key? key}) : super(key: key);

  @override
  State<TokenSearchScreen> createState() => _TokenSearchScreenState();
}

class _TokenSearchScreenState extends State<TokenSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final TokenDatabase _tokenDatabase = TokenDatabase();

  SearchTab _selectedTab = SearchTab.all;
  Category? _selectedCategory;
  bool _showNewTokenSheet = false;

  // Quantity dialog state
  bool _showingQuantityDialog = false;
  TokenDefinition? _selectedToken;
  int _tokenQuantity = 1;
  bool _createTapped = false;
  final FocusNode _quantityFieldFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _tokenDatabase.loadTokens();
    _searchController.addListener(() {
      _tokenDatabase.searchQuery = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _quantityFieldFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searchFocusNode.hasFocus
            ? null
            : const Text('Select Token'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedCategory != null || _searchController.text.isNotEmpty)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          _buildSearchBar(),

          // Tab Selector
          _buildTabSelector(),

          // Category Filter (only in "All" tab)
          if (_selectedTab == SearchTab.all) _buildCategoryFilter(),

          // Main Content
          Expanded(
            child: AnimatedBuilder(
              animation: _tokenDatabase,
              builder: (context, _) {
                if (_tokenDatabase.isLoading) {
                  return _buildLoadingView();
                } else if (_tokenDatabase.loadError != null) {
                  return _buildErrorView();
                } else {
                  final displayedTokens = _getDisplayedTokens();
                  if (displayedTokens.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildTokenList(displayedTokens);
                }
              },
            ),
          ),

          // Custom Token Button
          _buildCustomTokenButton(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                hintText: 'Search tokens...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
            ),
          ),
          if (_searchController.text.isNotEmpty) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey),
              onPressed: () {
                _searchController.clear();
                _tokenDatabase.searchQuery = '';
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SegmentedButton<SearchTab>(
        segments: const [
          ButtonSegment(
            value: SearchTab.all,
            label: Text('All'),
            icon: Icon(Icons.grid_view),
          ),
          ButtonSegment(
            value: SearchTab.recent,
            label: Text('Recent'),
            icon: Icon(Icons.history),
          ),
          ButtonSegment(
            value: SearchTab.favorites,
            label: Text('Favorites'),
            icon: Icon(Icons.star),
          ),
        ],
        selected: {_selectedTab},
        onSelectionChanged: (Set<SearchTab> newSelection) {
          setState(() {
            _selectedTab = newSelection.first;
          });
        },
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: Category.values.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category.displayName),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = selected ? category : null;
                  _tokenDatabase.selectedCategory = _selectedCategory;
                });
              },
              backgroundColor: Colors.grey.withOpacity(0.2),
              selectedColor: Colors.blue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<TokenDefinition> _getDisplayedTokens() {
    switch (_selectedTab) {
      case SearchTab.all:
        return _tokenDatabase.filteredTokens;
      case SearchTab.recent:
        return _tokenDatabase.recentTokens.where((token) {
          return _searchController.text.isEmpty ||
              token.matches(searchQuery: _searchController.text);
        }).toList();
      case SearchTab.favorites:
        return _tokenDatabase.getFavoriteTokens().where((token) {
          return _searchController.text.isEmpty ||
              token.matches(searchQuery: _searchController.text);
        }).toList();
    }
  }

  Widget _buildTokenList(List<TokenDefinition> tokens) {
    return ListView.builder(
      itemCount: tokens.length,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemBuilder: (context, index) {
        final token = tokens[index];
        final isFavorite = _tokenDatabase.isFavorite(token);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(
              token.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(token.cleanType),
                if (token.abilities.isNotEmpty)
                  Text(
                    token.abilities,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (token.pt.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      token.pt,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite ? Colors.amber : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _tokenDatabase.toggleFavorite(token);
                    });
                  },
                ),
              ],
            ),
            onTap: () => _selectToken(token),
          ),
        );
      },
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text(
            'Loading tokens...',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.orange,
            ),
            const SizedBox(height: 20),
            const Text(
              'Failed to Load Tokens',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _tokenDatabase.loadError ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _tokenDatabase.loadTokens(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    switch (_selectedTab) {
      case SearchTab.all:
        if (_searchController.text.isNotEmpty) {
          message = "No tokens match '${_searchController.text}'";
        } else if (_selectedCategory != null) {
          message = "No ${_selectedCategory!.displayName} tokens found";
        } else {
          message = "No tokens available";
        }
        break;
      case SearchTab.recent:
        message = _searchController.text.isEmpty
            ? "No recent tokens"
            : "No recent tokens match '${_searchController.text}'";
        break;
      case SearchTab.favorites:
        message = _searchController.text.isEmpty
            ? "No favorite tokens"
            : "No favorites match '${_searchController.text}'";
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedTab == SearchTab.favorites ? Icons.star_border : Icons.search,
            size: 60,
            color: Colors.grey,
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          if (_selectedTab == SearchTab.all &&
              (_selectedCategory != null || _searchController.text.isNotEmpty)) ...[
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _clearFilters,
              child: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomTokenButton() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            // Small delay for smooth transition
            Future.delayed(const Duration(milliseconds: 300), () {
              setState(() => _showNewTokenSheet = true);
            });
          },
          icon: const Icon(Icons.add_circle),
          label: const Text('Create Custom Token'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  void _selectToken(TokenDefinition token) {
    setState(() {
      _selectedToken = token;
      _tokenQuantity = 1;
      _createTapped = false;
      _showingQuantityDialog = true;
    });

    _tokenDatabase.addToRecent(token);

    _showQuantityDialog(token);
  }

  void _showQuantityDialog(TokenDefinition token) {
    final settings = context.read<SettingsProvider>();
    final multiplier = settings.tokenMultiplier;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Token Preview
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            token.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (token.pt.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              token.pt,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      token.cleanType,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    if (token.abilities.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        token.abilities,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Quantity Selector
              const Text(
                'How many tokens?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _tokenQuantity > 1
                          ? () => setModalState(() => _tokenQuantity--)
                          : null,
                      icon: const Icon(Icons.remove_circle),
                      iconSize: 32,
                      color: _tokenQuantity > 1 ? Colors.blue : Colors.grey,
                    ),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(
                          text: _tokenQuantity.toString(),
                        ),
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        focusNode: _quantityFieldFocus,
                        onChanged: (value) {
                          final parsed = int.tryParse(value);
                          if (parsed != null && parsed >= 1) {
                            setModalState(() => _tokenQuantity = parsed);
                          }
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: () => setModalState(() => _tokenQuantity++),
                      icon: const Icon(Icons.add_circle),
                      iconSize: 32,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),

              if (multiplier > 1) ...[
                const SizedBox(height: 8),
                Text(
                  'Current multiplier: x$multiplier - Final amount will be ${_tokenQuantity * multiplier}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 12),

              // Quick select buttons
              Row(
                children: [1, 2, 3, 4, 5].map((num) {
                  final isSelected = _tokenQuantity == num;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        onPressed: () => setModalState(() => _tokenQuantity = num),
                        style: OutlinedButton.styleFrom(
                          backgroundColor:
                              isSelected ? Colors.blue : Colors.transparent,
                          foregroundColor:
                              isSelected ? Colors.white : Colors.blue,
                        ),
                        child: Text('$num'),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Create Tapped Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create Tapped',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tokens enter the battlefield tapped',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _createTapped,
                      onChanged: (value) {
                        setModalState(() => _createTapped = value);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Create Button
              ElevatedButton(
                onPressed: () {
                  _createTokens(token, multiplier);
                  Navigator.pop(context); // Close quantity dialog
                  Navigator.pop(context); // Close search screen
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Create',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _createTokens(TokenDefinition token, int multiplier) {
    final tokenProvider = context.read<TokenProvider>();
    final finalAmount = _tokenQuantity * multiplier;
    final item = token.toItem(
      amount: finalAmount,
      createTapped: _createTapped,
    );

    tokenProvider.insertItem(item);
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategory = null;
      _tokenDatabase.clearFilters();
    });
  }
}
```

**CRITICAL NOTES:**
1. Uses ModalBottomSheet for quantity dialog (better UX than AlertDialog on mobile)
2. StatefulBuilder inside sheet to maintain local state
3. MediaQuery viewInsets for keyboard avoidance
4. Quick select buttons (1-5) for common quantities
5. Create Tapped toggle with explanation text
6. Multiplier reminder displayed when > 1
7. Two Navigator.pop() calls to dismiss both dialogs

**Checklist:**
- [ ] Search bar with clear button
- [ ] Three tabs (All/Recent/Favorites) with icons
- [ ] Category filter chips (only in All tab)
- [ ] Token list with favorites toggle
- [ ] Loading state with spinner
- [ ] Error state with retry button
- [ ] Empty states with contextual messages
- [ ] Custom token button at bottom
- [ ] Quantity dialog with stepper
- [ ] Create tapped toggle
- [ ] Multiplier calculation displayed
- [ ] Keyboard avoidance working

---

### 3.2 New Token Sheet

Create `lib/widgets/new_token_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/token_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/color_selection_button.dart';

class NewTokenSheet extends StatefulWidget {
  const NewTokenSheet({Key? key}) : super(key: key);

  @override
  State<NewTokenSheet> createState() => _NewTokenSheetState();
}

class _NewTokenSheetState extends State<NewTokenSheet> {
  final _nameController = TextEditingController();
  final _ptController = TextEditingController();
  final _abilitiesController = TextEditingController();

  int _amount = 1;
  bool _createTapped = false;

  // CRITICAL: SwiftUI NewTokenSheet uses ColorSelectionButton, not TextField
  bool _whiteSelected = false;
  bool _blueSelected = false;
  bool _blackSelected = false;
  bool _redSelected = false;
  bool _greenSelected = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ptController.dispose();
    _abilitiesController.dispose();
    super.dispose();
  }

  String _getColorString() {
    String colors = '';
    if (_whiteSelected) colors += 'W';
    if (_blueSelected) colors += 'U';
    if (_blackSelected) colors += 'B';
    if (_redSelected) colors += 'R';
    if (_greenSelected) colors += 'G';
    return colors;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final multiplier = settings.tokenMultiplier;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Custom Token'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _createToken,
            child: const Text(
              'Create',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Token Name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _ptController,
              decoration: const InputDecoration(
                labelText: 'Power/Toughness',
                hintText: 'e.g., 1/1',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Color Selection (using ColorSelectionButton from Phase 2)
            const Text(
              'Colors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  onChanged: (value) => setState(() => _whiteSelected = value),
                ),
                ColorSelectionButton(
                  symbol: 'U',
                  isSelected: _blueSelected,
                  color: Colors.blue,
                  label: 'Blue',
                  onChanged: (value) => setState(() => _blueSelected = value),
                ),
                ColorSelectionButton(
                  symbol: 'B',
                  isSelected: _blackSelected,
                  color: Colors.purple,
                  label: 'Black',
                  onChanged: (value) => setState(() => _blackSelected = value),
                ),
                ColorSelectionButton(
                  symbol: 'R',
                  isSelected: _redSelected,
                  color: Colors.red,
                  label: 'Red',
                  onChanged: (value) => setState(() => _redSelected = value),
                ),
                ColorSelectionButton(
                  symbol: 'G',
                  isSelected: _greenSelected,
                  color: Colors.green,
                  label: 'Green',
                  onChanged: (value) => setState(() => _greenSelected = value),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _abilitiesController,
              decoration: const InputDecoration(
                labelText: 'Abilities',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            const Text(
              'Quantity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                IconButton(
                  onPressed: _amount > 1 ? () => setState(() => _amount--) : null,
                  icon: const Icon(Icons.remove_circle),
                  iconSize: 32,
                ),
                Expanded(
                  child: Text(
                    '$_amount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _amount++),
                  icon: const Icon(Icons.add_circle),
                  iconSize: 32,
                ),
              ],
            ),

            if (multiplier > 1) ...[
              const SizedBox(height: 8),
              Text(
                'Current multiplier: x$multiplier - Final amount will be ${_amount * multiplier}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 24),

            SwitchListTile(
              title: const Text('Create Tapped'),
              subtitle: const Text('Tokens enter the battlefield tapped'),
              value: _createTapped,
              onChanged: (value) => setState(() => _createTapped = value),
            ),
          ],
        ),
      ),
    );
  }

  void _createToken() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a token name')),
      );
      return;
    }

    final tokenProvider = context.read<TokenProvider>();
    final settings = context.read<SettingsProvider>();
    final multiplier = settings.tokenMultiplier;
    final finalAmount = _amount * multiplier;

    final item = Item(
      name: _nameController.text,
      pt: _ptController.text,
      colors: _getColorString(),  // Build from color selections
      abilities: _abilitiesController.text,
      amount: finalAmount,
      tapped: _createTapped ? finalAmount : 0,
      summoningSick: finalAmount,
    );

    tokenProvider.insertItem(item);
    Navigator.pop(context);
  }
}
```

**CRITICAL**: Uses ColorSelectionButton (from Phase 2) instead of TextField for colors.
This matches SwiftUI's implementation.

**Checklist:**
- [ ] All fields present (name, P/T, abilities)
- [ ] **ColorSelectionButton for color selection (W/U/B/R/G)**
- [ ] Quantity stepper
- [ ] Multiplier reminder
- [ ] Create tapped toggle
- [ ] Name validation
- [ ] Keyboard handling
- [ ] Create button in app bar

---

### 3.3 Complete Dialog Implementations

Add these dialog methods to `content_screen.dart` and `token_card.dart`:

#### Untap All Dialog
```dart
void _showUntapAllDialog() {
  final tokenProvider = context.read<TokenProvider>();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Untap All Tokens'),
      content: const Text('This will untap all tokens on the battlefield.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            tokenProvider.untapAll();
            Navigator.pop(context);
          },
          child: const Text('Untap All'),
        ),
      ],
    ),
  );
}
```

#### Summoning Sickness Toggle Dialog
```dart
void _showSummoningSicknessToggle() {
  final settings = context.read<SettingsProvider>();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Summoning Sickness'),
      content: Text(
        settings.summoningSicknessEnabled
            ? 'Disable summoning sickness tracking?'
            : 'Enable summoning sickness tracking?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            settings.setSummoningSicknessEnabled(
              !settings.summoningSicknessEnabled,
            );
            Navigator.pop(context);
          },
          child: const Text('Toggle'),
        ),
      ],
    ),
  );
}
```

#### Save Deck Dialog
```dart
void _showSaveDeckDialog() {
  final tokenProvider = context.read<TokenProvider>();
  final deckProvider = context.read<DeckProvider>();
  final controller = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Save Deck'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: 'Enter deck name',
          border: OutlineInputBorder(),
        ),
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (controller.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a deck name')),
              );
              return;
            }

            final templates = tokenProvider.items
                .map((item) => TokenTemplate.fromItem(item))
                .toList();

            final deck = Deck(name: controller.text, templates: templates);
            deckProvider.saveDeck(deck);

            Navigator.pop(context);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Deck "${controller.text}" saved')),
            );
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
```

#### Board Wipe Dialog
```dart
void _showBoardWipeDialog() {
  final tokenProvider = context.read<TokenProvider>();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Board Wipe'),
      content: const Text(
        'Choose how to handle tokens:\n\n'
        '• Set to Zero: Keeps tokens but sets amount to 0\n'
        '• Delete All: Removes all tokens permanently',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            tokenProvider.boardWipeZero();
            Navigator.pop(context);
          },
          child: const Text('Set to Zero'),
        ),
        TextButton(
          onPressed: () {
            tokenProvider.boardWipeDelete();
            Navigator.pop(context);
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete All'),
        ),
      ],
    ),
  );
}
```

#### Add Tokens Dialog (for TokenCard)
```dart
void _showAddDialog(BuildContext context, TokenProvider provider, int multiplier) {
  final controller = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add Tokens'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Enter amount',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          if (multiplier > 1) ...[
            const SizedBox(height: 8),
            Text(
              'Current multiplier: x$multiplier',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
            final value = int.tryParse(controller.text);
            if (value != null && value > 0) {
              widget.item.amount += value * multiplier;
              widget.item.summoningSick += value * multiplier;
              provider.updateItem(widget.item);
            }
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
}
```

#### Remove Tokens Dialog (for TokenCard)
```dart
void _showRemoveDialog(BuildContext context, TokenProvider provider) {
  final controller = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove Tokens'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          hintText: 'Enter amount',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Reset to zero
            widget.item.amount = 0;
            widget.item.tapped = 0;
            widget.item.summoningSick = 0;
            provider.updateItem(widget.item);
            Navigator.pop(context);
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final value = int.tryParse(controller.text);
            if (value != null && value > 0) {
              final newAmount = (widget.item.amount - value).clamp(0, widget.item.amount);
              final removed = widget.item.amount - newAmount;

              // Proportionally reduce tapped and summoning sick
              if (widget.item.tapped > 0) {
                final tappedRatio = widget.item.tapped / widget.item.amount;
                widget.item.tapped = (newAmount * tappedRatio).round();
              }
              if (widget.item.summoningSick > 0) {
                final sickRatio = widget.item.summoningSick / widget.item.amount;
                widget.item.summoningSick = (newAmount * sickRatio).round();
              }

              widget.item.amount = newAmount;
              provider.updateItem(widget.item);
            }
            Navigator.pop(context);
          },
          child: const Text('Remove'),
        ),
      ],
    ),
  );
}
```

#### Tap/Untap Dialogs (for TokenCard)
```dart
void _showTapDialog(BuildContext context) {
  final controller = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Tap Tokens'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          hintText: 'Enter amount to tap',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final value = int.tryParse(controller.text);
            if (value != null && value > 0) {
              widget.item.tapped = (widget.item.tapped + value).clamp(0, widget.item.amount);
            }
            Navigator.pop(context);
          },
          child: const Text('Tap'),
        ),
      ],
    ),
  );
}

void _showUntapDialog(BuildContext context) {
  final controller = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Untap Tokens'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          hintText: 'Enter amount to untap',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final value = int.tryParse(controller.text);
            if (value != null && value > 0) {
              widget.item.tapped = (widget.item.tapped - value).clamp(0, widget.item.tapped);
            }
            Navigator.pop(context);
          },
          child: const Text('Untap'),
        ),
      ],
    ),
  );
}
```

**Checklist:**
- [ ] All dialogs implemented
- [ ] TextField autofocus in dialogs
- [ ] Multiplier reminders where applicable
- [ ] Validation for empty inputs
- [ ] Board wipe has two options
- [ ] Remove dialog has "Reset" option
- [ ] Snackbar feedback for save deck

---

### Phase 3 Validation

**Checklist:**
- [ ] Token search screen accessible from ContentScreen
- [ ] Search bar filters tokens correctly
- [ ] Three tabs work (All/Recent/Favorites)
- [ ] Category filter chips work
- [ ] Favorite toggle persists
- [ ] Quantity dialog appears on token selection
- [ ] Create tapped toggle works
- [ ] Multiplier calculation displayed correctly
- [ ] Custom token button opens NewTokenSheet
- [ ] New token sheet validates name field
- [ ] All toolbar dialogs functional
- [ ] Board wipe confirmation works
- [ ] Save/load deck functionality working

---

