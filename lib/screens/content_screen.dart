import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:gradient_borders/gradient_borders.dart';
import '../models/item.dart';
import '../models/token_template.dart';
import '../models/deck.dart';
import '../providers/token_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/deck_provider.dart';
import '../utils/constants.dart';
import '../utils/color_utils.dart';
import '../widgets/token_card.dart';
import '../widgets/multiplier_view.dart';
import '../widgets/load_deck_sheet.dart';
import '../widgets/floating_action_menu.dart';
import 'token_search_screen.dart';
import 'about_screen.dart';

class ContentScreen extends StatefulWidget {
  const ContentScreen({super.key});

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

          // Multiplier view overlay (bottom left)
          const Positioned(
            bottom: UIConstants.standardPadding,
            left: UIConstants.standardPadding,
            child: MultiplierView(),
          ),

          // Floating action menu (bottom right)
          Positioned(
            bottom: UIConstants.standardPadding,
            right: UIConstants.standardPadding,
            child: FloatingActionMenu(
              onNewToken: _showTokenSearch,
              onUntapAll: _showUntapAllDialog,
              onClearSickness: _handleClearSickness,
              onSaveDeck: _showSaveDeckDialog,
              onLoadDeck: _showLoadDeckSheet,
              onBoardWipe: _showBoardWipeDialog,
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Doubling Season'),
      centerTitle: true,
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
    // Use Provider.of with listen: false to get the provider reference once
    final tokenProvider = Provider.of<TokenProvider>(context, listen: false);

    // Only use ValueListenableBuilder for reactivity - no need for Consumer
    return ValueListenableBuilder<Box<Item>>(
      valueListenable: tokenProvider.listenable,
      builder: (context, box, _) {
        // Check empty state directly on box (efficient)
        if (box.isEmpty) {
          return _buildEmptyState();
        }

        final items = box.values.toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        return ReorderableListView.builder(
              itemCount: items.length,
              padding: const EdgeInsets.only(
                top: UIConstants.listTopPadding,
                left: UIConstants.smallPadding,
                right: UIConstants.smallPadding,
                bottom: UIConstants.listBottomPadding,
              ),
              onReorder: (oldIndex, newIndex) => _handleReorder(items, oldIndex, newIndex),
              proxyDecorator: _buildDragProxy,
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  key: ValueKey(item.createdAt),
                  padding: const EdgeInsets.symmetric(vertical: UIConstants.verticalSpacing),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(UIConstants.borderRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: UIConstants.shadowOpacity),
                          blurRadius: UIConstants.shadowBlurRadius,
                          offset: const Offset(0, UIConstants.shadowOffset),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: UIConstants.lightShadowOpacity),
                          blurRadius: UIConstants.lightShadowBlurRadius,
                          offset: const Offset(0, UIConstants.lightShadowOffset),
                        ),
                      ],
                      border: GradientBoxBorder(
                        gradient: ColorUtils.gradientForColors(item.colors, isEmblem: item.isEmblem),
                        width: UIConstants.borderWidth,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(UIConstants.smallBorderRadius),
                      child: Container(
                        color: Theme.of(context).cardColor,
                        child: Dismissible(
                          key: ValueKey('dismissible_${item.createdAt}'), // Use different key for Dismissible
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: UIConstants.standardPadding),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) => tokenProvider.deleteItem(item),
                          child: TokenCard(item: item),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
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
                  style: Theme.of(context).textTheme.titleLarge,
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
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  const SizedBox(width: UIConstants.largeSpacing),
                  Flexible(
                    child: Text(
                      'Open tools to add tokens, save decks, and more',
                      style: Theme.of(context).textTheme.bodyMedium,
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
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  const SizedBox(width: UIConstants.largeSpacing),
                  Flexible(
                    child: Text(
                      'Adjust multiplier for token doubling effects',
                      style: Theme.of(context).textTheme.bodyMedium,
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
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  const SizedBox(width: UIConstants.largeSpacing),
                  Flexible(
                    child: Text(
                      'Adjust Settings',
                      style: Theme.of(context).textTheme.bodyMedium,
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
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  const SizedBox(width: UIConstants.largeSpacing),
                  Flexible(
                    child: Text(
                      'About Doubling Season',
                      style: Theme.of(context).textTheme.bodyMedium,
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

  void _handleReorder(List<Item> items, int oldIndex, int newIndex) {
    // Track if moving down before adjustment
    final movingDown = newIndex > oldIndex;

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final item = items[oldIndex];

    // Calculate new fractional order
    double newOrder;
    if (newIndex == 0) {
      // Moving to top
      newOrder = items.first.order - 1.0;
    } else if (newIndex == items.length - 1) {
      // Moving to bottom
      newOrder = items.last.order + 1.0;
    } else {
      // Moving between two items
      if (movingDown) {
        // Item moves after items[newIndex]
        final prevOrder = items[newIndex].order;
        final nextOrder = items[newIndex + 1].order;
        newOrder = (prevOrder + nextOrder) / 2.0;
      } else {
        // Item moves before items[newIndex]
        final prevOrder = items[newIndex - 1].order;
        final nextOrder = items[newIndex].order;
        newOrder = (prevOrder + nextOrder) / 2.0;
      }
    }

    item.order = newOrder;
    item.save();

    // Check if we need compacting (when gap becomes too small)
    _checkAndCompactOrders(items);
  }

  void _checkAndCompactOrders(List<Item> items) {
    // If any two adjacent items have order difference < 0.001, compact all orders
    items.sort((a, b) => a.order.compareTo(b.order));

    for (int i = 0; i < items.length - 1; i++) {
      if ((items[i + 1].order - items[i].order) < 0.001) {
        _compactOrders(items);
        return;
      }
    }
  }

  void _compactOrders(List<Item> items) {
    items.sort((a, b) => a.order.compareTo(b.order));
    for (int i = 0; i < items.length; i++) {
      items[i].order = i.toDouble();
      items[i].save();
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

  void _showTokenSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TokenSearchScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  void _showUntapAllDialog() {
    final tokenProvider = context.read<TokenProvider>();
    tokenProvider.untapAll();
  }

  void _showSummoningSicknessToggle() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return SwitchListTile(
              title: const Text('Track summoning sickness'),
              subtitle: const Text('Automatically track summoning sickness on newly created tokens'),
              value: settings.summoningSicknessEnabled,
              onChanged: (value) {
                settings.setSummoningSicknessEnabled(value);
              },
              contentPadding: EdgeInsets.zero,
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
                // Sort by order and compact to sequential integers for clean deck storage
                final sortedItems = tokenProvider.items
                    ..sort((a, b) => a.order.compareTo(b.order));

                final templates = sortedItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final template = TokenTemplate.fromItem(item);
                  // Override order with compacted sequential values
                  template.order = index.toDouble();
                  return template;
                }).toList();

                final deck = Deck(name: deckName, templates: templates);
                deckProvider.saveDeck(deck);
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    // Wait for dialog animation to complete before disposing controller
    await Future.delayed(const Duration(milliseconds: 300));
    controller.dispose();
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
}
