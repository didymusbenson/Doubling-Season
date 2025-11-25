import 'package:flutter/material.dart';

class FloatingActionMenu extends StatelessWidget {
  final VoidCallback onNewToken;
  final VoidCallback onWidgets;
  final VoidCallback onAddCountersToAll;
  final VoidCallback onMinusOneToAll;
  final VoidCallback onUntapAll;
  final VoidCallback onClearSickness;
  final VoidCallback onSaveDeck;
  final VoidCallback onLoadDeck;
  final VoidCallback onBoardWipe;

  const FloatingActionMenu({
    super.key,
    required this.onNewToken,
    required this.onWidgets,
    required this.onAddCountersToAll,
    required this.onMinusOneToAll,
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
      isScrollControlled: true,
      builder: (context) => _ActionBottomSheet(
        onNewToken: onNewToken,
        onWidgets: onWidgets,
        onAddCountersToAll: onAddCountersToAll,
        onMinusOneToAll: onMinusOneToAll,
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
  final VoidCallback onWidgets;
  final VoidCallback onAddCountersToAll;
  final VoidCallback onMinusOneToAll;
  final VoidCallback onUntapAll;
  final VoidCallback onClearSickness;
  final VoidCallback onSaveDeck;
  final VoidCallback onLoadDeck;
  final VoidCallback onBoardWipe;

  const _ActionBottomSheet({
    required this.onNewToken,
    required this.onWidgets,
    required this.onAddCountersToAll,
    required this.onMinusOneToAll,
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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: SafeArea(
        minimum: const EdgeInsets.only(bottom: 24),
        child: SingleChildScrollView(
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
            const SizedBox(height: 12),

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
            // TODO: Uncomment when Widgets feature is ready for release
            // _buildActionTile(
            //   context: context,
            //   icon: Icons.widgets,
            //   label: 'Widgets',
            //   color: Colors.deepPurple,
            //   onTap: () {
            //     Navigator.pop(context);
            //     onWidgets();
            //   },
            // ),
            // const SizedBox(height: 4),
            _buildActionTile(
              context: context,
              icon: Icons.update,
              label: 'Board Update',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _showBoardUpdateSheet(context);
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
          ],
          ),
        ),
      ),
    );
  }

  void _showBoardUpdateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _BoardUpdateSheet(
        onAddCountersToAll: onAddCountersToAll,
        onMinusOneToAll: onMinusOneToAll,
        onUntapAll: onUntapAll,
        onClearSickness: onClearSickness,
        onBoardWipe: onBoardWipe,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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

class _BoardUpdateSheet extends StatelessWidget {
  final VoidCallback onAddCountersToAll;
  final VoidCallback onMinusOneToAll;
  final VoidCallback onUntapAll;
  final VoidCallback onClearSickness;
  final VoidCallback onBoardWipe;

  const _BoardUpdateSheet({
    required this.onAddCountersToAll,
    required this.onMinusOneToAll,
    required this.onUntapAll,
    required this.onClearSickness,
    required this.onBoardWipe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: SafeArea(
        minimum: const EdgeInsets.only(bottom: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.update, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Board Update',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Board update actions
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
                icon: Icons.trending_up,
                label: '+1/+1 Everything',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  onAddCountersToAll();
                },
              ),
              const SizedBox(height: 4),
              _buildActionTile(
                context: context,
                icon: Icons.trending_down,
                label: '-1/-1 Everything',
                color: Colors.red.shade700,
                onTap: () {
                  Navigator.pop(context);
                  onMinusOneToAll();
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
