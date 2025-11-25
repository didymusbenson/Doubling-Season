import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '../models/token_definition.dart' as token_models;
import '../database/token_database.dart';
import '../providers/token_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/new_token_sheet.dart';
import '../widgets/color_filter_button.dart';
import '../utils/constants.dart';
import '../utils/artwork_manager.dart';
import '../utils/artwork_preference_manager.dart';

enum SearchTab { all, recent, favorites }

class TokenSearchScreen extends StatefulWidget {
  const TokenSearchScreen({super.key});

  @override
  State<TokenSearchScreen> createState() => _TokenSearchScreenState();
}

class _TokenSearchScreenState extends State<TokenSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final TokenDatabase _tokenDatabase = TokenDatabase();

  SearchTab _selectedTab = SearchTab.all;
  token_models.Category? _selectedCategory;
  Set<String> _selectedColors = {};

  // Quantity dialog state
  int _tokenQuantity = 1;
  bool _createTapped = false;
  bool _isCreating = false; // Prevent multi-tap
  bool _isEditingQuantity = false;
  final TextEditingController _quantityController = TextEditingController();

  // Search debouncing - prevents excessive filtering while user is typing
  Timer? _searchDebounceTimer;
  static const _searchDebounceDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _tokenDatabase.loadTokens();
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel(); // Cancel pending search operations
    _searchController.dispose();
    _searchFocusNode.dispose();
    _quantityController.dispose();
    _tokenDatabase.dispose(); // Fix memory leak
    super.dispose();
  }

  /// Debounces search input to avoid filtering on every keystroke.
  /// Waits 300ms after user stops typing before applying the search filter.
  /// This significantly improves performance when searching through 300+ tokens.
  void _onSearchTextChanged() {
    // Cancel any pending search operations
    _searchDebounceTimer?.cancel();

    // Schedule new search after 300ms delay
    _searchDebounceTimer = Timer(_searchDebounceDuration, () {
      // Only update search query after user has stopped typing
      _tokenDatabase.searchQuery = _searchController.text;
    });
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
          if (_selectedCategory != null || _searchController.text.isNotEmpty || _selectedColors.isNotEmpty)
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

          // Color Filter (only in "All" tab)
          if (_selectedTab == SearchTab.all) _buildColorFilter(),

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

  Widget _buildColorFilter() {
    const colors = ['W', 'U', 'B', 'R', 'G', 'C'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: colors.map((color) {
          final isSelected = _selectedColors.contains(color);
          return ColorFilterButton(
            symbol: color,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedColors.remove(color);
                } else {
                  _selectedColors.add(color);
                }
                _tokenDatabase.selectedColors = _selectedColors;
              });
            },
          );
        }).toList(),
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
    // Only show Creature, Artifact, Myriad, and Emblem categories
    const allowedCategories = [
      token_models.Category.creature,
      token_models.Category.artifact,
      token_models.Category.myriad,
      token_models.Category.emblem,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: allowedCategories.map((category) {
          final isSelected = _selectedCategory == category;
          return FilterChip(
            label: Text(category.displayName),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (selected) {
              setState(() {
                _selectedCategory = selected ? category : null;
                _tokenDatabase.selectedCategory = _selectedCategory;
              });
            },
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  List<token_models.TokenDefinition> _getDisplayedTokens() {
    final settingsProvider = context.read<SettingsProvider>();

    switch (_selectedTab) {
      case SearchTab.all:
        return _tokenDatabase.filteredTokens;
      case SearchTab.recent:
        return _tokenDatabase.getRecentTokens(settingsProvider).where((token) {
          return _searchController.text.isEmpty ||
              token.matches(searchQuery: _searchController.text);
        }).toList();
      case SearchTab.favorites:
        return _tokenDatabase.getFavoriteTokens(settingsProvider).where((token) {
          return _searchController.text.isEmpty ||
              token.matches(searchQuery: _searchController.text);
        }).toList();
    }
  }

  Widget _buildTokenList(List<token_models.TokenDefinition> tokens) {
    final settingsProvider = context.read<SettingsProvider>();

    return ListView.builder(
      itemCount: tokens.length,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemBuilder: (context, index) {
        final token = tokens[index];
        final isFavorite = _tokenDatabase.isFavorite(token, settingsProvider);

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
                // Color indicators
                if (token.colors.isNotEmpty) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _buildColorIndicators(token.colors),
                  ),
                  const SizedBox(width: 8),
                ],
                if (token.pt.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.2),
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
                      _tokenDatabase.toggleFavorite(token, settingsProvider);
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

  List<Widget> _buildColorIndicators(String colors) {
    final indicators = <Widget>[];
    final colorMap = {
      'W': const Color(0xFFE8DDB5), // Cream for white
      'U': Colors.blue,
      'B': Colors.purple,
      'R': Colors.red,
      'G': Colors.green,
    };

    for (final colorChar in colors.split('')) {
      if (colorMap.containsKey(colorChar)) {
        indicators.add(
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: colorMap[colorChar],
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
        );
      }
    }

    return indicators;
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
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context); // Close search screen
            // Small delay for smooth transition
            Future.delayed(UIConstants.sheetDismissDelay, () {
              if (!mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const NewTokenSheet(),
                  fullscreenDialog: true,
                ),
              );
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

  void _selectToken(token_models.TokenDefinition token) {
    setState(() {
      _tokenQuantity = 1;
      _createTapped = false;
      _isCreating = false; // Reset creation flag
      _isEditingQuantity = false;
    });

    final settingsProvider = context.read<SettingsProvider>();
    _tokenDatabase.addToRecent(token, settingsProvider);

    // Pre-cache artwork while user is choosing quantity (performance optimization)
    // Check if user has custom artwork preference first
    final artworkPrefManager = ArtworkPreferenceManager();
    final tokenIdentity = token.id;
    final preferredArtwork = artworkPrefManager.getPreferredArtwork(tokenIdentity);

    // Only download if it's a Scryfall URL (not custom file://)
    if (preferredArtwork != null && !preferredArtwork.startsWith('file://')) {
      ArtworkManager.downloadArtwork(preferredArtwork).then((_) {
        debugPrint('Pre-cached artwork for ${token.name}');
      }).catchError((error) {
        debugPrint('Pre-cache failed for ${token.name}: $error');
        // Silent failure - will retry during creation if needed
      });
    } else if (preferredArtwork == null && token.artwork.isNotEmpty) {
      // No preference - precache first database artwork
      final firstArtwork = token.artwork[0];
      ArtworkManager.downloadArtwork(firstArtwork.url).then((_) {
        debugPrint('Pre-cached artwork for ${token.name}');
      }).catchError((error) {
        debugPrint('Pre-cache failed for ${token.name}: $error');
        // Silent failure - will retry during creation if needed
      });
    }

    _showQuantityDialog(token);
  }


  void _showQuantityDialog(token_models.TokenDefinition token) {
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
                  color: Colors.grey.withValues(alpha: 0.1),
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
                              color: Colors.grey.withValues(alpha: 0.2),
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
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _isEditingQuantity || _tokenQuantity <= 1
                          ? null
                          : () => setModalState(() => _tokenQuantity--),
                      icon: const Icon(Icons.remove_circle),
                      iconSize: 32,
                      color: _isEditingQuantity || _tokenQuantity <= 1 ? Colors.grey : Colors.blue,
                    ),
                    Expanded(
                      child: _isEditingQuantity
                          ? TextField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              autofocus: true,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: (value) {
                                final newQuantity = int.tryParse(value);
                                if (newQuantity != null && newQuantity > 0) {
                                  setModalState(() {
                                    _tokenQuantity = newQuantity;
                                    _isEditingQuantity = false;
                                  });
                                } else {
                                  setModalState(() => _isEditingQuantity = false);
                                }
                              },
                              onTapOutside: (event) {
                                final newQuantity = int.tryParse(_quantityController.text);
                                if (newQuantity != null && newQuantity > 0) {
                                  setModalState(() {
                                    _tokenQuantity = newQuantity;
                                    _isEditingQuantity = false;
                                  });
                                } else {
                                  setModalState(() => _isEditingQuantity = false);
                                }
                              },
                            )
                          : InkWell(
                              onTap: () {
                                setModalState(() {
                                  _quantityController.text = '$_tokenQuantity';
                                  _isEditingQuantity = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  '$_tokenQuantity',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    IconButton(
                      onPressed: _isEditingQuantity
                          ? null
                          : () => setModalState(() => _tokenQuantity++),
                      icon: const Icon(Icons.add_circle),
                      iconSize: 32,
                      color: _isEditingQuantity ? Colors.grey : Colors.blue,
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
                        onPressed: _isEditingQuantity
                            ? null
                            : () => setModalState(() => _tokenQuantity = num),
                        style: OutlinedButton.styleFrom(
                          backgroundColor:
                              isSelected ? Colors.blue : Colors.transparent,
                          foregroundColor:
                              isSelected ? Colors.white : (_isEditingQuantity ? Colors.grey : Colors.blue),
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
                  color: Colors.grey.withValues(alpha: 0.1),
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
                onPressed: _isCreating ? null : () async {
                  // Prevent multi-tap
                  setModalState(() => _isCreating = true);

                  // Capture provider references BEFORE any async operations
                  final tokenProvider = context.read<TokenProvider>();
                  final settingsProvider = context.read<SettingsProvider>();
                  final finalAmount = _tokenQuantity * multiplier;

                  // Create final token immediately (no placeholder)
                  final newItem = token.toItem(
                    amount: finalAmount,
                    createTapped: _createTapped,
                  );

                  // Load preferred artwork from preferences (Custom Artwork Feature)
                  final artworkPrefManager = ArtworkPreferenceManager();
                  final tokenIdentity = token.id; // Composite ID
                  final preferredArtwork = artworkPrefManager.getPreferredArtwork(tokenIdentity);

                  // Assign artwork URL immediately (synchronous, no download)
                  // Prefer user's saved preference, fallback to first available artwork
                  if (preferredArtwork != null) {
                    newItem.artworkUrl = preferredArtwork;
                    // Set artworkSet if it's a Scryfall URL (not custom file://)
                    if (!preferredArtwork.startsWith('file://') && token.artwork.isNotEmpty) {
                      // Try to find matching artwork variant by URL
                      final matchingArtwork = token.artwork.firstWhere(
                        (art) => art.url == preferredArtwork,
                        orElse: () => token.artwork[0],
                      );
                      newItem.artworkSet = matchingArtwork.set;
                    }
                  } else if (token.artwork.isNotEmpty) {
                    // No preference - use first available artwork
                    final firstArtwork = token.artwork[0];
                    newItem.artworkUrl = firstArtwork.url;
                    newItem.artworkSet = firstArtwork.set;
                  }

                  // Insert token immediately - it's now visible and fully functional
                  await tokenProvider.insertItem(newItem);

                  // Apply summoning sickness if enabled AND token is a creature without Haste
                  // (must be after insert because setter calls save())
                  if (settingsProvider.summoningSicknessEnabled &&
                      newItem.hasPowerToughness &&
                      !newItem.hasHaste) {
                    newItem.summoningSick = finalAmount;
                  }

                  // Reset creating state before closing dialogs
                  if (mounted) {
                    setModalState(() => _isCreating = false);
                  }

                  // Close dialogs - token is on board and usable
                  if (context.mounted) {
                    Navigator.pop(context); // Close quantity dialog
                    Navigator.pop(context); // Close search screen
                  }

                  // Download artwork in background (non-blocking, fire-and-forget)
                  // Skip if custom artwork (file://) - already local
                  if (newItem.artworkUrl != null && !newItem.artworkUrl!.startsWith('file://')) {
                    final artworkUrl = newItem.artworkUrl!;
                    ArtworkManager.downloadArtwork(artworkUrl).then((file) {
                      if (file == null) {
                        // Download failed - reset artworkUrl so it doesn't try to load
                        debugPrint('Artwork download failed for ${token.name}, resetting URL');
                        // Find the item again (it might have been deleted/modified)
                        final currentItem = tokenProvider.items.firstWhereOrNull(
                          (item) => item.artworkUrl == artworkUrl
                        );
                        if (currentItem != null) {
                          currentItem.artworkUrl = null;
                          currentItem.artworkSet = null;
                          currentItem.save();
                        }
                      } else {
                        debugPrint('Artwork downloaded and cached for ${token.name}');
                        // Trigger rebuild so TokenCard displays the cached artwork
                        final currentItem = tokenProvider.items.firstWhereOrNull(
                          (item) => item.artworkUrl == artworkUrl
                        );
                        if (currentItem != null) {
                          currentItem.save(); // Triggers Hive save and notifies listeners
                        }
                      }
                    }).catchError((error) {
                      debugPrint('Error during background artwork download: $error');
                      // Silent fail - reset artworkUrl on error
                      final currentItem = tokenProvider.items.firstWhereOrNull(
                        (item) => item.artworkUrl == artworkUrl
                      );
                      if (currentItem != null) {
                        currentItem.artworkUrl = null;
                        currentItem.artworkSet = null;
                        currentItem.save();
                      }
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: _isCreating ? Colors.grey : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  _isCreating ? 'Creating...' : 'Create',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }


  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategory = null;
      _selectedColors = {};
      _tokenDatabase.clearFilters();
    });
  }
}
