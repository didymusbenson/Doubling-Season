import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gradient_borders/gradient_borders.dart';
import '../models/item.dart';
import '../models/token_template.dart';
import '../models/deck.dart';
import '../models/tracker_widget.dart'; // NEW - Widget Cards Feature
import '../models/toggle_widget.dart'; // NEW - Widget Cards Feature
import '../models/tracker_widget_template.dart'; // NEW - Deck templates for utilities
import '../models/toggle_widget_template.dart'; // NEW - Deck templates for utilities
import '../providers/token_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/deck_provider.dart';
import '../providers/tracker_provider.dart'; // NEW - Widget Cards Feature
import '../providers/toggle_provider.dart'; // NEW - Widget Cards Feature
import '../utils/constants.dart';
import '../utils/color_utils.dart';
import '../widgets/token_card.dart';
import '../widgets/tracker_widget_card.dart'; // NEW - Widget Cards Feature
import '../widgets/toggle_widget_card.dart'; // NEW - Widget Cards Feature
import '../widgets/multiplier_view.dart';
import '../widgets/load_deck_sheet.dart';
import '../widgets/floating_action_menu.dart';
import 'token_search_screen.dart';
import 'widget_selection_screen.dart'; // NEW - Widget Cards Feature
import 'about_screen.dart';

// Helper class to wrap board items (tokens and widgets) for unified list display
class _BoardItem {
  final dynamic item; // Item, TrackerWidget, or ToggleWidget
  final double order;
  final String key; // Unique key for ReorderableListView

  _BoardItem(this.item, this.order, this.key);

  bool get isToken => item is Item;
  bool get isTracker => item is TrackerWidget;
  bool get isToggle => item is ToggleWidget;
}

// Helper class for preserving exact order when saving decks
class _BoardItemForSave {
  final dynamic item; // Item, TrackerWidget, or ToggleWidget
  final double order;
  final String type; // 'token', 'tracker', 'toggle'

  _BoardItemForSave(this.item, this.order, this.type);
}

class ContentScreen extends StatefulWidget {
  const ContentScreen({super.key});

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  final Map<String, ValueNotifier<bool>> _dismissStates = {}; // Track dismiss state per item

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Token list
          _buildTokenList(),

          // Multiplier view overlay (bottom left)
          const Positioned(
            bottom: UIConstants.standardPadding,
            left: UIConstants.standardPadding,
            child: MultiplierView(),
          ),

          // FAB row (bottom right) - + button and menu
          Positioned(
            bottom: UIConstants.standardPadding,
            right: UIConstants.standardPadding,
            child: Consumer<SettingsProvider>(
              builder: (context, settings, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      heroTag: 'new_token_fab',
                      onPressed: _showTokenSearch,
                      child: const Icon(Icons.add, size: 28),
                    ),
                    const SizedBox(width: UIConstants.smallPadding),
                    FloatingActionMenu(
                      onNewToken: _showTokenSearch,
                      onWidgets: _showWidgetSelection,
                      onAddCountersToAll: _handleAddCountersToAll,
                      onMinusOneToAll: _handleMinusOneToAll,
                      onUntapAll: _showUntapAllDialog,
                      onClearSickness: _handleClearSickness,
                      onSaveDeck: _showSaveDeckDialog,
                      onLoadDeck: _showLoadDeckSheet,
                      onBoardWipe: _showBoardWipeDialog,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Tripling Season'),
      centerTitle: true,
      leading: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status button (experimental features only)
              if (settings.experimentalFeaturesEnabled)
                IconButton(
                  onPressed: () => _showStatusPlaceholder(),
                  icon: const Icon(Icons.list_alt),
                  tooltip: 'Status',
                ),
              // Clear summoning sickness button
              IconButton(
                onPressed: () => _handleClearSickness(),
                icon: const Icon(Icons.adjust),
                tooltip: 'Clear Summoning Sickness',
              ),
            ],
          );
        },
      ),
      leadingWidth: 112, // Accommodate both buttons (56px each)
      actions: [
        // Settings (long press on summoning sickness icon)
        IconButton(
          onPressed: () => _showSummoningSicknessToggle(),
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
        ),
        // Help/About
        IconButton(
          onPressed: () => _showAboutPlaceholder(),
          icon: const Icon(Icons.help_outline),
          tooltip: 'About',
        ),
      ],
    );
  }

  Widget _buildTokenList() {
    // Get all providers
    final tokenProvider = Provider.of<TokenProvider>(context, listen: false);
    final trackerProvider = Provider.of<TrackerProvider>(context, listen: false);
    final toggleProvider = Provider.of<ToggleProvider>(context, listen: false);

    // Combine all listenables into one
    return ListenableBuilder(
      listenable: Listenable.merge([
        tokenProvider.listenable,
        trackerProvider.listenable,
        toggleProvider.listenable,
      ]),
      builder: (context, _) {
        // Merge all board items
        final boardItems = <_BoardItem>[];

        // Add tokens
        for (final item in tokenProvider.items) {
          boardItems.add(_BoardItem(item, item.order, 'token_${item.createdAt}'));
        }

        // Add trackers
        for (final tracker in trackerProvider.trackers) {
          boardItems.add(_BoardItem(tracker, tracker.order, 'tracker_${tracker.widgetId}'));
        }

        // Add toggles
        for (final toggle in toggleProvider.toggles) {
          boardItems.add(_BoardItem(toggle, toggle.order, 'toggle_${toggle.widgetId}'));
        }

        // Sort by order
        boardItems.sort((a, b) => a.order.compareTo(b.order));

        // Check empty state
        if (boardItems.isEmpty) {
          return _buildEmptyState();
        }

        return ReorderableListView.builder(
          itemCount: boardItems.length,
          padding: const EdgeInsets.only(
            top: UIConstants.listTopPadding,
            left: UIConstants.smallPadding,
            right: UIConstants.smallPadding,
            bottom: UIConstants.listBottomPadding,
          ),
          onReorder: (oldIndex, newIndex) => _handleReorder(boardItems, oldIndex, newIndex),
          proxyDecorator: _buildDragProxy,
          itemBuilder: (context, index) {
            final boardItem = boardItems[index];
            return _buildBoardItemCard(boardItem, index);
          },
        );
      },
    );
  }

  Widget _buildBoardItemCard(_BoardItem boardItem, int index) {
    // final isDarkMode = Theme.of(context).brightness == Brightness.dark; // Unused since boxShadow commented out
    const borderWidth = 3.0;
    final innerBorderRadius = UIConstants.borderRadius - borderWidth;

    // Determine colors for border gradient
    String colorIdentity = '';
    bool isEmblem = false;

    if (boardItem.isToken) {
      final item = boardItem.item as Item;
      colorIdentity = item.colors;
      isEmblem = item.isEmblem;
    } else if (boardItem.isTracker) {
      colorIdentity = (boardItem.item as TrackerWidget).colorIdentity;
    } else if (boardItem.isToggle) {
      colorIdentity = (boardItem.item as ToggleWidget).colorIdentity;
    }

    // Ensure ValueNotifier exists for this item
    _dismissStates.putIfAbsent(boardItem.key, () => ValueNotifier<bool>(false));

    return ValueListenableBuilder<bool>(
      key: ValueKey(boardItem.key), // Key must be on outer widget for ReorderableListView
      valueListenable: _dismissStates[boardItem.key]!,
      builder: (context, isDismissing, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(vertical: UIConstants.verticalSpacing),
          decoration: BoxDecoration(
            color: isDismissing ? Colors.red : Colors.transparent, // Red only during swipe animation
            borderRadius: BorderRadius.circular(UIConstants.borderRadius),
          ),
          // clipBehavior removed - was clipping the drop shadow in light mode
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(UIConstants.borderRadius),
          // boxShadow: isDarkMode ? null : [
          //   BoxShadow(
          //     color: Colors.black.withValues(alpha: UIConstants.shadowOpacity),
          //     blurRadius: UIConstants.shadowBlurRadius,
          //     offset: const Offset(UIConstants.shadowOffsetX, UIConstants.shadowOffsetY),
          //   ),
          //   BoxShadow(
          //     color: Colors.black.withValues(alpha: UIConstants.lightShadowOpacity),
          //     blurRadius: UIConstants.lightShadowBlurRadius,
          //     offset: const Offset(UIConstants.lightShadowOffsetX, UIConstants.lightShadowOffsetY),
          //   ),
          // ],
          border: GradientBoxBorder(
            gradient: ColorUtils.gradientForColors(colorIdentity, isEmblem: isEmblem),
            width: borderWidth,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(innerBorderRadius),
          child: _buildDismissibleCard(boardItem),
        ),
      ),
    );
  }

  Widget _buildDismissibleCard(_BoardItem boardItem) {
    const borderWidth = 3.0;
    final innerBorderRadius = UIConstants.borderRadius - borderWidth;

    return Dismissible(
      key: ValueKey('dismissible_${boardItem.key}'),
      direction: DismissDirection.endToStart,
      background: Material(
        color: Colors.red,
        borderRadius: BorderRadius.circular(innerBorderRadius),
        child: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: UIConstants.standardPadding),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
      ),
      onUpdate: (details) {
        // Track dismiss state without setState - only updates this specific item's container
        final notifier = _dismissStates[boardItem.key];
        if (notifier != null) {
          final shouldShowRed = details.progress > 0;
          if (notifier.value != shouldShowRed) {
            notifier.value = shouldShowRed;
          }
        }
      },
      onDismissed: (_) => _deleteItem(boardItem),
      child: _buildCardContent(boardItem),
    );
  }

  Widget _buildCardContent(_BoardItem boardItem) {
    if (boardItem.isToken) {
      return TokenCard(item: boardItem.item as Item);
    } else if (boardItem.isTracker) {
      return TrackerWidgetCard(tracker: boardItem.item as TrackerWidget);
    } else if (boardItem.isToggle) {
      return ToggleWidgetCard(toggle: boardItem.item as ToggleWidget);
    }
    return const SizedBox.shrink();
  }

  void _deleteItem(_BoardItem boardItem) {
    if (boardItem.isToken) {
      context.read<TokenProvider>().deleteItem(boardItem.item as Item);
    } else if (boardItem.isTracker) {
      context.read<TrackerProvider>().deleteTracker(boardItem.item as TrackerWidget);
    } else if (boardItem.isToggle) {
      context.read<ToggleProvider>().deleteToggle(boardItem.item as ToggleWidget);
    }
  }

  Widget _buildEmptyState() {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(UIConstants.largePadding),
        child: Container(
          padding: const EdgeInsets.all(UIConstants.largePadding),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(UIConstants.borderRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: Text(
                  'No tokens to display',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).textTheme.titleLarge?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: UIConstants.largePadding),
              GestureDetector(
                onTap: () => _showTokenSearch(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: UIConstants.largeSpacing),
                    Flexible(
                      child: Text(
                        'Create your first token',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: UIConstants.standardPadding),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: UIConstants.largeSpacing),
                  Flexible(
                    child: Text(
                      'Open tools to add tokens, save decks, and more',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: UIConstants.standardPadding),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: UIConstants.largeSpacing),
                  Flexible(
                    child: Text(
                      'Tap a token to edit details, add counters, and more',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: UIConstants.standardPadding),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calculate,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: UIConstants.largeSpacing),
                  Flexible(
                    child: Text(
                      'Adjust multiplier for token doubling effects',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: UIConstants.standardPadding),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.settings,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: UIConstants.largeSpacing),
                  Flexible(
                    child: Text(
                      'Adjust settings, theme, etc.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: UIConstants.standardPadding),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.help_outline,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: UIConstants.largeSpacing),
                  Flexible(
                    child: Text(
                      'About Tripling Season',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleReorder(List<_BoardItem> boardItems, int oldIndex, int newIndex) {
    // Track if moving down before adjustment
    final movingDown = newIndex > oldIndex;

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final boardItem = boardItems[oldIndex];

    // Calculate new fractional order
    double newOrder;
    if (newIndex == 0) {
      // Moving to top
      newOrder = boardItems.first.order - 1.0;
    } else if (newIndex == boardItems.length - 1) {
      // Moving to bottom
      newOrder = boardItems.last.order + 1.0;
    } else {
      // Moving between two items
      if (movingDown) {
        // Item moves after boardItems[newIndex]
        final prevOrder = boardItems[newIndex].order;
        final nextOrder = boardItems[newIndex + 1].order;
        newOrder = (prevOrder + nextOrder) / 2.0;
      } else {
        // Item moves before boardItems[newIndex]
        final prevOrder = boardItems[newIndex - 1].order;
        final nextOrder = boardItems[newIndex].order;
        newOrder = (prevOrder + nextOrder) / 2.0;
      }
    }

    // Update order based on item type
    if (boardItem.isToken) {
      final item = boardItem.item as Item;
      item.order = newOrder;
      item.save();
    } else if (boardItem.isTracker) {
      final tracker = boardItem.item as TrackerWidget;
      tracker.order = newOrder;
      tracker.save();
    } else if (boardItem.isToggle) {
      final toggle = boardItem.item as ToggleWidget;
      toggle.order = newOrder;
      toggle.save();
    }

    // Check if we need compacting (when gap becomes too small)
    _checkAndCompactOrders(boardItems);
  }

  void _checkAndCompactOrders(List<_BoardItem> boardItems) {
    // If any two adjacent items have order difference < 0.001, compact all orders
    boardItems.sort((a, b) => a.order.compareTo(b.order));

    for (int i = 0; i < boardItems.length - 1; i++) {
      if ((boardItems[i + 1].order - boardItems[i].order) < 0.001) {
        _compactOrders(boardItems);
        return;
      }
    }
  }

  void _compactOrders(List<_BoardItem> boardItems) {
    boardItems.sort((a, b) => a.order.compareTo(b.order));
    for (int i = 0; i < boardItems.length; i++) {
      if (boardItems[i].isToken) {
        final item = boardItems[i].item as Item;
        item.order = i.toDouble();
        item.save();
      } else if (boardItems[i].isTracker) {
        final tracker = boardItems[i].item as TrackerWidget;
        tracker.order = i.toDouble();
        tracker.save();
      } else if (boardItems[i].isToggle) {
        final toggle = boardItems[i].item as ToggleWidget;
        toggle.order = i.toDouble();
        toggle.save();
      }
    }
  }

  Widget _buildDragProxy(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // Scale from 1.0 to 1.03 during drag (3% growth)
        final scale = lerpDouble(1.0, UIConstants.dragScaleFactor, animation.value) ?? 1.0;

        return Transform.scale(
          scale: scale,
          child: Material(
            elevation: UIConstants.dragElevation,
            shadowColor: Colors.black.withValues(alpha: UIConstants.dragShadowOpacity),
            borderRadius: BorderRadius.circular(UIConstants.borderRadius),
            clipBehavior: Clip.antiAlias,
            type: MaterialType.transparency,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  void _handleClearSickness() {
    final tokenProvider = context.read<TokenProvider>();
    tokenProvider.clearSummoningSickness();
  }

  void _handleAddCountersToAll() {
    final tokenProvider = context.read<TokenProvider>();
    tokenProvider.addPlusOneToAll();
  }

  void _handleMinusOneToAll() {
    final tokenProvider = context.read<TokenProvider>();
    tokenProvider.addMinusOneToAll();
  }

  void _showTokenSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TokenSearchScreen(),
        fullscreenDialog: true,
      ),
    );
  }


  void _showWidgetSelection() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const WidgetSelectionScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  void _showUntapAllDialog() {
    final tokenProvider = context.read<TokenProvider>();
    tokenProvider.untapAll();
  }

  void _showExperimentalFeaturesConfirmation(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enable Experimental Features?'),
        content: const Text(
          'Are you sure? Enabling this setting provides access to in-development experimental features. This could impact your board state, theme, and other data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              settings.setExperimentalFeaturesEnabled(true);
              Navigator.pop(dialogContext);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showSummoningSicknessToggle() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Summoning sickness toggle
                SwitchListTile(
                  title: const Text('Track summoning sickness'),
                  value: settings.summoningSicknessEnabled,
                  onChanged: (value) {
                    settings.setSummoningSicknessEnabled(value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                // Experimental features toggle
                SwitchListTile(
                  title: const Text('Enable experimental features'),
                  value: settings.experimentalFeaturesEnabled,
                  onChanged: (value) {
                    if (value) {
                      // Show confirmation dialog when enabling
                      _showExperimentalFeaturesConfirmation(context, settings);
                    } else {
                      // Allow disabling without confirmation
                      settings.setExperimentalFeaturesEnabled(false);
                    }
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                const Divider(),

                // Theme section header
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(
                      'Theme',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Theme mode settings
                SwitchListTile(
                  title: const Text('Use system theme'),
                  value: settings.useSystemTheme,
                  onChanged: (value) {
                    settings.setUseSystemTheme(value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                SwitchListTile(
                  title: const Text('Dark mode'),
                  value: settings.isDarkMode,
                  onChanged: settings.useSystemTheme ? null : (value) {
                    settings.setIsDarkMode(value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 8),

                // Token art selection
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Token Art'),
                  ),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'fullView',
                      label: Text('Full Card'),
                      icon: Icon(Icons.crop_landscape),
                    ),
                    ButtonSegment(
                      value: 'fadeout',
                      label: Text('Half Card'),
                      icon: Icon(Icons.gradient),
                    ),
                  ],
                  selected: {settings.artworkDisplayStyle},
                  onSelectionChanged: (Set<String> newSelection) {
                    settings.setArtworkDisplayStyle(newSelection.first);
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBoardWipeDialog() {
    final tokenProvider = context.read<TokenProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Board Wipe'),
        content: const Text('Choose board wipe action:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await tokenProvider.boardWipeZero();
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Set to 0'),
          ),
          TextButton(
            onPressed: () async {
              await tokenProvider.boardWipeDelete();
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSaveDeckDialog() async {
    final tokenProvider = context.read<TokenProvider>();
    final trackerProvider = context.read<TrackerProvider>();
    final toggleProvider = context.read<ToggleProvider>();
    final deckProvider = context.read<DeckProvider>();
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isEmpty) {
                return;
              }

              final deckName = controller.text;

              // Close dialog immediately
              Navigator.pop(dialogContext);

              // Save deck after dialog is fully dismissed
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Collect all board items with their orders to preserve exact positions
                final allBoardItems = <_BoardItemForSave>[];

                // Add all tokens
                for (final item in tokenProvider.items) {
                  allBoardItems.add(_BoardItemForSave(item, item.order, 'token'));
                }

                // Add all trackers
                for (final tracker in trackerProvider.trackers) {
                  allBoardItems.add(_BoardItemForSave(tracker, tracker.order, 'tracker'));
                }

                // Add all toggles
                for (final toggle in toggleProvider.toggles) {
                  allBoardItems.add(_BoardItemForSave(toggle, toggle.order, 'toggle'));
                }

                // Sort by order to get exact board sequence
                allBoardItems.sort((a, b) => a.order.compareTo(b.order));

                // Process items in order, deduplicating tokens while preserving utilities
                final Map<String, bool> seenTokens = {}; // Track seen token identities
                final List<TokenTemplate> templates = [];
                final List<TrackerWidgetTemplate> trackerTemplates = [];
                final List<ToggleWidgetTemplate> toggleTemplates = [];

                int normalizedIndex = 0;
                for (final boardItem in allBoardItems) {
                  if (boardItem.type == 'token') {
                    final item = boardItem.item as Item;
                    final key = '${item.name}|${item.pt}|${item.colors}|${item.abilities}';
                    if (!seenTokens.containsKey(key)) {
                      // First occurrence - save this token
                      seenTokens[key] = true;
                      final template = TokenTemplate.fromItem(item);
                      template.order = normalizedIndex.toDouble();
                      templates.add(template);
                      normalizedIndex++;
                    }
                    // Skip duplicate tokens
                  } else if (boardItem.type == 'tracker') {
                    final tracker = boardItem.item as TrackerWidget;
                    final template = TrackerWidgetTemplate.fromWidget(tracker);
                    template.order = normalizedIndex.toDouble();
                    trackerTemplates.add(template);
                    normalizedIndex++;
                  } else if (boardItem.type == 'toggle') {
                    final toggle = boardItem.item as ToggleWidget;
                    final template = ToggleWidgetTemplate.fromWidget(toggle);
                    template.order = normalizedIndex.toDouble();
                    toggleTemplates.add(template);
                    normalizedIndex++;
                  }
                }

                final deck = Deck(
                  name: deckName,
                  templates: templates,
                  trackerWidgets: trackerTemplates.isEmpty ? null : trackerTemplates,
                  toggleWidgets: toggleTemplates.isEmpty ? null : toggleTemplates,
                );
                deckProvider.saveDeck(deck);
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) {
      // Dispose controller after all frames have been processed to avoid accessing disposed controller during teardown
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.dispose();
      });
    });
  }

  void _showLoadDeckSheet() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LoadDeckSheet(),
        fullscreenDialog: true,
      ),
    );
  }

  void _showAboutPlaceholder() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AboutScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  void _showStatusPlaceholder() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Status'),
        content: const Text('Not yet implemented'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
