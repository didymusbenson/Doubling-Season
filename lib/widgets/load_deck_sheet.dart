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
              // BUG FIX: SwiftUI LoadDeckSheet has a bug where it creates
              // items with amount: 0. This implementation properly uses template values.
              for (final template in deck.templates) {
                final item = template.toItem();
                await tokenProvider.insertItem(item);
              }

              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close load deck sheet

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Loaded deck "${deck.name}"')),
                );
              }
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
              if (context.mounted) {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
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
