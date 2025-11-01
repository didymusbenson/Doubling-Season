import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';

class MultiplierView extends StatefulWidget {
  const MultiplierView({super.key});

  @override
  State<MultiplierView> createState() => _MultiplierViewState();
}

class _MultiplierViewState extends State<MultiplierView> {
  bool _showControls = false;
  final TextEditingController _manualInputController = TextEditingController();

  @override
  void dispose() {
    _manualInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final multiplier = settings.tokenMultiplier;

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      onLongPress: () => _showManualInput(context, settings, multiplier),
      child: AnimatedSwitcher(
        duration: UIConstants.animationDuration,
        child: _showControls
            ? _buildExpandedControls(context, settings, multiplier)
            : _buildCollapsedBadge(multiplier),
      ),
    );
  }

  Widget _buildCollapsedBadge(int multiplier) {
    return Container(
      key: const ValueKey('collapsed'),
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'x$multiplier',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedControls(BuildContext context, SettingsProvider settings, int multiplier) {
    return Container(
      key: const ValueKey('expanded'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: multiplier > GameConstants.minMultiplier
                ? () => settings.setTokenMultiplier(multiplier - 1)
                : null,
            icon: const Icon(Icons.remove),
            color: Colors.blue,
          ),
          GestureDetector(
            onLongPress: () => _showManualInput(context, settings, multiplier),
            child: Text(
              'x$multiplier',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ),
          IconButton(
            onPressed: () => settings.setTokenMultiplier(multiplier + 1),
            icon: const Icon(Icons.add),
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  void _showManualInput(BuildContext context, SettingsProvider settings, int multiplier) {
    _manualInputController.text = multiplier.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Multiplier'),
        content: TextField(
          controller: _manualInputController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Enter multiplier value',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(_manualInputController.text);
              if (value != null && value >= GameConstants.minMultiplier) {
                settings.setTokenMultiplier(value);
              }
              Navigator.pop(context);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }
}
