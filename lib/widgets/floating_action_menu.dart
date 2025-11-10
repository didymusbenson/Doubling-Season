import 'package:flutter/material.dart';

class FloatingActionMenu extends StatelessWidget {
  final VoidCallback onNewToken;
  final VoidCallback onUntapAll;
  final VoidCallback onClearSickness;
  final VoidCallback onSaveDeck;
  final VoidCallback onLoadDeck;
  final VoidCallback onBoardWipe;

  const FloatingActionMenu({
    super.key,
    required this.onNewToken,
    required this.onUntapAll,
    required this.onClearSickness,
    required this.onSaveDeck,
    required this.onLoadDeck,
    required this.onBoardWipe,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showActionSheet(context),
      heroTag: 'menu_fab',
      child: const Icon(Icons.menu, size: 28),
    );
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ActionBottomSheet(
        onNewToken: onNewToken,
        onUntapAll: onUntapAll,
        onClearSickness: onClearSickness,
        onSaveDeck: onSaveDeck,
        onLoadDeck: onLoadDeck,
        onBoardWipe: onBoardWipe,
      ),
    );
  }
}

class _ActionBottomSheet extends StatelessWidget {
  final VoidCallback onNewToken;
  final VoidCallback onUntapAll;
  final VoidCallback onClearSickness;
  final VoidCallback onSaveDeck;
  final VoidCallback onLoadDeck;
  final VoidCallback onBoardWipe;

  const _ActionBottomSheet({
    required this.onNewToken,
    required this.onUntapAll,
    required this.onClearSickness,
    required this.onSaveDeck,
    required this.onLoadDeck,
    required this.onBoardWipe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.menu, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Actions',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Actions list
            _buildActionTile(
              context: context,
              icon: Icons.add,
              label: 'New Token',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                onNewToken();
              },
            ),
            const SizedBox(height: 4),
            _buildActionTile(
              context: context,
              icon: Icons.refresh,
              label: 'Untap All',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                onUntapAll();
              },
            ),
            const SizedBox(height: 4),
            _buildActionTile(
              context: context,
              icon: Icons.adjust,
              label: 'Clear Summoning Sickness',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                onClearSickness();
              },
            ),
            const SizedBox(height: 4),
            _buildActionTile(
              context: context,
              icon: Icons.save,
              label: 'Save Deck',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                onSaveDeck();
              },
            ),
            const SizedBox(height: 4),
            _buildActionTile(
              context: context,
              icon: Icons.folder_open,
              label: 'Load Deck',
              color: Colors.indigo,
              onTap: () {
                Navigator.pop(context);
                onLoadDeck();
              },
            ),
            const SizedBox(height: 4),
            _buildActionTile(
              context: context,
              icon: Icons.delete_sweep,
              label: 'Board Wipe',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                onBoardWipe();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
