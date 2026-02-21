import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/deck.dart';
import '../models/token_template.dart';
import '../models/tracker_widget_template.dart';
import '../models/toggle_widget_template.dart';
import '../providers/deck_provider.dart';
import '../providers/token_provider.dart';
import '../providers/tracker_provider.dart';
import '../providers/toggle_provider.dart';

// Helper class for preserving exact order when loading decks
class _TemplateForLoad {
  final dynamic template; // TokenTemplate, TrackerWidgetTemplate, or ToggleWidgetTemplate
  final double order;
  final String type; // 'token', 'tracker', 'toggle'

  _TemplateForLoad(this.template, this.order, this.type);
}

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
      body: Builder(
        builder: (context) {
          final decks = deckProvider.decks;

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
              final utilityCount = (deck.trackerWidgets?.length ?? 0) + (deck.toggleWidgets?.length ?? 0);
              final subtitle = utilityCount > 0
                  ? '${deck.templates.length} tokens, $utilityCount utilities'
                  : '${deck.templates.length} tokens';

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
                  subtitle: Text(subtitle),
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
    final trackerProvider = context.read<TrackerProvider>();
    final toggleProvider = context.read<ToggleProvider>();
    final currentTokens = tokenProvider.items;
    final currentTrackers = trackerProvider.trackers;
    final currentToggles = toggleProvider.toggles;

    if (currentTokens.isEmpty && currentTrackers.isEmpty && currentToggles.isEmpty) {
      // Board is empty - load directly without confirmation
      await _loadDeckItems(tokenProvider, trackerProvider, toggleProvider, deck, startOrder: 0.0);

      if (context.mounted) {
        Navigator.pop(context); // Close load deck sheet
      }
      return;
    }

    // Board has items - show confirmation dialog
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
            child: const Text('Clear board and load'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'add'),
            child: const Text('Add deck to board'),
          ),
        ],
      ),
    );

    if (result == null || result == 'cancel') return;

    if (result == 'clear') {
      // Clear all tokens and utilities
      await tokenProvider.boardWipeDelete();
      await trackerProvider.deleteAll();
      await toggleProvider.deleteAll();
      await _loadDeckItems(tokenProvider, trackerProvider, toggleProvider, deck, startOrder: 0.0);
    } else if (result == 'add') {
      // Find max order and append deck items after it
      final maxTokenOrder = currentTokens.isEmpty
          ? 0.0
          : currentTokens.map((i) => i.order).reduce(max);
      final maxTrackerOrder = currentTrackers.isEmpty
          ? 0.0
          : currentTrackers.map((w) => w.order).reduce(max);
      final maxToggleOrder = currentToggles.isEmpty
          ? 0.0
          : currentToggles.map((w) => w.order).reduce(max);
      final maxOrder = [maxTokenOrder, maxTrackerOrder, maxToggleOrder].reduce(max);

      await _loadDeckItems(tokenProvider, trackerProvider, toggleProvider, deck, startOrder: maxOrder.floor() + 1.0);
    }

    if (context.mounted) {
      Navigator.pop(context); // Close load deck sheet
    }
  }

  Future<void> _loadDeckItems(
    TokenProvider tokenProvider,
    TrackerProvider trackerProvider,
    ToggleProvider toggleProvider,
    Deck deck, {
    required double startOrder,
  }) async {
    // Collect all templates with their orders to preserve exact sequence
    final allTemplates = <_TemplateForLoad>[];

    // Add token templates
    for (final template in deck.templates) {
      allTemplates.add(_TemplateForLoad(template, template.order, 'token'));
    }

    // Add tracker templates if present
    if (deck.trackerWidgets != null) {
      for (final template in deck.trackerWidgets!) {
        allTemplates.add(_TemplateForLoad(template, template.order, 'tracker'));
      }
    }

    // Add toggle templates if present
    if (deck.toggleWidgets != null) {
      for (final template in deck.toggleWidgets!) {
        allTemplates.add(_TemplateForLoad(template, template.order, 'toggle'));
      }
    }

    // Sort by order to restore exact board sequence
    allTemplates.sort((a, b) => a.order.compareTo(b.order));

    // Load items in order
    for (int i = 0; i < allTemplates.length; i++) {
      final templateItem = allTemplates[i];
      final newOrder = startOrder + i.toDouble();

      if (templateItem.type == 'token') {
        final template = templateItem.template as TokenTemplate;
        final item = template.toItem(
          amount: 0, // Initialize with 0 tokens (user adds as needed)
          createTapped: false,
        );
        item.order = newOrder;
        await tokenProvider.insertItemWithExplicitOrder(item);
      } else if (templateItem.type == 'tracker') {
        final template = templateItem.template as TrackerWidgetTemplate;
        final widget = template.toWidget(customOrder: newOrder);
        await trackerProvider.insertTrackerWithExplicitOrder(widget);
      } else if (templateItem.type == 'toggle') {
        final template = templateItem.template as ToggleWidgetTemplate;
        final widget = template.toWidget(customOrder: newOrder);
        await toggleProvider.insertToggleWithExplicitOrder(widget);
      }
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    Deck deck,
    DeckProvider provider,
  ) {
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
