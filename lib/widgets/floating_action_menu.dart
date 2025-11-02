import 'package:flutter/material.dart';

class FloatingActionMenu extends StatefulWidget {
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
  State<FloatingActionMenu> createState() => _FloatingActionMenuState();
}

class _FloatingActionMenuState extends State<FloatingActionMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _handleAction(VoidCallback action) {
    action();
    _toggle(); // Close menu after action
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Menu items
        if (_isExpanded) ...[
          _buildMenuItem(
            icon: Icons.add,
            label: 'New Token',
            onTap: () => _handleAction(widget.onNewToken),
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.refresh,
            label: 'Untap All',
            onTap: () => _handleAction(widget.onUntapAll),
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.hexagon_outlined,
            label: 'Clear Sickness',
            onTap: () => _handleAction(widget.onClearSickness),
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.save,
            label: 'Save Deck',
            onTap: () => _handleAction(widget.onSaveDeck),
            color: Colors.purple,
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.folder_open,
            label: 'Load Deck',
            onTap: () => _handleAction(widget.onLoadDeck),
            color: Colors.indigo,
          ),
          const SizedBox(height: 12),
          _buildMenuItem(
            icon: Icons.delete_sweep,
            label: 'Board Wipe',
            onTap: () => _handleAction(widget.onBoardWipe),
            color: Colors.red,
          ),
          const SizedBox(height: 16),
        ],

        // Main FAB
        FloatingActionButton(
          onPressed: _toggle,
          child: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _expandAnimation,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return ScaleTransition(
      scale: _expandAnimation,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Icon button
          Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
