import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/deck.dart';
import '../providers/deck_provider.dart';
import '../providers/token_provider.dart';

class LoadDeckSheet extends StatelessWidget {
  const LoadDeckSheet({super.key});

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

  void _loadDeck(BuildContext context, Deck deck) async {
    // Capture references from outer context BEFORE showing dialog
    final tokenProvider = context.read<TokenProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final currentTokens = tokenProvider.items;

    if (currentTokens.isEmpty) {
      // Board is empty - load directly without confirmation
      await _loadDeckTokens(tokenProvider, deck, startOrder: 0.0);

      if (context.mounted) {
        Navigator.pop(context); // Close load deck sheet
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Loaded deck "${deck.name}"')),
        );
      }
      return;
    }

    // Board has tokens - show confirmation dialog
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Loading ${deck.name}'),
        content: const Text('Would you like to:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'clear'),
            child: const Text('Clear tokens and load'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'add'),
            child: const Text('Add deck tokens to board'),
          ),
        ],
      ),
    );

    if (result == null || result == 'cancel') return;

    if (result == 'clear') {
      await tokenProvider.boardWipeDelete();
      await _loadDeckTokens(tokenProvider, deck, startOrder: 0.0);
    } else if (result == 'add') {
      // Find max order and append deck tokens after it
      final maxOrder = currentTokens.isEmpty
          ? 0.0
          : currentTokens.map((i) => i.order).reduce(max);
      await _loadDeckTokens(tokenProvider, deck, startOrder: maxOrder.floor() + 1.0);
    }

    if (context.mounted) {
      Navigator.pop(context); // Close load deck sheet
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Loaded deck "${deck.name}"')),
      );
    }
  }

  Future<void> _loadDeckTokens(TokenProvider tokenProvider, Deck deck, {required double startOrder}) async {
    // Sort templates by order
    final sortedTemplates = deck.templates.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    // Create items preserving relative order
    for (int i = 0; i < sortedTemplates.length; i++) {
      final template = sortedTemplates[i];
      final item = template.toItem(
        amount: 1, // Default amount
        createTapped: false,
      );
      // Override order to position correctly (clear: 0,1,2... or add: maxOrder+1, maxOrder+2...)
      item.order = startOrder + i.toDouble();
      await tokenProvider.insertItemWithExplicitOrder(item);
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    Deck deck,
    DeckProvider provider,
  ) {
    // Capture ScaffoldMessenger before showing dialog
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Deck'),
        content: Text('Delete "${deck.name}"?\n\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await provider.deleteDeck(deck);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);

                // Use captured ScaffoldMessenger (safe without context)
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Deleted deck "${deck.name}"')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
