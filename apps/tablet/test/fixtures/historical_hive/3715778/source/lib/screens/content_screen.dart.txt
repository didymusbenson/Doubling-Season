import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/token_template.dart';
import '../models/deck.dart';
import '../providers/token_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/deck_provider.dart';
import '../widgets/token_card.dart';
import '../widgets/multiplier_view.dart';
import '../widgets/load_deck_sheet.dart';
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

          // Multiplier view overlay (bottom center)
          const Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: MultiplierView(),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    final tokenProvider = context.watch<TokenProvider>();

    return AppBar(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Plus button (create token)
          IconButton(
            onPressed: () => _showTokenSearch(),
            icon: const Icon(Icons.add),
            tooltip: 'Add Token',
          ),

          // Untap all
          IconButton(
            onPressed: () => _showUntapAllDialog(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Untap All',
          ),

          // Clear summoning sickness
          GestureDetector(
            onTap: () => tokenProvider.clearSummoningSickness(),
            onLongPress: () => _showSummoningSicknessToggle(),
            child: IconButton(
              onPressed: null,
              icon: const Icon(Icons.hexagon_outlined),
              tooltip: 'Clear Summoning Sickness',
            ),
          ),

          // Save deck
          IconButton(
            onPressed: () => _showSaveDeckDialog(),
            icon: const Icon(Icons.save),
            tooltip: 'Save Deck',
          ),

          // Load deck
          IconButton(
            onPressed: () => _showLoadDeckSheet(),
            icon: const Icon(Icons.folder_open),
            tooltip: 'Load Deck',
          ),

          // Board wipe
          IconButton(
            onPressed: () => _showBoardWipeDialog(),
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Board Wipe',
          ),
        ],
      ),
      actions: [
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
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Dismissible(
                    key: ValueKey(items[index].key), // Use Hive key
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

  void _showUntapAllDialog() {
    final tokenProvider = context.read<TokenProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Untap All'),
        content: const Text('Untap all tokens?'),
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
            child: const Text('Untap'),
          ),
        ],
      ),
    );
  }

  void _showSummoningSicknessToggle() {
    final settings = context.read<SettingsProvider>();
    final current = settings.summoningSicknessEnabled;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Summoning Sickness'),
        content: Text(
          current
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
              settings.setSummoningSicknessEnabled(!current);
              Navigator.pop(context);
            },
            child: Text(current ? 'Disable' : 'Enable'),
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
