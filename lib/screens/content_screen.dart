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
import '../widgets/token_card.dart';
import '../widgets/multiplier_view.dart';
import '../widgets/load_deck_sheet.dart';
import '../widgets/floating_action_menu.dart';
import '../utils/color_utils.dart';
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
            bottom: 16,
            left: 16,
            child: MultiplierView(),
          ),

          // Floating action menu (bottom right)
          Positioned(
            bottom: 16,
            right: 16,
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
                bottom: 120, // Space for MultiplierView
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
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
                      border: GradientBoxBorder(
                        gradient: ColorUtils.gradientForColors(item.colors, isEmblem: item.isEmblem),
                        width: 3,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9), // Slightly smaller to fit inside border
                      child: Dismissible(
                        key: ValueKey(item.key), // Use Hive key
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => provider.deleteItem(item),
                        child: TokenCard(item: item),
                      ),
                    ),
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
    return Align(
      alignment: Alignment.topCenter,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: Text(
                  'No tokens to display',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => _showTokenSearch(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
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
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.menu,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Open tools to add tokens, save decks, and more',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calculate,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Adjust multiplier for token doubling effects',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.settings,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Adjust Settings',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.help_outline,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  const SizedBox(width: 12),
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
      builder: (context) => AlertDialog(
        title: const Text('Board Wipe'),
        content: const Text('Choose board wipe action:'),
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
            child: const Text('Set to 0'),
          ),
          TextButton(
            onPressed: () {
              tokenProvider.boardWipeDelete();
              Navigator.pop(context);
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

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
